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

#include <initializer_list>
#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/src/firebase/firestore/auth/empty_credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_operation.h"
#include "Firestore/core/src/firebase/firestore/remote/stream.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/executor_std.h"
#include "Firestore/core/test/firebase/firestore/util/grpc_tests_util.h"
#include "absl/memory/memory.h"
#include "grpcpp/client_context.h"
#include "grpcpp/completion_queue.h"
#include "grpcpp/create_channel.h"
#include "grpcpp/generic/generic_stub.h"
#include "grpcpp/support/byte_buffer.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {

using auth::CredentialsProvider;
using auth::EmptyCredentialsProvider;
using auth::Token;
using auth::TokenListener;
using util::AsyncQueue;
using util::GrpcStreamFixture;
using util::OperationResult;
using util::OperationResult::Error;
using util::OperationResult::Ok;
using util::TimerId;
using util::internal::ExecutorStd;

namespace {

const auto kIdleTimerId = TimerId::ListenStreamIdle;

class MockCredentialsProvider : public EmptyCredentialsProvider {
 public:
  void FailGetToken() {
    fail_get_token_ = true;
  }
  void DelayGetToken() {
    delay_get_token_ = true;
  }

  void GetToken(TokenListener completion) override {
    observed_states_.push_back("GetToken");

    if (delay_get_token_) {
      delayed_token_listener_ = completion;
      return;
    }

    if (fail_get_token_) {
      if (completion) {
        completion(util::Status{FirestoreErrorCode::Unknown, ""});
      }
    } else {
      EmptyCredentialsProvider::GetToken(std::move(completion));
    }
  }

  void InvokeGetToken() {
    delay_get_token_ = false;
    EmptyCredentialsProvider::GetToken(std::move(delayed_token_listener_));
  }

  void InvalidateToken() override {
    observed_states_.push_back("InvalidateToken");
    EmptyCredentialsProvider::InvalidateToken();
  }

  const std::vector<std::string>& observed_states() const {
    return observed_states_;
  }

 private:
  std::vector<std::string> observed_states_;
  bool fail_get_token_ = false;
  bool delay_get_token_ = false;
  TokenListener delayed_token_listener_;
};

class TestStream : public Stream {
 public:
  TestStream(GrpcStreamFixture* fixture,
             CredentialsProvider* credentials_provider)
      : Stream{&fixture->async_queue(), credentials_provider,
               /*Datastore=*/nullptr, TimerId::ListenStreamConnectionBackoff,
               kIdleTimerId},
        fixture_{fixture} {
  }

  void WriteEmptyBuffer() {
    Write({});
  }

  void FailStreamRead() {
    fail_stream_read_ = true;
  }

  const std::vector<std::string>& observed_states() const {
    return observed_states_;
  }

 private:
  std::unique_ptr<GrpcStream> CreateGrpcStream(
      Datastore* datastore, absl::string_view token) override {
    return fixture_->CreateStream(this);
  }
  void FinishGrpcStream(GrpcStream* stream) override {
    stream->Finish();
  }

  void DoOnStreamStart() override {
    observed_states_.push_back("OnStreamStart");
  }

  util::Status DoOnStreamRead(const grpc::ByteBuffer& message) override {
    observed_states_.push_back("OnStreamRead");
    if (fail_stream_read_) {
      fail_stream_read_ = false;
      return util::Status{FirestoreErrorCode::Internal, ""};
    }
    return util::Status::OK();
  }

  void DoOnStreamFinish(const util::Status& status) override {
    observed_states_.push_back(std::string{"OnStreamStop("} +
                               std::to_string(status.code()) + ")");
  }

  std::string GetDebugName() const override {
    return "";
  }

  GrpcStreamFixture* fixture_ = nullptr;
  std::vector<std::string> observed_states_;
  bool fail_stream_read_ = false;
};

}  // namespace

class StreamTest : public testing::Test {
 public:
  StreamTest()
      : firestore_stream{
            std::make_shared<TestStream>(&fixture_, &credentials)} {
  }

  ~StreamTest() {
    async_queue().EnqueueBlocking([&] {
      if (firestore_stream && firestore_stream->IsStarted()) {
        fixture_.KeepPollingGrpcQueue();
        firestore_stream->Stop();
      }
    });
    fixture_.Shutdown();
  }

  void ForceFinish(std::initializer_list<OperationResult> results) {
    fixture_.ForceFinish(results);
  }
  void KeepPollingGrpcQueue() {
    fixture_.KeepPollingGrpcQueue();
  }

  void StartStream() {
    async_queue().EnqueueBlocking([&] { firestore_stream->Start(); });
    ForceFinish({/*Start*/ Ok});
  }

  const std::vector<std::string>& observed_states() const {
    return firestore_stream->observed_states();
  }

  // This is to make `EXPECT_EQ` a little shorter and work around macro
  // limitations related to initializer lists.
  std::vector<std::string> States(std::initializer_list<std::string> states) {
    return {states};
  }

  AsyncQueue& async_queue() {
    return fixture_.async_queue();
  }

 private:
  GrpcStreamFixture fixture_;

 public:
  MockCredentialsProvider credentials;
  std::shared_ptr<TestStream> firestore_stream;
};

TEST_F(StreamTest, CanStart) {
  async_queue().EnqueueBlocking([&] {
    EXPECT_NO_THROW(firestore_stream->Start());
    EXPECT_TRUE(firestore_stream->IsStarted());
    EXPECT_FALSE(firestore_stream->IsOpen());
  });
}

