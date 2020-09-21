/*
 * Copyright 2017 Google
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

#import <XCTest/XCTest.h>

#include "Firestore/core/src/firebase/firestore/local/mutation_queue.h"

namespace firebase {
namespace firestore {
namespace local {

class MutationQueue;
class Persistence;

}  // namespace local
}  // namespace firestore
}  // namespace firebase

namespace local = firebase::firestore::local;

NS_ASSUME_NONNULL_BEGIN

/**
 * These are tests for any implementation of the MutationQueue interface.
 *
 * To test a specific implementation of MutationQueue:
 *
 * + Subclass FSTMutationQueueTests
 * + override -setUp, assigning to mutationQueue and persistence
 * + override -tearDown, cleaning up mutationQueue and persistence
 */
@interface FSTMutationQueueTests : XCTestCase

@property(nonatomic, nullable) local::MutationQueue *mutationQueue;

@property(nonatomic, nullable) local::Persistence *persistence;

@end

NS_ASSUME_NONNULL_END
