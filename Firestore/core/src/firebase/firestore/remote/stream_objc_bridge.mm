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

#include "Firestore/core/src/firebase/firestore/remote/stream_objc_bridge.h"

#include <iomanip>
#include <sstream>
#include <vector>

#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/Remote/FSTStream.h"

#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/util/error_apple.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "grpcpp/support/status.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace bridge {

using model::TargetId;
using model::SnapshotVersion;
using util::MakeString;
using util::MakeNSError;
using util::Status;
using util::StringFormat;

namespace {

NSData* ToNsData(const grpc::ByteBuffer& buffer) {
  std::vector<grpc::Slice> slices;
  grpc::Status status = buffer.Dump(&slices);
  HARD_ASSERT(status.ok(), "Trying to convert an invalid grpc::ByteBuffer");

  if (slices.size() == 1) {
    return [NSData dataWithBytes:slices.front().begin()
                          length:slices.front().size()];
  } else {
    NSMutableData* data = [NSMutableData dataWithCapacity:buffer.Length()];
    for (const auto& slice : slices) {
      [data appendBytes:slice.begin() length:slice.size()];
    }
    return data;
  }
}

std::string ToHexString(const grpc::ByteBuffer& buffer) {
  std::vector<grpc::Slice> slices;
  grpc::Status status = buffer.Dump(&slices);

  std::stringstream output;
  // The output will look like "0x00 0x0a"
  output << std::hex << std::setfill('0') << std::setw(2);
  for (const auto& slice : slices) {
    for (uint8_t c : slice) {
      output << "0x" << static_cast<int>(c) << " ";
    }
  }

  return output.str();
}

template <typename Proto>
Proto* ToProto(const grpc::ByteBuffer& message, Status* out_status) {
  NSError* error = nil;
  Proto* proto = [Proto parseFromData:ToNsData(message) error:&error];
  if (!error) {
    return proto;
  }

  std::string error_description = StringFormat(
      "Unable to parse response from the server.\n"
      "Underlying error: %s\n"
      "Expected class: %s\n"
      "Received value: %s\n",
      error, [Proto class], ToHexString(message));

  *out_status = {FirestoreErrorCode::Internal, error_description};
  return nil;
}

grpc::ByteBuffer ConvertToByteBuffer(NSData* data) {
  grpc::Slice slice{[data bytes], [data length]};
  return grpc::ByteBuffer{&slice, 1};
}

}  // namespace

bool IsLoggingEnabled() {
  return [FIRFirestore isLoggingEnabled];
}

GCFSListenRequest* WatchStreamSerializer::CreateRequest(
    FSTQueryData* query) const {
  GCFSListenRequest* request = [GCFSListenRequest message];
  request.database = [serializer_ encodedDatabaseID];
  request.addTarget = [serializer_ encodedTarget:query];
  request.labels = [serializer_ encodedListenRequestLabelsForQueryData:query];
  return request;
}

GCFSListenRequest* WatchStreamSerializer::CreateRequest(
    TargetId target_id) const {
  GCFSListenRequest* request = [GCFSListenRequest message];
  request.database = [serializer_ encodedDatabaseID];
  request.removeTarget = target_id;
  return request;
}

grpc::ByteBuffer WatchStreamSerializer::ToByteBuffer(
    GCFSListenRequest* request) const {
  return ConvertToByteBuffer([request data]);
}

NSString* WatchStreamSerializer::Describe(GCFSListenRequest* request) const {
  return [request description];
}

NSString* WatchStreamSerializer::Describe(GCFSListenResponse* response) const {
  return [response description];
}

GCFSWriteRequest* WriteStreamSerializer::CreateHandshake() const {
  // The initial request cannot contain mutations, but must contain a projectID.
  GCFSWriteRequest* request = [GCFSWriteRequest message];
  request.database = [serializer_ encodedDatabaseID];
  return request;
}

