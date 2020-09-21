/*
 * Copyright 2019 Google
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

import ManifestReader

// Get the launch arguments, parsed by user defaults.
let args = LaunchArgs.shared

// Keep timing for how long it takes to change the Firebase pod versions.
let buildStart = Date()
var cocoaPodsUpdateMessage: String = ""

var paths = FirebasePod.FilesystemPaths(currentReleasePath: args.currentReleasePath,
                                        gitRootPath: args.gitRootPath)

/// Assembles the expected versions based on the release manifest passed in.
/// Returns an array with the pod name as the key and version as the value,
private func getExpectedVersions() -> [String: String] {
  // Merge the versions from the current release and the known public versions.
  var releasingVersions: [String: String] = [:]

  // Override any of the expected versions with the current release manifest, if it exists.
  let currentRelease = ManifestReader.loadCurrentRelease(fromTextproto: paths.currentReleasePath)
  print("Overriding the following Pod versions, taken from the current release manifest:")
  for pod in currentRelease.sdk {
    releasingVersions[pod.sdkName] = pod.sdkVersion
    print("\(pod.sdkName): \(pod.sdkVersion)")
  }

  if !releasingVersions.isEmpty {
    print("Updating Firebase Pod in git installation at \(paths.gitRootPath)) " +
      "with the following versions: \(releasingVersions)")
  }

  return releasingVersions
}

private func updateFirebasePod(newVersions: [String: String]) {
  let podspecFile = paths.gitRootPath + "/Firebase.podspec"
  var contents = ""
  do {
    contents = try String(contentsOfFile: podspecFile, encoding: .utf8)
  } catch {
    fatalError("Could not read Firebase podspec. \(error)")
  }
  for (pod, version) in newVersions {
    if pod == "Firebase" {
      // Replace version in string like s.version = '6.9.0'
      guard let range = contents.range(of: "s.version") else {
        fatalError("Could not find version of Firebase pod in podspec at \(podspecFile)")
      }
      var versionStartIndex = contents.index(range.upperBound, offsetBy: 1)
      while contents[versionStartIndex] != "'" {
        versionStartIndex = contents.index(versionStartIndex, offsetBy: 1)
      }
      var versionEndIndex = contents.index(versionStartIndex, offsetBy: 1)
      while contents[versionEndIndex] != "'" {
        versionEndIndex = contents.index(versionEndIndex, offsetBy: 1)
      }
      contents.removeSubrange(versionStartIndex ... versionEndIndex)
      contents.insert(contentsOf: "'" + version + "'", at: versionStartIndex)
    } else {
      // Replace version in string like ss.dependency 'FirebaseCore', '6.3.0'
      guard let range = contents.range(of: pod) else {
        // This pod is not a top-level Firebase pod dependency.
        continue
      }
      var versionStartIndex = contents.index(range.upperBound, offsetBy: 2)
      while !contents[versionStartIndex].isWholeNumber {
        versionStartIndex = contents.index(versionStartIndex, offsetBy: 1)
      }
      var versionEndIndex = contents.index(versionStartIndex, offsetBy: 1)
      while contents[versionEndIndex] != "'" {
        versionEndIndex = contents.index(versionEndIndex, offsetBy: 1)
      }
      contents.removeSubrange(versionStartIndex ... versionEndIndex)
      contents.insert(contentsOf: version + "'", at: versionStartIndex)
    }
  }
  do {
    try contents.write(toFile: podspecFile, atomically: false, encoding: String.Encoding.utf8)
  } catch {
    fatalError("Failed to write \(podspecFile). \(error)")
  }
}

do {
  let newVersions = getExpectedVersions()
  updateFirebasePod(newVersions: newVersions)
  print("Updating Firebase pod for version \(String(describing: newVersions["Firebase"]!))")

  // Get the time since the tool start.
  let secondsSinceStart = -Int(buildStart.timeIntervalSinceNow)
  print("""
  Time profile:
    It took \(secondsSinceStart) seconds (~\(secondsSinceStart / 60)m) to update the Firebase pod.
    \(cocoaPodsUpdateMessage)
  """)
}
