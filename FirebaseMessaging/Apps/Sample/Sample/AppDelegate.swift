// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import FirebaseCore
import FirebaseMessaging

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication
                     .LaunchOptionsKey: Any]?) -> Bool {
    FirebaseApp.configure()
    application.delegate = self

    let center = UNUserNotificationCenter.current()
    center.delegate = self

    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      if error != nil {
        print("Failed requesting notification permission: ", error ?? "")
      }
    }
    application.registerForRemoteNotifications()

    return true
  }

  // Implement this to display notification when app is in foreground.
  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions)
                                -> Void) {
    completionHandler([.alert, .sound])
  }

  // MARK: UISceneSession Lifecycle

  func application(_ application: UIApplication,
                   configurationForConnecting connectingSceneSession: UISceneSession,
                   options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return UISceneConfiguration(name: "Default Configuration",
                                sessionRole: connectingSceneSession.role)
  }

  func application(_ application: UIApplication,
                   didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                   fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult)
                     -> Void) {
    // Log delivery signal for data/hidden/background messages
    print("Hidden message arrived:\n" + userInfo.debugDescription)
    Messaging.serviceExtension().exportDeliveryMetricsToBigQuery(withMessageInfo: userInfo)
    completionHandler(.newData)
  }
}
