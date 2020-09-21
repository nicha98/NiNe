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

#ifndef FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_UTIL_GRPC_STREAM_TESTER_H_
#define FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_UTIL_GRPC_STREAM_TESTER_H_

#include <initializer_list>
#include <memory>

#include "Firestore/core/src/firebase/firestore/remote/grpc_completion.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_stream.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_streaming_reader.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/executor_std.h"
#include "absl/types/optional.h"
#include "grpcpp/client_context.h"
#include "grpcpp/completion_queue.h"
#include "grpcpp/create_channel.h"
#include "grpcpp/generic/generic_stub.h"

namespace firebase {
namespace firestore {
namespace util {

enum CompletionResult { Ok, Error };
struct CompletionEndState {
  CompletionEndState(CompletionResult result)  // NOLINT(runtime/explicit)
      : result{result} {
  }
  CompletionEndState(const grpc::Status& status)  // NOLINT(runtime/explicit)
      : result{Ok}, maybe_status{status} {
  }

  CompletionResult result;
  absl::optional<grpc::Status> maybe_status;
};

/**
 * Does the somewhat complicated setup required to create a `GrpcStream` and
 * allows imitating the normal completion of `GrpcCompletion`s.
 */
class GrpcStreamTester {
 public:
  GrpcStreamTester();
  ~GrpcStreamTester();

  /** Finishes the stream and shuts down the gRPC completion queue. */
  void Shutdown();

  std::unique_ptr<remote::GrpcStream> CreateStream(
      remote::GrpcStreamObserver* observer);
  std::unique_ptr<remote::GrpcStreamingReader> CreateStreamingReader();

  /**
   * Takes as many completions off gRPC completion queue as there are elements
   * in `results` and completes each of them with the corresponding result,
   * ignoring the actual result from gRPC.
   *
   * This is a blocking function; it will finish quickly if the gRPC completion
   * queue has at least as many pending completions as there are elements in
   * `results`; otherwise, it will hang.
   */
  void ForceFinish(std::initializer_list<CompletionEndState> results);

  /**
   * Using a separate executor, keep polling gRPC completion queue and tell all
   * the completions that come off the queue that they finished successfully,
   * ignoring the actual result from gRPC.
   *
   * Call this method before calling the blocking functions `GrpcStream::Finish`
   * or `GrpcStream::WriteAndFinish`, otherwise they would hang.
   */
  void KeepPollingGrpcQueue();

  void ShutdownGrpcQueue();

  AsyncQueue& worker_queue() {
    return worker_queue_;
  }

 private:
  std::unique_ptr<internal::ExecutorStd> dedicated_executor_;
  AsyncQueue worker_queue_;

  grpc::GenericStub grpc_stub_;
  grpc::CompletionQueue grpc_queue_;
  // Context is needed to be able to cancel pending operations.
  grpc::ClientContext* grpc_context_ = nullptr;

  bool is_shut_down_ = false;
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_UTIL_GRPC_STREAM_TESTER_H_
