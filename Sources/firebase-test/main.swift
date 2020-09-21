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

import Foundation
import Firebase
import FirebaseCore
import FirebaseAuth
// import FirebaseFunctions
import FirebaseInstallations
import FirebaseInstanceID
import FirebaseStorage
import FirebaseStorageSwift
import GoogleDataTransport
// import GoogleDataTransportCCTSupport
import GoogleUtilities_Environment
import GoogleUtilities_Logger

print("Hello world!")
print("Is app store receipt sandbox? Answer: \(GULAppEnvironmentUtil.isAppStoreReceiptSandbox())")
print("Is from app store? Answer: \(GULAppEnvironmentUtil.isFromAppStore())")
print("Is this the simulator? Answer: \(GULAppEnvironmentUtil.isSimulator())")
print("Device model? Answer: \(GULAppEnvironmentUtil.deviceModel() ?? "NONE")")
print("System version? Answer: \(GULAppEnvironmentUtil.systemVersion() ?? "NONE")")
print("Is App extension? Answer: \(GULAppEnvironmentUtil.isAppExtension())")
print("Is iOS 7 or higher? Answer: \(GULAppEnvironmentUtil.isIOS7OrHigher())")

print("Is there a default app? Answer: \(FirebaseApp.app() != nil)")

print("Storage Version String? Answer: \(String(cString: StorageVersionString))")

// print("InstanceIDScopeFirebaseMessaging? Answer: \(InstanceIDScopeFirebaseMessaging)")
