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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_STREAM_OBJC_BRIDGE_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_STREAM_OBJC_BRIDGE_H_

#if !defined(__OBJC__)
#error "This header only supports Objective-C++"
#endif  // !defined(__OBJC__)

#include <string>

#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "grpcpp/support/byte_buffer.h"

#import <Foundation/Foundation.h>
#import "Firestore/Protos/objc/google/firestore/v1beta1/Firestore.pbobjc.h"
#import "Firestore/Source/Core/FSTTypes.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"
#import "Firestore/Source/Remote/FSTWatchChange.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace bridge {

bool IsLoggingEnabled();

// Contains operations in `WatchStream` and `WriteStream` that are still
// delegated to Objective-C: proto parsing and delegates.
//
// The principle is that the C++ implementation can only take Objective-C
// objects as parameters or return them, but never instantiate them or call any
// methods on them -- if that is necessary, it's delegated to one of the bridge
// classes. This allows easily identifying which parts of `WatchStream` and
// `WriteStream` still rely on not-yet-ported code.

class WatchStreamSerializer {
 public:
  explicit WatchStreamSerializer(FSTSerializerBeta* serializer)
      : serializer_{serializer} {
  }

  GCFSListenRequest* CreateRequest(FSTQueryData* query) const;
  GCFSListenRequest* CreateRequest(model::TargetId target_id) const;

  grpc::ByteBuffer ToByteBuffer(GCFSListenRequest* request) const;

  NSString* Describe(GCFSListenRequest* request) const;
  NSString* Describe(GCFSListenResponse* request) const;

  FSTWatchChange* ToWatchChange(GCFSListenResponse* proto) const;
  model::SnapshotVersion ToSnapshotVersion(GCFSListenResponse* proto) const;

  GCFSListenResponse* ParseResponse(const grpc::ByteBuffer& message,
                                    util::Status* out_status) const;

 private:
  FSTSerializerBeta* serializer_;
};

class WriteStreamSerializer {
 public:
  explicit WriteStreamSerializer(FSTSerializerBeta* serializer)
      : serializer_{serializer} {
  }

  void UpdateLastStreamToken(GCFSWriteResponse* proto);
  void SetLastStreamToken(NSData* token) {
    last_stream_token_ = token;
  }
  NSData* GetLastStreamToken() const {
    return last_stream_token_;
  }

  GCFSWriteRequest* CreateHandshake() const;
  GCFSWriteRequest* CreateRequest(NSArray<FSTMutation*>* mutations) const;
  GCFSWriteRequest* CreateEmptyMutationsList() {
    return CreateRequest(@[]);
  }

  grpc::ByteBuffer ToByteBuffer(GCFSWriteRequest* request) const;

  NSString* Describe(GCFSWriteRequest* request) const;
  NSString* Describe(GCFSWriteResponse* request) const;

  GCFSWriteResponse* ParseResponse(const grpc::ByteBuffer& message,
                                   util::Status* out_status) const;

  model::SnapshotVersion ToCommitVersion(GCFSWriteResponse* proto) const;
  NSArray<FSTMutationResult*>* ToMutationResults(
      GCFSWriteResponse* proto) const;

 private:
  FSTSerializerBeta* serializer_;
  NSData* last_stream_token_;
};

class WatchStreamDelegate {
 public:
  explicit WatchStreamDelegate(id delegate) : delegate_{delegate} {
  }

  void NotifyDelegateOnOpen();
  void NotifyDelegateOnChange(FSTWatchChange* change,
                              const model::SnapshotVersion& snapshot_version);
  void NotifyDelegateOnStreamFinished(const util::Status& status);

 private:
  id delegate_;
};

class WriteStreamDelegate {
 public:
  explicit WriteStreamDelegate(id delegate) : delegate_{delegate} {
  }

  void NotifyDelegateOnOpen();
  void NotifyDelegateOnHandshakeComplete();
  void NotifyDelegateOnCommit(const model::SnapshotVersion& commit_version,
                              NSArray<FSTMutationResult*>* results);
  void NotifyDelegateOnStreamFinished(const util::Status& status);

 private:
  id delegate_;
};

}  // namespace bridge
}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_STREAM_OBJC_BRIDGE_H_
