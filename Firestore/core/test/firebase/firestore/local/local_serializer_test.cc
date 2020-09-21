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

#include "Firestore/core/src/firebase/firestore/local/local_serializer.h"

#include "Firestore/Protos/cpp/firestore/local/maybe_document.pb.h"
#include "Firestore/Protos/cpp/firestore/local/target.pb.h"
#include "Firestore/Protos/cpp/google/firestore/v1beta1/firestore.pb.h"
#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/local/query_data.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/maybe_document.h"
#include "Firestore/core/src/firebase/firestore/model/no_document.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/remote/serializer.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "google/protobuf/util/message_differencer.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {

namespace v1beta1 = google::firestore::v1beta1;
using core::Query;
using ::google::protobuf::util::MessageDifferencer;
using model::DatabaseId;
using model::Document;
using model::DocumentKey;
using model::MaybeDocument;
using model::NoDocument;
using model::SnapshotVersion;
using testutil::DeletedDoc;
using testutil::Doc;
using testutil::Query;
using util::Status;
using util::StatusOr;

// TODO(rsgowman): This is copied from remote/serializer_tests.cc. Refactor.
#define EXPECT_OK(status) EXPECT_TRUE(StatusOk(status))

class LocalSerializerTest : public ::testing::Test {
 public:
  LocalSerializerTest()
      : remote_serializer(kDatabaseId), serializer(remote_serializer) {
    msg_diff.ReportDifferencesToString(&message_differences);
  }

  const DatabaseId kDatabaseId{"p", "d"};
  remote::Serializer remote_serializer;
  local::LocalSerializer serializer;

  void ExpectRoundTrip(const MaybeDocument& model,
                       const ::firestore::client::MaybeDocument& proto,
                       MaybeDocument::Type type) {
    // First, serialize model with our (nanopb based) serializer, then
    // deserialize the resulting bytes with libprotobuf and ensure the result is
    // the same as the expected proto.
    ExpectSerializationRoundTrip(model, proto, type);

    // Next, serialize proto with libprotobuf, then deserialize the resulting
    // bytes with our (nanopb based) deserializer and ensure the result is the
    // same as the expected model.
    ExpectDeserializationRoundTrip(model, proto, type);
  }

  void ExpectRoundTrip(const QueryData& query_data,
                       const ::firestore::client::Target& proto) {
    // First, serialize model with our (nanopb based) serializer, then
    // deserialize the resulting bytes with libprotobuf and ensure the result is
    // the same as the expected proto.
    ExpectSerializationRoundTrip(query_data, proto);

    // Next, serialize proto with libprotobuf, then deserialize the resulting
    // bytes with our (nanopb based) deserializer and ensure the result is the
    // same as the expected model.
    ExpectDeserializationRoundTrip(query_data, proto);
  }

  /**
   * Checks the status. Don't use directly; use one of the relevant macros
   * instead. eg:
   *
   *   Status good_status = ...;
   *   ASSERT_OK(good_status);
   *
   *   Status bad_status = ...;
   *   EXPECT_NOT_OK(bad_status);
   */
  // TODO(rsgowman): This is copied from remote/serializer_tests.cc. Refactor.
  testing::AssertionResult StatusOk(const Status& status) {
    if (!status.ok()) {
      return testing::AssertionFailure()
             << "Status should have been ok, but instead contained "
             << status.ToString();
    }
    return testing::AssertionSuccess();
  }

  // TODO(rsgowman): This is copied from remote/serializer_tests.cc. Refactor.
  template <typename T>
  testing::AssertionResult StatusOk(const StatusOr<T>& status) {
    return StatusOk(status.status());
  }

 private:
  void ExpectSerializationRoundTrip(
      const MaybeDocument& model,
      const ::firestore::client::MaybeDocument& proto,
      MaybeDocument::Type type) {
    EXPECT_EQ(type, model.type());
    std::vector<uint8_t> bytes = EncodeMaybeDocument(&serializer, model);
    ::firestore::client::MaybeDocument actual_proto;
    bool ok = actual_proto.ParseFromArray(bytes.data(),
                                          static_cast<int>(bytes.size()));
    EXPECT_TRUE(ok);
    EXPECT_TRUE(msg_diff.Compare(proto, actual_proto)) << message_differences;
  }

  void ExpectDeserializationRoundTrip(
      const MaybeDocument& model,
      const ::firestore::client::MaybeDocument& proto,
      MaybeDocument::Type type) {
    std::vector<uint8_t> bytes(proto.ByteSizeLong());
    bool status =
        proto.SerializeToArray(bytes.data(), static_cast<int>(bytes.size()));
    EXPECT_TRUE(status);
    StatusOr<std::unique_ptr<MaybeDocument>> actual_model_status =
        serializer.DecodeMaybeDocument(bytes);
    EXPECT_OK(actual_model_status);
    std::unique_ptr<MaybeDocument> actual_model =
        std::move(actual_model_status).ValueOrDie();
    EXPECT_EQ(type, actual_model->type());
    EXPECT_EQ(model, *actual_model);
  }

