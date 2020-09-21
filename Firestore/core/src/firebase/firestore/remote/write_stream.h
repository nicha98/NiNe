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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_WRITE_STREAM_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_WRITE_STREAM_H_

#if !defined(__OBJC__)
#error "This header only supports Objective-C++"
#endif  // !defined(__OBJC__)

#include <memory>
#include <string>

#include "Firestore/core/src/firebase/firestore/remote/datastore.h"
#include "Firestore/core/src/firebase/firestore/remote/stream.h"
#include "Firestore/core/src/firebase/firestore/remote/stream_objc_bridge.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "absl/strings/string_view.h"
#include "grpcpp/support/byte_buffer.h"

#import <Foundation/Foundation.h>
#import "Firestore/Source/Core/FSTTypes.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"

namespace firebase {
namespace firestore {
namespace remote {

/**
 * A `Stream` that implements the StreamingWrite RPC.
 *
 * The StreamingWrite RPC requires the caller to maintain special stream token
 * state in-between calls, to help the server understand which responses the
 * client has processed by the time the next request is made. Every response may
 * contain a stream token; this value must be passed to the next request.
 *
 * After calling `Start` on this stream, the next request must be a handshake,
 * containing whatever stream token is on hand. Once a response to this request
 * is received, all pending mutations may be submitted. When submitting multiple
 * batches of mutations at the same time, it's okay to use the same stream token
 * for the calls to `WriteMutations`.
 */
class WriteStream : public Stream {
 public:
  WriteStream(util::AsyncQueue* async_queue,
              auth::CredentialsProvider* credentials_provider,
              FSTSerializerBeta* serializer,
              Datastore* datastore,
              id delegate);

  /**
   * The last received stream token from the server, used to acknowledge which
   * responses the client has processed. Stream tokens are opaque checkpoint
   * markers whose only real value is their inclusion in the next request.
   *
   * `WriteStream` manages propagating this value from responses to the next
   * request.
   */
  void SetLastStreamToken(NSData* token);
  NSData* GetLastStreamToken() const;

  /**
   * Sends an initial streamToken to the server, performing the handshake
   * required to make the StreamingWrite RPC work. Subsequent `WriteMutations`
   * calls should wait until a response has been delivered to the delegate's
   * `writeStreamDidCompleteHandshake` method.
   */
  void WriteHandshake();

  /** Sends a group of mutations to the Firestore backend to apply. */
  void WriteMutations(NSArray<FSTMutation*>* mutations);

  bool IsHandshakeComplete() const {
    return is_handshake_complete_;
  }

 private:
  std::unique_ptr<GrpcStream> CreateGrpcStream(
      Datastore* datastore, const absl::string_view token) override;
  void FinishGrpcStream(GrpcStream* call) override;

  void DoOnStreamStart() override;
  util::Status DoOnStreamRead(const grpc::ByteBuffer& message) override;
  void DoOnStreamFinish(const util::Status& status) override;

  std::string GetDebugName() const override {
    return "WriteStream";
  }

  bridge::WriteStreamSerializer serializer_bridge_;
  bridge::WriteStreamDelegate delegate_bridge_;
  bool is_handshake_complete_ = false;
  std::string last_stream_token_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_WRITE_STREAM_H_