GCFSWriteRequest* WriteStreamSerializer::CreateRequest(
    NSArray<FSTMutation*>* mutations) const {
  NSMutableArray<GCFSWrite*>* protos =
      [NSMutableArray arrayWithCapacity:mutations.count];
  for (FSTMutation* mutation in mutations) {
    [protos addObject:[serializer_ encodedMutation:mutation]];
  };

  GCFSWriteRequest* request = [GCFSWriteRequest message];
  request.writesArray = protos;
  request.streamToken = last_stream_token_;

  return request;
}

grpc::ByteBuffer WriteStreamSerializer::ToByteBuffer(
    GCFSWriteRequest* request) const {
  return ConvertToByteBuffer([request data]);
}

NSString* WriteStreamSerializer::Describe(GCFSWriteRequest* request) const {
  return [request description];
}

NSString* WriteStreamSerializer::Describe(GCFSWriteResponse* response) const {
  return [response description];
}

FSTWatchChange* WatchStreamSerializer::ToWatchChange(
    GCFSListenResponse* proto) const {
  return [serializer_ decodedWatchChange:proto];
}

SnapshotVersion WatchStreamSerializer::ToSnapshotVersion(
    GCFSListenResponse* proto) const {
  return [serializer_ versionFromListenResponse:proto];
}

GCFSListenResponse* WatchStreamSerializer::ParseResponse(
    const grpc::ByteBuffer& message, Status* out_status) const {
  return ToProto<GCFSListenResponse>(message, out_status);
}

void WriteStreamSerializer::UpdateLastStreamToken(GCFSWriteResponse* proto) {
  last_stream_token_ = proto.streamToken;
}

model::SnapshotVersion WriteStreamSerializer::ToCommitVersion(
    GCFSWriteResponse* proto) const {
  return [serializer_ decodedVersion:proto.commitTime];
}

NSArray<FSTMutationResult*>* WriteStreamSerializer::ToMutationResults(
    GCFSWriteResponse* proto) const {
  NSMutableArray<GCFSWriteResult*>* protos = proto.writeResultsArray;
  NSMutableArray<FSTMutationResult*>* results =
      [NSMutableArray arrayWithCapacity:protos.count];
  for (GCFSWriteResult* proto in protos) {
    [results addObject:[serializer_ decodedMutationResult:proto]];
  };
  return results;
}

GCFSWriteResponse* WriteStreamSerializer::ParseResponse(
    const grpc::ByteBuffer& message, Status* out_status) const {
  return ToProto<GCFSWriteResponse>(message, out_status);
}

void WatchStreamDelegate::NotifyDelegateOnOpen() {
  id<FSTWatchStreamDelegate> delegate = delegate_;
  [delegate watchStreamDidOpen];
}

void WatchStreamDelegate::NotifyDelegateOnChange(
    FSTWatchChange* change, const model::SnapshotVersion& snapshot_version) {
  id<FSTWatchStreamDelegate> delegate = delegate_;
  [delegate watchStreamDidChange:change snapshotVersion:snapshot_version];
}

void WatchStreamDelegate::NotifyDelegateOnStreamFinished(const Status& status) {
  id<FSTWatchStreamDelegate> delegate = delegate_;
  [delegate watchStreamWasInterruptedWithError:MakeNSError(status)];
}

void WriteStreamDelegate::NotifyDelegateOnOpen() {
  id<FSTWriteStreamDelegate> delegate = delegate_;
  [delegate writeStreamDidOpen];
}

void WriteStreamDelegate::NotifyDelegateOnHandshakeComplete() {
  id<FSTWriteStreamDelegate> delegate = delegate_;
  [delegate writeStreamDidCompleteHandshake];
}

void WriteStreamDelegate::NotifyDelegateOnCommit(
    const SnapshotVersion& commit_version,
    NSArray<FSTMutationResult*>* results) {
  id<FSTWriteStreamDelegate> delegate = delegate_;
  [delegate writeStreamDidReceiveResponseWithVersion:commit_version
                                     mutationResults:results];
}

void WriteStreamDelegate::NotifyDelegateOnStreamFinished(const Status& status) {
  id<FSTWriteStreamDelegate> delegate = delegate_;
  [delegate writeStreamWasInterruptedWithError:MakeNSError(status)];
}

}  // bridge
}  // remote
}  // firestore
}  // firebase
