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

#include "Firestore/core/src/firebase/firestore/remote/grpc_stream.h"

#include <chrono>  // NOLINT(build/c++11)
#include <future>  // NOLINT(build/c++11)

#include "Firestore/core/src/firebase/firestore/remote/datastore.h"

namespace firebase {
namespace firestore {
namespace remote {

using util::AsyncQueue;

// The mechanism for calling async gRPC methods that `GrpcStream` uses is
// issuing `StreamOperation`s.
//
// To invoke an async method, `GrpcStream` will create a new `StreamOperation`
// and execute the operation; `StreamOperation` knows which gRPC method to
// invoke and it puts itself on the gRPC completion queue. `GrpcStream` does not
// have a reference to the gRPC completion queue (this allows using the same
// completion queue for all streams); it expects that some different class (in
// practice, `RemoteStore`) will poll the gRPC completion queue and `Complete`
// all `StreamOperation`s that come out of the queue.
// `StreamOperation::Complete` will invoke a corresponding callback on the
// `GrpcStream`. In turn, `GrpcStream` will decide whether to notify its
// observer.
//
// `GrpcStream` owns the gRPC objects (such as `grpc::ClientContext`) that must
// be valid until all `StreamOperation`s issued by this stream come back from
// the gRPC completion queue. `StreamOperation`s contain an `std::promise` that
// is fulfilled once the operation is taken off the gRPC completion queue, and
// `StreamOperation::WaitUntilOffQueue` allows blocking on this. `GrpcStream`
// holds non-owning pointers to all operations that it issued (and removes
// pointers to completed operations). `GrpcStream::Finish` and
// `GrpcStream::WriteAndFinish` block on `StreamOperation::WaitUntilOffQueue`
// for all the currently-pending operations, thus ensuring that the stream can
// be safely released (along with the gRPC objects the stream owns) after
// `Finish` or `WriteAndFinish` have completed.

namespace internal {

StreamWrite* BufferedWriter::EnqueueWrite(grpc::ByteBuffer&& write) {
  queue_.push(write);
  return TryStartWrite();
}

StreamWrite* BufferedWriter::TryStartWrite() {
  if (queue_.empty() || has_active_write_) {
    return nullptr;
  }

  has_active_write_ = true;
  grpc::ByteBuffer message = std::move(queue_.front());
  queue_.pop();
  return new StreamWrite{stream_, std::move(message)};
}

StreamWrite* BufferedWriter::DequeueNextWrite() {
  has_active_write_ = false;
  return TryStartWrite();
}

}  // namespace internal

using internal::BufferedWriter;

GrpcStream::GrpcStream(
    std::unique_ptr<grpc::ClientContext> context,
    std::unique_ptr<grpc::GenericClientAsyncReaderWriter> call,
    GrpcStreamObserver* observer,
    AsyncQueue* firestore_queue)
    : context_{std::move(context)},
      call_{std::move(call)},
      observer_{observer},
      firestore_queue_{firestore_queue},
      buffered_writer_{this} {
}

GrpcStream::~GrpcStream() {
  HARD_ASSERT(operations_.empty(),
              "GrpcStream is being destroyed without proper shutdown");
}

void GrpcStream::Start() {
  Execute(new StreamStart{this});
}

void GrpcStream::Read() {
  if (observer_) {
    Execute(new StreamRead{this});
  }
}

void GrpcStream::Write(grpc::ByteBuffer&& message) {
  BufferedWrite(std::move(message));
}

void GrpcStream::Finish() {
  UnsetObserver();

  if (operations_.empty()) {
    // Nothing to cancel.
    return;
  }

  // Important: since the stream always has a pending read operation,
  // cancellation has to be called, or else the read would hang forever, and
  // finish operation will never get completed.
  //
  // (on the other hand, when an operation fails, cancellation should not be
  // called, otherwise the real failure cause will be overwritten by status
  // "canceled".)
  context_->TryCancel();
  // TODO(varconst): is issuing a finish operation necessary in this case? We
  // don't care about the status, but perhaps it will make the server notice
  // client disconnecting sooner?
  Execute(new ClientInitiatedFinish{this});

  FastFinishOperationsBlocking();
}

void GrpcStream::FastFinishOperationsBlocking() {
  // TODO(varconst): reset buffered_writer_? Should not be necessary, because it
  // should never be called again after a call to Finish.

  for (auto operation : operations_) {
    // `GrpcStream` cannot cancel the completion of any operations that might
    // already have been enqueued on the Firestore queue, so instead turn those
    // completions into no-ops.
    operation->UnsetObserver();
  }

  for (auto operation : operations_) {
    // This is blocking.
    operation->WaitUntilOffQueue();
  }
  operations_.clear();
}

bool GrpcStream::WriteAndFinish(grpc::ByteBuffer&& message) {
  bool did_last_write = false;

  StreamWrite* last_write_operation = BufferedWrite(std::move(message));
  // Only bother with the last write if there is no active write at the moment.
  if (last_write_operation) {
    last_write_operation->UnsetObserver();
    // Empirically, the write normally takes less than a millisecond to finish
    // (both with and without network connection), and never more than several
    // dozen milliseconds. Nevertheless, ensure `WriteAndFinish` doesn't hang if
    // there happen to be circumstances under which the write may block
    // indefinitely (in that case, rely on the fact that canceling GRPC call
    // makes all pending operations come back from the queue quickly).
    auto status =
        last_write_operation->WaitUntilOffQueue(std::chrono::milliseconds(500));
    if (status == std::future_status::ready) {
      RemoveOperation(last_write_operation);
      did_last_write = true;
    }
  }

  Finish();
  return did_last_write;
}

StreamWrite* GrpcStream::BufferedWrite(grpc::ByteBuffer&& message) {
  StreamWrite* maybe_write = buffered_writer_.EnqueueWrite(std::move(message));
  if (maybe_write) {
    Execute(maybe_write);
  }
  return maybe_write;
}

GrpcStream::MetadataT GrpcStream::GetResponseHeaders() const {
  return context_->GetServerInitialMetadata();
}

// Callbacks

void GrpcStream::OnStart() {
  if (observer_) {
    observer_->OnStreamStart();
    // Start listening for new messages.
    Read();
  }
}

void GrpcStream::OnRead(const grpc::ByteBuffer& message) {
  if (observer_) {
    observer_->OnStreamRead(message);
    // Continue waiting for new messages indefinitely as long as there is an
    // interested observer.
    Read();
  }
}

void GrpcStream::OnWrite() {
  if (observer_) {
    StreamWrite* maybe_write = buffered_writer_.DequeueNextWrite();
    if (maybe_write) {
      Execute(maybe_write);
    }
    // Observer is not interested in this event.
  }
}

void GrpcStream::OnOperationFailed() {
  if (is_finishing_) {
    // `Finish` itself cannot fail. If another failed operation already
    // triggered `Finish`, there's nothing to do.
    return;
  }

  is_finishing_ = true;

  if (observer_) {
    Execute(new RemoteInitiatedFinish{this});
  } else {
    // The only reason to finish would be to get the status; if the observer is
    // no longer interested, there is no need to do that.
    FastFinishOperationsBlocking();
  }
}

void GrpcStream::OnFinishedByServer(const grpc::Status& status) {
  FastFinishOperationsBlocking();

  if (observer_) {
    // The call to observer could end this `GrpcStream`'s lifetime.
    GrpcStreamObserver* observer = observer_;
    UnsetObserver();
    observer->OnStreamError(Datastore::ConvertStatus(status));
  }
}

void GrpcStream::OnFinishedByClient() {
  // The observer is not interested in this event -- since it initiated the
  // finish operation, the observer must know the reason.
}

void GrpcStream::RemoveOperation(const StreamOperation* to_remove) {
  auto found = std::find(operations_.begin(), operations_.end(), to_remove);
  HARD_ASSERT(found != operations_.end(), "Missing StreamOperation");
  operations_.erase(found);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
