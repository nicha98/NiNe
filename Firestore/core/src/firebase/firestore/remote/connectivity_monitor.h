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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_CONNECTIVITY_MONITOR_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_CONNECTIVITY_MONITOR_H_

#include <functional>
#include <memory>
#include <utility>
#include <vector>

#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace remote {

class ConnectivityMonitor {
 public:
  enum class NetworkStatus {
    Unreachable,
    Reachable,
    ReachableViaCellular,
  };

  using CallbackT = std::function<void(NetworkStatus)>;

  static std::unique_ptr<ConnectivityMonitor> Create(
      util::AsyncQueue* worker_queue);

  explicit ConnectivityMonitor(util::AsyncQueue* worker_queue)
      : worker_queue_{worker_queue} {
  }

  virtual ~ConnectivityMonitor() {
  }

  void AddCallback(CallbackT&& callback) {
    callbacks_.push_back(std::move(callback));
  }

 protected:
  void SetInitialStatus(NetworkStatus new_status);
  void MaybeInvokeCallbacks(NetworkStatus new_status);

 private:
  util::AsyncQueue* worker_queue_ = nullptr;
  std::vector<CallbackT> callbacks_;
  absl::optional<NetworkStatus> status_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_CONNECTIVITY_MONITOR_H_
