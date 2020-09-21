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

#include <memory>
#include <string>
#include <vector>

#include "Firestore/core/src/firebase/firestore/remote/datastore.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/executor_libdispatch.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/test/firebase/firestore/util/fake_credentials_provider.h"
#include "Firestore/core/test/firebase/firestore/util/grpc_stream_tester.h"
#include "absl/memory/memory.h"
#include "gtest/gtest.h"

#import "Firestore/Protos/objc/google/firestore/v1/Document.pbobjc.h"
#import "Firestore/Protos/objc/google/firestore/v1/Firestore.pbobjc.h"

namespace firebase {
namespace firestore {
namespace remote {

using auth::CredentialsProvider;
using core::DatabaseInfo;
using model::DatabaseId;
using util::AsyncQueue;
using util::MakeByteBuffer;
using util::CompletionEndState;
using util::GrpcStreamTester;
using util::FakeCredentialsProvider;
using util::FakeGrpcQueue;
using util::WrapNSString;
using util::ExecutorLibdispatch;
using util::CompletionResult::Error;
using util::CompletionResult::Ok;
using util::ExecutorStd;
using util::Status;
using Type = GrpcCompletion::Type;

namespace {

grpc::ByteBuffer MakeByteBuffer(NSData* data) {
  grpc::Slice slice{[data bytes], [data length]};
  return grpc::ByteBuffer{&slice, 1};
}

grpc::ByteBuffer MakeFakeDocument(const std::string& doc_name) {
  GCFSDocument* doc = [GCFSDocument message];
  doc.name =
      WrapNSString(std::string{"projects/p/databases/d/documents/"} + doc_name);
  GCFSValue* value = [GCFSValue message];
  value.stringValue = @"bar";
  [doc.fields addEntriesFromDictionary:@{
    @"foo" : value,
  }];
  doc.updateTime.seconds = 0;
  doc.updateTime.nanos = 42000;

  GCFSBatchGetDocumentsResponse* response =
      [GCFSBatchGetDocumentsResponse message];
  response.found = doc;
  return MakeByteBuffer([response data]);
}

class FakeDatastore : public Datastore {
 public:
  using Datastore::Datastore;

  grpc::CompletionQueue* queue() {
    return grpc_queue();
  }
  void CancelLastCall() {
    LastCall()->context()->TryCancel();
  }
};

std::shared_ptr<FakeDatastore> CreateDatastore(
    const DatabaseInfo& database_info,
    AsyncQueue* worker_queue,
    CredentialsProvider* credentials) {
  return std::make_shared<FakeDatastore>(database_info, worker_queue,
                                         credentials);
}

}  // namespace

class DatastoreTest : public testing::Test {
 public:
  DatastoreTest()
      : worker_queue{absl::make_unique<ExecutorLibdispatch>(
            dispatch_queue_create("datastore_test", DISPATCH_QUEUE_SERIAL))},
        database_info{DatabaseId{"p", "d"}, "", "some.host", false},
        datastore{CreateDatastore(database_info, &worker_queue, &credentials)},
        fake_grpc_queue{datastore->queue()} {
    // Deliberately don't `Start` the `Datastore` to prevent normal gRPC
    // completion queue polling; the test is using `FakeGrpcQueue`.
  }

  ~DatastoreTest() {
    if (!is_shut_down) {
      Shutdown();
    }
  }

  void Shutdown() {
    is_shut_down = true;
    datastore->Shutdown();
  }

  void ForceFinish(std::initializer_list<CompletionEndState> end_states) {
    datastore->CancelLastCall();
    fake_grpc_queue.ExtractCompletions(end_states);
    worker_queue.EnqueueBlocking([] {});
  }

  void ForceFinishAnyTypeOrder(
      std::initializer_list<CompletionEndState> end_states) {
    datastore->CancelLastCall();
    fake_grpc_queue.ExtractCompletions(
        GrpcStreamTester::CreateAnyTypeOrderCallback(end_states));
    worker_queue.EnqueueBlocking([] {});
  }

  bool is_shut_down = false;
  DatabaseInfo database_info;
  FakeCredentialsProvider credentials;

  AsyncQueue worker_queue;
  std::shared_ptr<FakeDatastore> datastore;