  std::vector<uint8_t> EncodeMaybeDocument(local::LocalSerializer* serializer,
                                           const MaybeDocument& maybe_doc) {
    std::vector<uint8_t> bytes;
    Status status = serializer->EncodeMaybeDocument(maybe_doc, &bytes);
    EXPECT_OK(status);
    return bytes;
  }

  void ExpectSerializationRoundTrip(const QueryData& query_data,
                                    const ::firestore::client::Target& proto) {
    std::vector<uint8_t> bytes = EncodeQueryData(&serializer, query_data);
    ::firestore::client::Target actual_proto;
    bool ok = actual_proto.ParseFromArray(bytes.data(),
                                          static_cast<int>(bytes.size()));
    EXPECT_TRUE(ok);
    EXPECT_TRUE(msg_diff.Compare(proto, actual_proto)) << message_differences;
  }

  void ExpectDeserializationRoundTrip(
      const QueryData& query_data, const ::firestore::client::Target& proto) {
    std::vector<uint8_t> bytes(proto.ByteSizeLong());
    bool status =
        proto.SerializeToArray(bytes.data(), static_cast<int>(bytes.size()));
    EXPECT_TRUE(status);
    StatusOr<QueryData> actual_query_data_status =
        serializer.DecodeQueryData(bytes);
    EXPECT_OK(actual_query_data_status);
    QueryData actual_query_data =
        std::move(actual_query_data_status).ValueOrDie();

    EXPECT_EQ(query_data, actual_query_data);
  }

  std::vector<uint8_t> EncodeQueryData(local::LocalSerializer* serializer,
                                       const QueryData& query_data) {
    std::vector<uint8_t> bytes;
    EXPECT_EQ(query_data.purpose(), QueryPurpose::kListen);
    Status status = serializer->EncodeQueryData(query_data, &bytes);
    EXPECT_OK(status);
    return bytes;
  }

  std::string message_differences;
  MessageDifferencer msg_diff;
};

TEST_F(LocalSerializerTest, EncodesDocumentAsMaybeDocument) {
  Document doc = Doc("some/path", /*version=*/42);

  ::firestore::client::MaybeDocument maybe_doc_proto;
  maybe_doc_proto.mutable_document()->set_name(
      "projects/p/databases/d/documents/some/path");
  maybe_doc_proto.mutable_document()->mutable_update_time()->set_seconds(0);
  maybe_doc_proto.mutable_document()->mutable_update_time()->set_nanos(42000);

  ExpectRoundTrip(doc, maybe_doc_proto, doc.type());
}

TEST_F(LocalSerializerTest, EncodesNoDocumentAsMaybeDocument) {
  NoDocument no_doc = DeletedDoc("some/path", /*version=*/42);

  ::firestore::client::MaybeDocument maybe_doc_proto;
  maybe_doc_proto.mutable_no_document()->set_name(
      "projects/p/databases/d/documents/some/path");
  maybe_doc_proto.mutable_no_document()->mutable_read_time()->set_seconds(0);
  maybe_doc_proto.mutable_no_document()->mutable_read_time()->set_nanos(42000);

  ExpectRoundTrip(no_doc, maybe_doc_proto, no_doc.type());
}

TEST_F(LocalSerializerTest, EncodesQueryData) {
  core::Query query = testutil::Query("room");
  int target_id = 42;
  SnapshotVersion version = testutil::Version(1039);
  std::vector<uint8_t> resume_token = testutil::ResumeToken(1039);

  QueryData query_data(core::Query(query), target_id, QueryPurpose::kListen,
                       SnapshotVersion(version),
                       std::vector<uint8_t>(resume_token));

  // Let the RPC serializer test various permutations of query serialization.
  std::vector<uint8_t> query_target_bytes;
  util::Status status = remote_serializer.EncodeQueryTarget(
      query_data.query(), &query_target_bytes);
  EXPECT_OK(status);
  v1beta1::Target::QueryTarget queryTargetProto;
  bool ok = queryTargetProto.ParseFromArray(
      query_target_bytes.data(), static_cast<int>(query_target_bytes.size()));
  EXPECT_TRUE(ok);

  ::firestore::client::Target expected;
  expected.set_target_id(target_id);
  expected.mutable_snapshot_version()->set_nanos(1039000);
  expected.set_resume_token(resume_token.data(), resume_token.size());
  v1beta1::Target::QueryTarget* query_proto = expected.mutable_query();
  query_proto->set_parent(queryTargetProto.parent());
  *query_proto->mutable_structured_query() =
      queryTargetProto.structured_query();

  ExpectRoundTrip(query_data, expected);
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
