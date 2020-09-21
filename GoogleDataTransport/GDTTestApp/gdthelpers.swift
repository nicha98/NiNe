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

import GoogleDataTransport

// For use by GDT.
class TestDataObject: NSObject, GDTCOREventDataObject {
  func transportBytes() -> Data {
    return "Normally, some SDK's data object would populate this. \(Date())"
      .data(using: String.Encoding.utf8)!
  }
}

class TestPrioritizer: NSObject, GDTCORPrioritizer {
  func prioritizeEvent(_ event: GDTCOREvent) {}

  func uploadPackage(with target: GDTCORTarget,
                     conditions: GDTCORUploadConditions) -> GDTCORUploadPackage {
    return GDTCORUploadPackage(target: GDTCORTarget.test)
  }
}

class TestUploader: NSObject, GDTCORUploader {
  func ready(toUploadTarget target: GDTCORTarget, conditions: GDTCORUploadConditions) -> Bool {
    return false
  }

  func uploadPackage(_ package: GDTCORUploadPackage) {}
}