  std::unique_ptr<ConnectivityMonitor> connectivity_monitor;
  FakeGrpcQueue fake_grpc_queue;
};

TEST_F(DatastoreTest, CanShutdownWithNoOperations) {
  Shutdown();
}

TEST_F(DatastoreTest, WhitelistedHeaders) {
  GrpcStream::Metadata headers = {
      {"date", "date value"},
      {"x-google-backends", "backend value"},
      {"x-google-foo", "should not be in result"},  // Not whitelisted
      {"x-google-gfe-request-trace", "request trace"},
      {"x-google-netmon-label", "netmon label"},
      {"x-google-service", "service 1"},
      {"x-google-service", "service 2"},  // Duplicate names are allowed
  };
  std::string result = Datastore::GetWhitelistedHeadersAsString(headers);
  EXPECT_EQ(result, "date: date value\n"
                    "x-google-backends: backend value\n"
                    "x-google-gfe-request-trace: request trace\n"
                    "x-google-netmon-label: netmon label\n"
                    "x-google-service: service 1\n"
                    "x-google-service: service 2\n");
}

// Normal operation

TEST_F(DatastoreTest, CommitMutationsSuccess) {
  bool done = false;
  Status resulting_status;
  datastore->CommitMutations({}, [&](const Status& status) {
    done = true;
    resulting_status = status;
  });
  // Make sure Auth has a chance to run.
  worker_queue.EnqueueBlocking([] {});

  ForceFinish({{Type::Finish, grpc::Status::OK}});

  EXPECT_TRUE(done);
  EXPECT_TRUE(resulting_status.ok());
}

TEST_F(DatastoreTest, LookupDocumentsOneSuccessfulRead) {
  bool done = false;
  std::vector<FSTMaybeDocument*> resulting_docs;
  Status resulting_status;
  datastore->LookupDocuments(
      {}, [&](const std::vector<FSTMaybeDocument*>& documents,
              const Status& status) {
        done = true;
        resulting_docs = documents;
        resulting_status = status;
      });
  // Make sure Auth has a chance to run.
  worker_queue.EnqueueBlocking([] {});

  ForceFinishAnyTypeOrder({{Type::Read, MakeFakeDocument("foo/1")},
                           {Type::Write, Ok},
                           /*Read after last*/ {Type::Read, Error}});
  ForceFinish({{Type::Finish, grpc::Status::OK}});

  EXPECT_TRUE(done);
  EXPECT_EQ(resulting_docs.size(), 1);
  EXPECT_EQ(resulting_docs[0].key.ToString(), "foo/1");
  EXPECT_TRUE(resulting_status.ok());
}

TEST_F(DatastoreTest, LookupDocumentsTwoSuccessfulReads) {
  bool done = false;
  std::vector<FSTMaybeDocument*> resulting_docs;
  Status resulting_status;
  datastore->LookupDocuments(
      {}, [&](const std::vector<FSTMaybeDocument*>& documents,
              const Status& status) {
        done = true;
        resulting_docs = documents;
        resulting_status = status;
      });
  // Make sure Auth has a chance to run.
  worker_queue.EnqueueBlocking([] {});

  ForceFinishAnyTypeOrder({{Type::Write, Ok},
                           {Type::Read, MakeFakeDocument("foo/1")},
                           {Type::Read, MakeFakeDocument("foo/2")},
                           /*Read after last*/ {Type::Read, Error}});
  ForceFinish({{Type::Finish, grpc::Status::OK}});

  EXPECT_TRUE(done);
  EXPECT_EQ(resulting_docs.size(), 2);
  EXPECT_EQ(resulting_docs[0].key.ToString(), "foo/1");
  EXPECT_EQ(resulting_docs[1].key.ToString(), "foo/2");
  EXPECT_TRUE(resulting_status.ok());
}

// gRPC errors

TEST_F(DatastoreTest, CommitMutationsError) {
  bool done = false;
  Status resulting_status;
  datastore->CommitMutations({}, [&](const Status& status) {
    done = true;
    resulting_status = status;
  });
  // Make sure Auth has a chance to run.
  worker_queue.EnqueueBlocking([] {});

  ForceFinish({{Type::Finish, grpc::Status{grpc::UNAVAILABLE, ""}}});

  EXPECT_TRUE(done);
  EXPECT_FALSE(resulting_status.ok());
  EXPECT_EQ(resulting_status.code(), FirestoreErrorCode::Unavailable);
}

TEST_F(DatastoreTest, LookupDocumentsErrorBeforeFirstRead) {
  bool done = false;
  Status resulting_status;
  datastore->LookupDocuments(
      {}, [&](const std::vector<FSTMaybeDocument*>& documents,
              const Status& status) {
        done = true;
        resulting_status = status;
      });
  // Make sure Auth has a chance to run.
  worker_queue.EnqueueBlocking([] {});

  ForceFinishAnyTypeOrder({{Type::Read, Error}, {Type::Write, Error}});
  ForceFinish({{Type::Finish, grpc::Status{grpc::UNAVAILABLE, ""}}});

  EXPECT_TRUE(done);
  EXPECT_FALSE(resulting_status.ok());
  EXPECT_EQ(resulting_status.code(), FirestoreErrorCode::Unavailable);
}

TEST_F(DatastoreTest, LookupDocumentsErrorAfterFirstRead) {
  bool done = false;
  std::vector<FSTMaybeDocument*> resulting_docs;
  Status resulting_status;
  datastore->LookupDocuments(
      {}, [&](const std::vector<FSTMaybeDocument*>& documents,
              const Status& status) {
        done = true;
        resulting_status = status;
      });
  // Make sure Auth has a chance to run.
  worker_queue.EnqueueBlocking([] {});

  ForceFinishAnyTypeOrder({{Type::Write, Ok},
                           {Type::Read, MakeFakeDocument("foo/1")},
                           {Type::Read, Error}});
  ForceFinish({{Type::Finish, grpc::Status{grpc::UNAVAILABLE, ""}}});

  EXPECT_TRUE(done);
  EXPECT_TRUE(resulting_docs.empty());
  EXPECT_FALSE(resulting_status.ok());
  EXPECT_EQ(resulting_status.code(), FirestoreErrorCode::Unavailable);
}

// Auth errors

TEST_F(DatastoreTest, CommitMutationsAuthFailure) {
  credentials.FailGetToken();

  Status resulting_status;
  datastore->CommitMutations(
      {}, [&](const Status& status) { resulting_status = status; });
  worker_queue.EnqueueBlocking([] {});
  EXPECT_FALSE(resulting_status.ok());
}

TEST_F(DatastoreTest, LookupDocumentsAuthFailure) {
  credentials.FailGetToken();

  Status resulting_status;
  datastore->LookupDocuments(
      {}, [&](const std::vector<FSTMaybeDocument*>&, const Status& status) {
        resulting_status = status;
      });
  worker_queue.EnqueueBlocking([] {});
  EXPECT_FALSE(resulting_status.ok());
}

TEST_F(DatastoreTest, AuthAfterDatastoreHasBeenShutDown) {
  credentials.DelayGetToken();

  worker_queue.EnqueueBlocking([&] {
    datastore->CommitMutations({}, [](const Status& status) {
      FAIL() << "Callback shouldn't be invoked";
    });
  });
  Shutdown();

  EXPECT_NO_THROW(credentials.InvokeGetToken());
}

TEST_F(DatastoreTest, AuthOutlivesDatastore) {
  credentials.DelayGetToken();

  worker_queue.EnqueueBlocking([&] {
    datastore->CommitMutations({}, [](const Status& status) {
      FAIL() << "Callback shouldn't be invoked";
    });
  });
  Shutdown();
  datastore.reset();

  EXPECT_NO_THROW(credentials.InvokeGetToken());
}

// Error classification

TEST_F(DatastoreTest, IsPermanentError) {
  EXPECT_FALSE(
      Datastore::IsPermanentError(Status{FirestoreErrorCode::Cancelled, ""}));
  EXPECT_FALSE(Datastore::IsPermanentError(
      Status{FirestoreErrorCode::ResourceExhausted, ""}));
  EXPECT_FALSE(
      Datastore::IsPermanentError(Status{FirestoreErrorCode::Unavailable, ""}));
  // User info doesn't matter:
  EXPECT_FALSE(Datastore::IsPermanentError(
      Status{FirestoreErrorCode::Unavailable, "Connectivity lost"}));
  // "unauthenticated" is considered a recoverable error due to expired token.
  EXPECT_FALSE(Datastore::IsPermanentError(
      Status{FirestoreErrorCode::Unauthenticated, ""}));

  EXPECT_TRUE(
      Datastore::IsPermanentError(Status{FirestoreErrorCode::DataLoss, ""}));
  EXPECT_TRUE(
      Datastore::IsPermanentError(Status{FirestoreErrorCode::Aborted, ""}));
}

TEST_F(DatastoreTest, IsPermanentWriteError) {
  EXPECT_FALSE(Datastore::IsPermanentWriteError(
      Status{FirestoreErrorCode::Unauthenticated, ""}));
  EXPECT_TRUE(Datastore::IsPermanentWriteError(
      Status{FirestoreErrorCode::DataLoss, ""}));
  EXPECT_FALSE(Datastore::IsPermanentWriteError(
      Status{FirestoreErrorCode::Aborted, ""}));
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
