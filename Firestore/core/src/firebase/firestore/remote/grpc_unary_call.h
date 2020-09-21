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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_UNARY_CALL_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_UNARY_CALL_H_

#include <functional>
#include <map>
#include <memory>

#include "Firestore/core/src/firebase/firestore/remote/grpc_call_interface.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_completion.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "grpcpp/client_context.h"
#include "grpcpp/generic/generic_stub.h"
#include "grpcpp/support/byte_buffer.h"

namespace firebase {
namespace firestore {
namespace remote {

class GrpcConnection;

/**
 * Sends a single request to the server and invokes the given callback with the
 * server response.
 */
class GrpcUnaryCall : public GrpcCallInterface {
 public:
  using MetadataT = std::multimap<grpc::string_ref, grpc::string_ref>;
  /**
   * The first argument is status of the call; the second argument is the server
   * response.
   */
  using CallbackT =
      std::function<void(const util::Status&, const grpc::ByteBuffer&)>;

  GrpcUnaryCall(std::unique_ptr<grpc::ClientContext> context,
                std::unique_ptr<grpc::GenericClientAsyncResponseReader> call,
                util::AsyncQueue* worker_queue,
                GrpcConnection* grpc_connection,
                const grpc::ByteBuffer& request);
  ~GrpcUnaryCall();

  /**
   * Starts the call; the given `callback` will be invoked with the result of
   * the call. If the call fails, the `callback` will be invoked with a non-ok
   * status.
   */
  void Start(CallbackT&& callback);

  /**
   * If the call is in progress, attempts to cancel the call; otherwise, it's
   * a no-op. Cancellation is done on best-effort basis; however:
   * - the call is guaranteed to be finished when this function returns;
   * - this function is blocking but should finish very fast (order of
   *   milliseconds).
   *
   * If this function succeeds in cancelling the call, the callback will not be
   * invoked.
   */
  void Cancel() override;

  void Cancel(const util::Status& status) override;

  /**
   * Returns the metadata received from the server.
   *
   * Can only be called once the `GrpcUnaryCall` has finished.
   */
  MetadataT GetResponseHeaders() const;

 private:
  void FastFinishCompletion();

  // See comments in `GrpcStream` on lifetime issues for gRPC objects.
  std::unique_ptr<grpc::ClientContext> context_;
  std::unique_ptr<grpc::GenericClientAsyncResponseReader> call_;
  // Stored to avoid lifetime issues with gRPC.
  grpc::ByteBuffer request_;

  util::AsyncQueue* worker_queue_ = nullptr;
  GrpcConnection* grpc_connection_ = nullptr;

  GrpcCompletion* finish_completion_ = nullptr;
  CallbackT callback_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_UNARY_CALL_H_
