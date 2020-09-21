#!/usr/bin/swift
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

// Utility script for verifying `import` and `include` syntax. This ensures a
// consistent style as well as functionality across multiple package managers.

// For more context, see https://github.com/firebase/firebase-ios-sdk/blob/master/HeadersImports.md.

import Foundation

// Skip these directories. Imports should only be repo-relative in libraries
// and unit tests.
let skipDirPatterns = ["/Sample/", "/Pods/", "FirebaseStorage/Tests/Integration",
                       "FirebaseInAppMessaging/Tests/Integration/",
                       "Example/InstanceID/App", "SymbolCollisionTest/", "/gen/",
                       "CocoapodsIntegrationTest/"] +
  [
    "CoreOnly/Sources", // Skip Firebase.h
  ] +

  // The following are temporary skips pending working through a first pass of the repo:
  [
    "FirebaseABTesting",
    "FirebaseAppDistribution",
    "FirebaseCore/Sources/Private", // Fixes require breaking private API changes. For Firebase 7.
    "FirebaseDynamicLinks",
    "Firebase/CoreDiagnostics",
    "FirebaseDatabase/Sources/third_party/Wrap-leveldb", // Pending SwiftPM for leveldb.
    "Example",
    "FirebaseInAppMessaging",
    "FirebaseInstallations/Source/Tests/Unit/",
    "Firebase/InstanceID",
    "FirebaseMessaging",
    "FirebaseRemoteConfig",
    "Crashlytics",
    "Firestore",
    "GoogleDataTransport",
    "GoogleUtilitiesComponents",
  ]

// Skip existence test for patterns that start with the following:
let skipImportPatterns = [
  "FBLPromise",
]

var foundError = false

func genError(_ message: String) {
  print(message)
  foundError = true
}

func checkFile(_ file: String, isPublic: Bool) {
  var fileContents = ""
  do {
    fileContents = try String(contentsOfFile: file, encoding: .utf8)
  } catch {
    genError("Could not read \(file). \(error)")
    // Not a source file, give up and return.
    return
  }
  var inSwiftPackage = false
  var inSwiftPackageElse = false
  let lines = fileContents.components(separatedBy: .newlines)
  var lineNum = 0
  nextLine: for rawLine in lines {
    let line = rawLine.trimmingCharacters(in: .whitespaces)
    lineNum += 1
    if line.starts(with: "#if SWIFT_PACKAGE") {
      inSwiftPackage = true
    } else if inSwiftPackage, line.starts(with: "#else") {
      inSwiftPackage = false
      inSwiftPackageElse = true
    } else if inSwiftPackageElse, line.starts(with: "#endif") {
      inSwiftPackageElse = false
    } else if inSwiftPackage {
      continue
    } else if line.starts(with: "@import") {
      // "@import" is only allowed for Swift Package Manager.
      genError("@import should not be used in CocoaPods library code: \(file):\(lineNum)")
    }

    // "The #else of a SWIFT_PACKAGE check should only do CocoaPods module-style imports."
    if line.starts(with: "#import") || line.starts(with: "#include") {
      let importFile = line.components(separatedBy: " ")[1]
      if inSwiftPackageElse {
        if importFile.first != "<" {
          genError("Import error: \(file):\(lineNum) Import in SWIFT_PACKAGE #else should start with \"<\".")
        }
        continue
      }
      let importFileRaw = importFile.replacingOccurrences(of: "\"", with: "")
        .replacingOccurrences(of: "<", with: "")
        .replacingOccurrences(of: ">", with: "")

      if importFile.first == "\"" {
        // Public Headers should only use simple file names without paths.
        if isPublic {
          if importFile.contains("/") {
            genError("Import error: \(file):\(lineNum) Public header import should not include \"/\"")
          }

        } else if !FileManager.default.fileExists(atPath: repoURL.path + "/" + importFileRaw) {
          // All non-public header imports should be repo-relative paths.
          for skip in skipImportPatterns {
            if importFileRaw.starts(with: skip) {
              continue nextLine
            }
          }
          genError("Import error: \(file):\(lineNum) Import \(importFileRaw) does not exist.")
        }
      } else if importFile.first == "<" {
        // Verify that double quotes are always used for intra-module imports.
        if importFileRaw.starts(with: "Firebase") ||
          importFileRaw.starts(with: "GoogleUtilities") ||
          importFileRaw.starts(with: "GoogleDataTransport") {
          genError("Import error: \(file):\(lineNum) Imports internal to the repo should use double quotes not \"<\"")
        }
      }
    }
  }
}

// Search the path upwards to find the root of the firebase-ios-sdk repo.
var url = URL(fileURLWithPath: FileManager().currentDirectoryPath)
while url.path != "/", url.lastPathComponent != "firebase-ios-sdk" {
  url = url.deletingLastPathComponent()
}

let repoURL = url

let contents =
  try FileManager.default.contentsOfDirectory(at: repoURL,
                                              includingPropertiesForKeys: nil,
                                              options: [.skipsHiddenFiles])

for rootURL in contents {
  if !rootURL.hasDirectoryPath {
    continue
  }
  let enumerator = FileManager.default.enumerator(atPath: rootURL.path)
  whileLoop: while let file = enumerator?.nextObject() as? String {
    if let fType = enumerator?.fileAttributes?[FileAttributeKey.type] as? FileAttributeType,
      fType == .typeRegular {
      if file.starts(with: ".") {
        continue
      }
      if !(file.hasSuffix(".h") ||
        file.hasSuffix(".m") ||
        file.hasSuffix(".mm") ||
        file.hasSuffix(".c")) {
        continue
      }
      let fullTransformPath = rootURL.path + "/" + file
      for dirPattern in skipDirPatterns {
        if fullTransformPath.range(of: dirPattern) != nil {
          continue whileLoop
        }
      }
      checkFile(fullTransformPath, isPublic: file.range(of: "/Public/") != nil)
    }
  }
}

exit(foundError ? 1 : 0)
