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

#include "Firestore/core/src/firebase/firestore/remote/connectivity_monitor.h"

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>

#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "absl/memory/memory.h"
#include "dispatch/dispatch.h"

namespace firebase {
namespace firestore {
namespace remote {

namespace {

using NetworkStatus = ConnectivityMonitor::NetworkStatus;
using util::AsyncQueue;

NetworkStatus ToNetworkStatus(SCNetworkReachabilityFlags flags) {
  if (!(flags & kSCNetworkReachabilityFlagsReachable)) {
    return NetworkStatus::Unreachable;
  }
  if (flags & kSCNetworkReachabilityFlagsConnectionRequired) {
    return NetworkStatus::Unreachable;
  }

#if TARGET_OS_IPHONE
  if (flags & kSCNetworkReachabilityFlagsIsWWAN) {
    return NetworkStatus::ReachableViaCellular;
  }
#endif
  return NetworkStatus::Reachable;
}

SCNetworkReachabilityRef CreateReachability() {
  sockaddr_in any_connection_addr{};
  any_connection_addr.sin_len = sizeof(any_connection_addr);
  any_connection_addr.sin_family = AF_INET;
  return SCNetworkReachabilityCreateWithAddress(
      nullptr, reinterpret_cast<sockaddr*>(&any_connection_addr));
}

}  // namespace

class ConnectivityMonitorApple : public ConnectivityMonitor {
 public:
  ConnectivityMonitorApple(AsyncQueue* worker_queue)
      : ConnectivityMonitor{worker_queue}, reachability_{CreateReachability()} {
    SCNetworkReachabilityFlags flags;
    if (SCNetworkReachabilityGetFlags(reachability_, &flags)) {
      SetInitialStatus(ToNetworkStatus(flags));
    }

    auto on_reachability_changed = [](SCNetworkReachabilityRef /*unused*/,
                                      SCNetworkReachabilityFlags flags,
                                      void* raw_this) {
      HARD_ASSERT(raw_this, "Received a null pointer as context");
      static_cast<ConnectivityMonitorApple*>(raw_this)->OnChange(flags);
    };

    SCNetworkReachabilityContext context{};
    context.info = this;
    bool success = SCNetworkReachabilitySetCallback(
        reachability_, on_reachability_changed, &context);
    if (!success) {
      LOG_DEBUG("Couldn't set reachability callback");
      return;
    }

    auto queue =
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    success = SCNetworkReachabilitySetDispatchQueue(reachability_, queue);
    if (!success) {
      LOG_DEBUG("Couldn't set reachability queue");
      return;
    }
  }

  ~ConnectivityMonitorApple() {
    bool success =
        SCNetworkReachabilitySetCallback(reachability_, nullptr, nullptr);
    if (!success) {
      LOG_DEBUG("Couldn't unset reachability callback");
      return;
    }
    success = SCNetworkReachabilitySetDispatchQueue(reachability_, nullptr);
    if (!success) {
      LOG_DEBUG("Couldn't unset reachability queue");
      return;
    }
  }

 private:
  void OnChange(SCNetworkReachabilityFlags flags) {
    MaybeInvokeCallbacks(ToNetworkStatus(flags));
  }

  SCNetworkReachabilityRef reachability_;
};

std::unique_ptr<ConnectivityMonitor> ConnectivityMonitor::Create(
    AsyncQueue* worker_queue) {
  return absl::make_unique<ConnectivityMonitorApple>(worker_queue);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
