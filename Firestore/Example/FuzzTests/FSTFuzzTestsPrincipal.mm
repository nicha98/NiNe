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

#import <Foundation/NSObject.h>

#include "LibFuzzer/FuzzerDefs.h"

#include "Firestore/core/src/firebase/firestore/remote/serializer.h"

using firebase::firestore::remote::Serializer;

namespace {

// Fuzz-test the deserialization process in Firestore. The Serializer reads raw
// bytes and converts them to a model object.
void FuzzTestDeserialization(const uint8_t *data, size_t size) {
  // TODO(minafarid): fuzz-test Serializer.
}

// Contains the code to be fuzzed. Called by the fuzzing library with
// different argument values for `data` and `size`.
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  FuzzTestDeserialization(data, size);
  return 0;
}

// Simulates calling the main() function of libFuzzer (FuzzerMain.cpp).
int RunFuzzTestingMain() {
  // Arguments to libFuzzer main() function should be added to this array,
  // e.g., dictionaries, corpus, number of runs, jobs, etc.
  char *program_args[] = {
      const_cast<char *>("RunFuzzTestingMain")  // First arg is program name.
  };
  char **argv = program_args;
  int argc = sizeof(program_args) / sizeof(program_args[0]);

  // Start fuzzing using libFuzzer's driver.
  return fuzzer::FuzzerDriver(&argc, &argv, LLVMFuzzerTestOneInput);
}

}  // namespace

/**
 * This class is registered as the NSPrincipalClass in the
 * Firestore_FuzzTests_iOS bundle's Info.plist. XCTest instantiates this class
 * to perform one-time setup for the test bundle, as documented here:
 *
 *   https://developer.apple.com/documentation/xctest/xctestobservationcenter
 */
@interface FSTFuzzTestsPrincipal : NSObject
@end

@implementation FSTFuzzTestsPrincipal

- (instancetype)init {
  self = [super init];
  RunFuzzTestingMain();
  return self;
}

@end
