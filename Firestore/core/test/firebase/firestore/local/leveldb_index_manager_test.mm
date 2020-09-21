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

#include "Firestore/core/test/firebase/firestore/local/index_manager_test.h"

#import "Firestore/Example/Tests/Local/FSTPersistenceTestHelpers.h"
#import "Firestore/Source/Local/FSTPersistence.h"

#include "Firestore/core/src/firebase/firestore/local/leveldb_index_manager.h"
#include "absl/memory/memory.h"
#include "gtest/gtest.h"

NS_ASSUME_NONNULL_BEGIN

namespace firebase {
namespace firestore {
namespace local {

namespace {

id<FSTPersistence> PersistenceFactory() {
  return static_cast<id<FSTPersistence>>(
      [FSTPersistenceTestHelpers levelDBPersistence]);
}

}  // namespace

INSTANTIATE_TEST_CASE_P(LevelDbIndexManagerTest,
                        IndexManagerTest,
                        ::testing::Values(PersistenceFactory));

NS_ASSUME_NONNULL_END

}  // namespace local
}  // namespace firestore
}  // namespace firebase