TEST_F(StreamTest, CannotStartTwice) {
  async_queue().EnqueueBlocking([&] {
    EXPECT_NO_THROW(firestore_stream->Start());
    EXPECT_ANY_THROW(firestore_stream->Start());
  });
}

TEST_F(StreamTest, CanStopBeforeStarting) {
  async_queue().EnqueueBlocking(
      [&] { EXPECT_NO_THROW(firestore_stream->Stop()); });
}

TEST_F(StreamTest, CanStopAfterStarting) {
  async_queue().EnqueueBlocking([&] {
    EXPECT_NO_THROW(firestore_stream->Start());
    EXPECT_TRUE(firestore_stream->IsStarted());
    EXPECT_NO_THROW(firestore_stream->Stop());
    EXPECT_FALSE(firestore_stream->IsStarted());
  });
}

TEST_F(StreamTest, CanStopTwice) {
  async_queue().EnqueueBlocking([&] {
    EXPECT_NO_THROW(firestore_stream->Start());
    EXPECT_NO_THROW(firestore_stream->Stop());
    EXPECT_NO_THROW(firestore_stream->Stop());
  });
}

TEST_F(StreamTest, CannotWriteBeforeOpen) {
  async_queue().EnqueueBlocking([&] {
    EXPECT_ANY_THROW(firestore_stream->WriteEmptyBuffer());
    firestore_stream->Start();
    EXPECT_ANY_THROW(firestore_stream->WriteEmptyBuffer());
  });
}

TEST_F(StreamTest, CanOpen) {
  StartStream();
  async_queue().EnqueueBlocking([&] {
    EXPECT_TRUE(firestore_stream->IsStarted());
    EXPECT_TRUE(firestore_stream->IsOpen());
    EXPECT_EQ(observed_states(), States({"OnStreamStart"}));
  });
}

TEST_F(StreamTest, CanStop) {
  StartStream();
  async_queue().EnqueueBlocking([&] {
    KeepPollingGrpcQueue();
    firestore_stream->Stop();

    EXPECT_FALSE(firestore_stream->IsStarted());
    EXPECT_FALSE(firestore_stream->IsOpen());
    EXPECT_EQ(observed_states(), States({"OnStreamStart", "OnStreamStop(0)"}));
  });
}

TEST_F(StreamTest, GrpcFailureOnStart) {
  async_queue().EnqueueBlocking([&] { firestore_stream->Start(); });
  ForceFinish({/*Start*/ Error, /*Finish*/ Ok});

  async_queue().EnqueueBlocking([&] {
    EXPECT_FALSE(firestore_stream->IsStarted());
    EXPECT_FALSE(firestore_stream->IsOpen());
    EXPECT_EQ(observed_states(), States({"OnStreamStop(1)"}));
  });
}

TEST_F(StreamTest, AuthFailureOnStart) {
  credentials.FailGetToken();
  async_queue().EnqueueBlocking([&] { firestore_stream->Start(); });

  async_queue().EnqueueBlocking([&] {
    EXPECT_FALSE(firestore_stream->IsStarted());
    EXPECT_FALSE(firestore_stream->IsOpen());
    EXPECT_EQ(observed_states(), States({"OnStreamStop(2)"}));
  });
}

TEST_F(StreamTest, AuthWhenStreamHasBeenStopped) {
  credentials.DelayGetToken();
  async_queue().EnqueueBlocking([&] {
    firestore_stream->Start();
    firestore_stream->Stop();
  });
  credentials.InvokeGetToken();
}

TEST_F(StreamTest, AuthOutlivesStream) {
  credentials.DelayGetToken();
  async_queue().EnqueueBlocking([&] {
    firestore_stream->Start();
    firestore_stream->Stop();
    firestore_stream.reset();
  });
  credentials.InvokeGetToken();
}

TEST_F(StreamTest, ErrorAfterStart) {
  StartStream();
  ForceFinish({/*Read*/ Error, /*Finish*/ Ok});
  async_queue().EnqueueBlocking([&] {
    EXPECT_FALSE(firestore_stream->IsStarted());
    EXPECT_FALSE(firestore_stream->IsOpen());
    EXPECT_EQ(observed_states(), States({"OnStreamStart", "OnStreamStop(1)"}));
  });
}

TEST_F(StreamTest, ClosesOnIdle) {
  StartStream();

  async_queue().EnqueueBlocking([&] { firestore_stream->MarkIdle(); });

  KeepPollingGrpcQueue();
  EXPECT_TRUE(async_queue().IsScheduled(kIdleTimerId));
  async_queue().RunScheduledOperationsUntil(kIdleTimerId);
  async_queue().EnqueueBlocking([&] {
    EXPECT_FALSE(firestore_stream->IsStarted());
    EXPECT_FALSE(firestore_stream->IsOpen());
    EXPECT_EQ(observed_states().back(), "OnStreamStop(0)");
  });
}

TEST_F(StreamTest, ClientSideErrorOnRead) {
  StartStream();

  firestore_stream->FailStreamRead();
  ForceFinish({/*Read*/ Ok});

  KeepPollingGrpcQueue();
  async_queue().EnqueueBlocking([&] {
    EXPECT_FALSE(firestore_stream->IsStarted());
    EXPECT_FALSE(firestore_stream->IsOpen());
    EXPECT_EQ(observed_states().back(), "OnStreamStop(13)");
  });
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
