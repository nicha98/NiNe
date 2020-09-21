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

#include "Firestore/core/src/firebase/firestore/immutable/array_sorted_map.h"

#include <numeric>
#include <random>

#include "Firestore/core/src/firebase/firestore/util/secure_random.h"

#include "Firestore/core/test/firebase/firestore/immutable/testing.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace immutable {
namespace impl {

using IntMap = ArraySortedMap<int, int>;
constexpr IntMap::size_type kFixedSize = IntMap::kFixedSize;

TEST(ArraySortedMap, ChecksSize) {
  std::vector<int> to_insert = Sequence(kFixedSize);
  IntMap map = ToMap<IntMap>(to_insert);

  // Replacing an existing entry should not hit increase size
  map = map.insert(5, 10);

  int next = kFixedSize;
  ASSERT_ANY_THROW(map.insert(next, next));
}

}  // namespace impl
}  // namespace immutable
}  // namespace firestore
}  // namespace firebase
