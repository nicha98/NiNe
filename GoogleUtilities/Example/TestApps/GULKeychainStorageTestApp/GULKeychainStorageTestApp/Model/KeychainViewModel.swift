/*
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation

import Combine
import BackgroundTasks
import UserNotifications
import CoreLocation

import GoogleUtilities
import Promises

protocol BackgroundFetchHandler: AnyObject {
  func performFetchWithCompletionHandler(completionHandler: @escaping (UIBackgroundFetchResult)
    -> Void)
}

class KeychainViewModel: NSObject, ObservableObject {
  let valueKey = "SingleValueStorage.ValueKey"
  let keychainStorage: GULKeychainStorage
  let locationManager = CLLocationManager()

  internal init(keychainStorage: GULKeychainStorage = GULKeychainStorage(service: Bundle.main
      .bundleIdentifier ?? "GULKeychainStorageTestApp")) {
    self.keychainStorage = keychainStorage
    super.init()

//    self.registerBackgroundFetchHandler()
    self.startLocationUpdates()
  }

  // MARK: - - Keychain

  private func getValue() -> Promise<String?> {
    return Promise<String?>(keychainStorage
      .getObjectForKey(valueKey, objectClass: NSString.self, accessGroup: nil))
  }

  private func set(value: String?) -> Promise<NSNull> {
    if let value = value {
      return Promise<NSNull>(keychainStorage
        .setObject(value as NSString, forKey: valueKey, accessGroup: nil))
    } else {
      return Promise<NSNull>(keychainStorage.removeObject(forKey: valueKey, accessGroup: nil))
    }
  }

  private func generateRandom() -> Promise<String> {
    return Promise(UUID().uuidString)
  }

  // MARK: - - Log

  private func log(message: String) {
    log = "\(message)\n\(log)"
    print(message)
  }

  private func showNotification(message: String) {
    UNUserNotificationCenter.current().requestAuthorization(options: .alert) { granted, error in
      guard granted else {
        self.log(message: "Cannot display User Notification - access denied.")
        return
      }

      let content = UNMutableNotificationContent()
      content.body = message
      content.title = "Background fetch."
      let request = UNNotificationRequest(identifier: "keychain_test", content: content,
                                          trigger: nil)
      UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
  }

  private func updateAndLogValue(completion: @escaping () -> Void) {
    log(message: "isProtectedDataAvailable: \(UIApplication.shared.isProtectedDataAvailable)")

    readButtonPressed()

    generateAndSaveButtonPressed {
      self.showNotification(message: self.log)
      completion()
    }
  }

  // MARK: - - View Model API

  @Published var log = ""

  func readButtonPressed() {
    getValue()
      .then { value in
        self.log(message: "Get value: \(value ?? "nil")")
      }.catch { error in
        self.log(message: "Get value error: \(error)")
      }
  }

  func generateAndSaveButtonPressed(completion: (() -> Void)? = nil) {
    generateRandom()
      .then { random -> Promise<NSNull> in
        self.log(message: "Saved value: \(random)")
        return self.set(value: random)
      }
      .catch { error in
        self.log(message: "Save value error: \(error)")
      }
      .always {
        completion?()
      }
  }

  // MARK: - - Background fetch

  let backgroundFetchTaskID = "KeychainViewModel.fetch"
  private func registerBackgroundFetchHandler() {
    let registered = BGTaskScheduler.shared
      .register(forTaskWithIdentifier: backgroundFetchTaskID, using: nil) { task in
        self.log(message: "Background fetch:")

        // Schedule next refresh.
        self.registerBackgroundFetchHandler()

        // Do.
        self.updateAndLogValue {
          task.setTaskCompleted(success: true)
        }
    }
    
    guard registered else {
      log(message: "Failed to register for background fetch.")
      return
    }

    let request = BGAppRefreshTaskRequest(identifier: backgroundFetchTaskID)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 5)

    do {
      try BGTaskScheduler.shared.submit(request)
      print("Background app refresh scheduled.")
    } catch {
      print("Could not schedule app refresh: \(error)")
    }
  }
}

extension KeychainViewModel: BackgroundFetchHandler {
  func performFetchWithCompletionHandler(completionHandler: @escaping (UIBackgroundFetchResult)
    -> Void) {
    log(message: "Background fetch:")
    updateAndLogValue {
      completionHandler(.newData)
    }
  }
}

extension KeychainViewModel: CLLocationManagerDelegate {
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    log(message: "Location update")
    DispatchQueue.main.async {
      self.updateAndLogValue {}
    }
  }

  func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
    log(message: "Visit")
    DispatchQueue.main.async {
      self.updateAndLogValue {}
    }
  }

  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    _ = startLocationUpdates(with: status)
  }

  private func startLocationUpdates() {
    locationManager.delegate = self
    locationManager.allowsBackgroundLocationUpdates = true

    if !startLocationUpdates(with: CLLocationManager.authorizationStatus()) {
      locationManager.requestAlwaysAuthorization()
    }
  }

  private func startLocationUpdates(with status: CLAuthorizationStatus) -> Bool {
    switch status {
    case .authorizedAlways:
//      locationManager.startUpdatingLocation()
      locationManager.startMonitoringVisits()
      log(message: "Location updates started")
      return true
    default:
      log(message: "CLLocationManager wrong auth status: \(status.rawValue)")
      return false
    }
  }
}
