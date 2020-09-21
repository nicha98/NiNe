// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

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

import PackageDescription

let package = Package(
  name: "Firebase",
  platforms: [.iOS(.v9), .macOS(.v10_11), .tvOS(.v10)],
  products: [
    // Products define the executables and libraries produced by a package, and make them visible to
    // other packages.
    // This is a test-only executable for us to try `swift run` and use all imported modules from a
    // Swift target.
    .executable(name: "firebase-test", targets: ["firebase-test"]),
    //
    .library(
      name: "Firebase",
      targets: ["Firebase"]
    ),
    .library(
      name: "FirebaseCore",
      targets: ["FirebaseCore"]
    ),
    .library(
      name: "FirebaseAuth",
      targets: ["FirebaseAuth"]
    ),
    // .library(
    //   name: "FirebaseCrashlytics",
    //   targets: ["FirebaseCrashlytics"]
    // ),
    // .library(
    //   name: "FirebaseFunctions",
    //   targets: ["FirebaseFunctions"]),
    .library(
      name: "FirebaseInstallations",
      targets: ["FirebaseInstallations"]
    ),
    .library(
      name: "FirebaseInstanceID",
      targets: ["FirebaseInstanceID"]
    ),
    .library(
      name: "FirebaseStorage",
      targets: ["FirebaseStorage"]
    ),
    .library(
      name: "FirebaseStorageSwift",
      targets: ["FirebaseStorageSwift"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/google/promises.git", "1.2.8" ..< "1.3.0"),
    .package(url: "https://github.com/google/gtm-session-fetcher.git", "1.4.0" ..< "2.0.0"),
    .package(url: "https://github.com/paulb777/nanopb.git", .branch("swift-package-manager")),
    // Branches need a force update with a run with the revision set like below.
    //   .package(url: "https://github.com/paulb777/nanopb.git", .revision("564392bd87bd093c308a3aaed3997466efb95f74"))
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages which this package depends on.
    .target(
      name: "firebase-test",
      dependencies: [ // "FirebaseAuth", "FirebaseFunctions",
        "Firebase", "FirebaseCore", "FirebaseInstallations", "FirebaseInstanceID",
        "FirebaseStorage",
        "FirebaseStorageSwift",
        "GoogleUtilities_Environment", "GoogleUtilities_Logger",
      ]
    ),
    .target(
      name: "GoogleUtilities_AppDelegateSwizzler",
      dependencies: ["GoogleUtilities_Environment", "GoogleUtilities_Logger",
                     "GoogleUtilities_Network"],
      path: "GoogleUtilities",
      sources: [
        "AppDelegateSwizzler/",
        "SceneDelegateSwizzler/",
        "Common/*.h",
      ],
      publicHeadersPath: "AppDelegateSwizzler/Private",
      cSettings: [
        .headerSearchPath("../"),
      ]
    ),
    .target(
      name: "GoogleUtilities_Environment",
      dependencies: ["FBLPromises"],
      path: "GoogleUtilities/Environment",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),

    // Tests need OCMock and resource support.

    .target(
      name: "GoogleUtilities_Logger",
      dependencies: ["GoogleUtilities_Environment"],
      path: "GoogleUtilities/Logger",
      publicHeadersPath: "Public"
    ),
    .target(
      name: "GoogleUtilities_Network",
      dependencies: ["GoogleUtilities_Logger", "GoogleUtilities_NSData",
                     "GoogleUtilities_Reachability"],
      path: "GoogleUtilities/Network",
      publicHeadersPath: "Private",
      cSettings: [
        .headerSearchPath("../.."),
      ]
      // linkerSettings: [
      //   .linkedFramework("Security"),
      // ]
    ),
    .target(
      name: "GoogleUtilities_NSData",
      path: "GoogleUtilities/NSData+zlib",
      publicHeadersPath: ".",
      cSettings: [
        .headerSearchPath("../.."),
      ],
      linkerSettings: [
        .linkedLibrary("z"),
      ]
    ),
    .target(
      name: "GoogleUtilities_Reachability",
      dependencies: ["GoogleUtilities_Logger"],
      path: "GoogleUtilities/Reachability",
      publicHeadersPath: "Private",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),
    .target(
      name: "GoogleUtilities_UserDefaults",
      dependencies: ["GoogleUtilities_Logger"],
      path: "GoogleUtilities/UserDefaults",
      publicHeadersPath: "Private", // Consider renaming "Private" directory to "Public"
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),
    .target(
      name: "Firebase",
      path: "Firebase/Sources",
      publicHeadersPath: "Public"
    ),
    .target(
      name: "FirebaseCore",
      dependencies: ["GoogleUtilities_Environment", "GoogleUtilities_Logger"],
      path: "FirebaseCore/Sources",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../.."),
        .define("FIRCore_VERSION", to: "0.0.1"), // TODO: Fix version
        .define("Firebase_VERSION", to: "0.0.1"), // TODO: Fix version
        // TODO: - Add support for cflags cSetting so that we can set the -fno-autolink option
      ]
    ),
    .target(
      name: "FirebaseAuth",
      dependencies: ["FirebaseCore", "GoogleUtilities_Environment",
                     "GoogleUtilities_AppDelegateSwizzler",
                     "GTMSessionFetcherCore"],
      path: "FirebaseAuth/Sources",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
        .define("FIRAuth_VERSION", to: "0.0.1"), // TODO: Fix version
        .define("FIRAuth_MINOR_VERSION", to: "1.1"), // TODO: Fix version
//        .define("DEBUG", .when(configuration: .debug)), // TODO - destroys other settings in DEBUG config
        // linkerSettings: [
        //   .linkedFramework("Security"),
        //  .linkedFramework("SafariServices", .when(platforms: [.iOS])),
      ]
    ),
//     .target(
//       name: "FirebaseFunctions",
//       dependencies: ["FirebaseCore", "GTMSessionFetcher_Core"],
//       path: "Functions/FirebaseFunctions",
//       publicHeadersPath: "Public",
//       cSettings: [
//          // SPM doesn't support interface frameworks or private headers
//         .headerSearchPath("../../"),
//         .define("FIRFunctions_VERSION", to: "0.0.1"),  // TODO Fix version
//         .define("SWIFT_PACKAGE", to: "1"),  // SPM loses defaults if other cSettings
//       ]),
    .target(
      name: "FirebaseInstanceID",
      dependencies: ["FirebaseCore", "FirebaseInstallations",
                     "GoogleUtilities_Environment", "GoogleUtilities_UserDefaults"],
      path: "Firebase/InstanceID",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
        .define("FIRInstanceID_LIB_VERSION", to: "0.0.1"), // TODO: Fix version
      ]
    ),
    .target(
      name: "FirebaseInstallations",
      dependencies: ["FirebaseCore", "FBLPromises",
                     "GoogleUtilities_Environment", "GoogleUtilities_UserDefaults"],
      path: "FirebaseInstallations/Source/Library",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../../"),
      ]
    ),
    .target(
      name: "FirebaseStorage",
      dependencies: ["FirebaseCore", "GTMSessionFetcherCore"],
      path: "FirebaseStorage/Sources",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
        .define("FIRStorage_VERSION", to: "0.0.1"), // TODO: Fix version
      ]
    ),
    .target(
      name: "FirebaseStorageSwift",
      dependencies: ["FirebaseStorage"],
      path: "FirebaseStorageSwift/Sources"
    ),
    .target(
      name: "GoogleDataTransport",
      path: "GoogleDataTransport/GDTCORLibrary",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../"),
        .define("GDTCOR_VERSION", to: "0.0.1"),
      ]
    ),
    .target(
      name: "GoogleDataTransportCCTSupport",
      dependencies: ["GoogleDataTransport", "nanopb"],
      path: "GoogleDataTransportCCTSupport/GDTCCTLibrary",
      cSettings: [
        .headerSearchPath("../"),
        .define("PB_FIELD_32BIT", to: "1"),
        .define("PB_NO_PACKED_STRUCTS", to: "1"),
        .define("PB_ENABLE_MALLOC", to: "1"),
      ]
    ),
//       linkerSettings: [
//         .linkedFramework("CoreServices", .when(platforms: [.macOS])),
//         .linkedFramework("MobileCoreServices", .when(platforms: [.iOS, .tvOS])),
//       ]),
  ],
  cLanguageStandard: .c99
)
