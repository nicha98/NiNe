/*
 * Copyright 2018 Google
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

#import <Foundation/Foundation.h>
#include <cstddef>
#include <cstdint>

#import "Firestore/Example/FuzzTests/FuzzingTargets/FSTFuzzTestSerializer.h"

#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/nanopb/reader.h"
#include "Firestore/core/src/firebase/firestore/remote/serializer.h"

namespace firebase {
namespace firestore {
namespace fuzzing {

using firebase::firestore::model::DatabaseId;
using firebase::firestore::nanopb::Reader;
using firebase::firestore::remote::Serializer;

int FuzzTestDeserialization(const uint8_t *data, size_t size) {
  Serializer serializer{DatabaseId{"project", DatabaseId::kDefault}};

  @autoreleasepool {
    @try {
      Reader reader = Reader::Wrap(data, size);
      google_firestore_v1_Value nanopb_proto{};
      reader.ReadNanopbMessage(google_firestore_v1_Value_fields, &nanopb_proto);
      serializer.DecodeFieldValue(&reader, nanopb_proto);
    } @catch (...) {
      // Caught exceptions are ignored because the input might be malformed and
      // the deserialization might throw an error as intended. Fuzzing focuses on
      // runtime errors that are detected by the sanitizers.
    }
  }

  return 0;
}

}  // namespace fuzzing
}  // namespace firestore
}  // namespace firebase
