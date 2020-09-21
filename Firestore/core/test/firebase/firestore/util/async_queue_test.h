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

#ifndef FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_UTIL_ASYNC_QUEUE_TEST_H_
#define FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_UTIL_ASYNC_QUEUE_TEST_H_

#include <memory>

#include "gtest/gtest.h"

#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/test/firebase/firestore/util/async_tests_util.h"

namespace firebase {
namespace firestore {
namespace util {

using FactoryFunc = std::unique_ptr<internal::Executor> (*)();

class AsyncQueueTest : public TestWithTimeoutMixin,
                       public ::testing::TestWithParam<FactoryFunc> {
 public:
  // `GetParam()` must return a factory function.
  AsyncQueueTest() : queue{GetParam()()} {
  }

  AsyncQueue queue;
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_UTIL_ASYNC_QUEUE_TEST_H_
