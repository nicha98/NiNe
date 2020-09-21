/*
 * Copyright 2017 Google
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

#import "Firestore/Example/Tests/SpecTests/FSTSyncEngineTestDriver.h"

#import <FirebaseFirestore/FIRFirestoreErrors.h>

#include <map>
#include <memory>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#import "Firestore/Example/Tests/SpecTests/FSTMockDatastore.h"

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/firebase/firestore/auth/empty_credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/core/event_manager.h"
#include "Firestore/core/src/firebase/firestore/core/sync_engine.h"
#include "Firestore/core/src/firebase/firestore/local/local_store.h"
#include "Firestore/core/src/firebase/firestore/local/persistence.h"
#include "Firestore/core/src/firebase/firestore/local/simple_query_engine.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/objc/objc_compatibility.h"
#include "Firestore/core/src/firebase/firestore/remote/remote_store.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/delayed_constructor.h"
#include "Firestore/core/src/firebase/firestore/util/error_apple.h"
#include "Firestore/core/src/firebase/firestore/util/executor.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"
#include "Firestore/core/src/firebase/firestore/util/string_format.h"
#include "Firestore/core/src/firebase/firestore/util/to_string.h"
#include "Firestore/core/test/firebase/firestore/testutil/async_testing.h"
#include "absl/memory/memory.h"

namespace testutil = firebase::firestore::testutil;

using firebase::firestore::Error;
using firebase::firestore::auth::EmptyCredentialsProvider;
using firebase::firestore::auth::HashUser;
using firebase::firestore::auth::User;
using firebase::firestore::core::DatabaseInfo;
using firebase::firestore::core::EventListener;
using firebase::firestore::core::EventManager;
using firebase::firestore::core::ListenOptions;
using firebase::firestore::core::Query;
using firebase::firestore::core::QueryListener;
using firebase::firestore::core::SyncEngine;
using firebase::firestore::core::ViewSnapshot;
using firebase::firestore::local::LocalStore;
using firebase::firestore::local::Persistence;
using firebase::firestore::local::QueryData;
using firebase::firestore::local::SimpleQueryEngine;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::Mutation;
using firebase::firestore::model::MutationResult;
using firebase::firestore::model::OnlineState;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;
using firebase::firestore::remote::MockDatastore;
using firebase::firestore::remote::RemoteStore;
using firebase::firestore::remote::WatchChange;
using firebase::firestore::util::AsyncQueue;
using firebase::firestore::util::DelayedConstructor;
using firebase::firestore::util::Empty;
using firebase::firestore::util::Executor;
using firebase::firestore::util::MakeNSError;
using firebase::firestore::util::MakeNSString;
using firebase::firestore::util::MakeString;
using firebase::firestore::util::Status;
using firebase::firestore::util::StatusOr;
using firebase::firestore::util::StringFormat;
using firebase::firestore::util::TimerId;
using firebase::firestore::util::ToString;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTQueryEvent {
  absl::optional<ViewSnapshot> _maybeViewSnapshot;
}

- (const absl::optional<ViewSnapshot> &)viewSnapshot {
  return _maybeViewSnapshot;
}

- (void)setViewSnapshot:(absl::optional<ViewSnapshot>)snapshot {
  _maybeViewSnapshot = std::move(snapshot);
}

- (NSString *)description {
  // The Query is also included in the view, so we skip it.
  std::string str = StringFormat("<FSTQueryEvent: viewSnapshot=%s, error=%s>",
                                 ToString(_maybeViewSnapshot), self.error);
  return MakeNSString(str);
}

@end

@implementation FSTOutstandingWrite {
  Mutation _write;
}

- (const model::Mutation &)write {
  return _write;
}

- (void)setWrite:(model::Mutation)write {
  _write = std::move(write);
}

@end

@interface FSTSyncEngineTestDriver ()

#pragma mark - Parts of the Firestore system that the spec tests need to control.

#pragma mark - Data structures for holding events sent by the watch stream.

/** A block for the FSTEventAggregator to use to report events to the test. */
@property(nonatomic, strong, readonly) void (^eventHandler)(FSTQueryEvent *);
/** The events received by our eventHandler and not yet retrieved via capturedEventsSinceLastCall */
@property(nonatomic, strong, readonly) NSMutableArray<FSTQueryEvent *> *events;

#pragma mark - Data structures for holding events sent by the write stream.

/** The names of the documents that the client acknowledged during the current spec test step */
@property(nonatomic, strong, readonly) NSMutableArray<NSString *> *acknowledgedDocs;
/** The names of the documents that the client rejected during the current spec test step */
@property(nonatomic, strong, readonly) NSMutableArray<NSString *> *rejectedDocs;

@end

@implementation FSTSyncEngineTestDriver {
  std::unique_ptr<Persistence> _persistence;

  std::unique_ptr<LocalStore> _localStore;

  std::unique_ptr<SyncEngine> _syncEngine;

  std::shared_ptr<AsyncQueue> _workerQueue;

  std::unique_ptr<RemoteStore> _remoteStore;

  DelayedConstructor<EventManager> _eventManager;

  // Set of active targets, keyed by target Id, mapped to corresponding resume token,
  // and list of `QueryData`.
  ActiveTargetMap _expectedActiveTargets;

  // ivar is declared as mutable.
  std::unordered_map<User, NSMutableArray<FSTOutstandingWrite *> *, HashUser> _outstandingWrites;
  DocumentKeySet _expectedLimboDocuments;

  /** A dictionary for tracking the listens on queries. */
  std::unordered_map<Query, std::shared_ptr<QueryListener>> _queryListeners;

  DatabaseInfo _databaseInfo;
  User _currentUser;

  std::vector<std::shared_ptr<EventListener<Empty>>> _snapshotsInSyncListeners;
  std::shared_ptr<MockDatastore> _datastore;

  // TODO(index-free): Use IndexFreeQueryEngine
  SimpleQueryEngine _queryEngine;

  int _snapshotsInSyncEvents;
}

- (instancetype)initWithPersistence:(std::unique_ptr<Persistence>)persistence {
  return [self initWithPersistence:std::move(persistence)
                       initialUser:User::Unauthenticated()
                 outstandingWrites:{}];
}

- (instancetype)initWithPersistence:(std::unique_ptr<Persistence>)persistence
                        initialUser:(const User &)initialUser
                  outstandingWrites:(const FSTOutstandingWriteQueues &)outstandingWrites {
  if (self = [super init]) {
    // Do a deep copy.
    for (const auto &pair : outstandingWrites) {
      _outstandingWrites[pair.first] = [pair.second mutableCopy];
    }

    _events = [NSMutableArray array];

    _databaseInfo = {DatabaseId{"project", "database"}, "persistence", "host", false};

    // Set up the sync engine and various stores.
    _workerQueue = testutil::AsyncQueueForTesting();
    _persistence = std::move(persistence);
    _localStore = absl::make_unique<LocalStore>(_persistence.get(), &_queryEngine, initialUser);

    _datastore = std::make_shared<MockDatastore>(_databaseInfo, _workerQueue,
                                                 std::make_shared<EmptyCredentialsProvider>());
    _remoteStore = absl::make_unique<RemoteStore>(
        _localStore.get(), _datastore, _workerQueue,
        [self](OnlineState onlineState) { _syncEngine->HandleOnlineStateChange(onlineState); });
    ;

    _syncEngine = absl::make_unique<SyncEngine>(_localStore.get(), _remoteStore.get(), initialUser);
    _remoteStore->set_sync_engine(_syncEngine.get());
    _eventManager.Init(_syncEngine.get());

    // Set up internal event tracking for the spec tests.
    NSMutableArray<FSTQueryEvent *> *events = [NSMutableArray array];
    _eventHandler = ^(FSTQueryEvent *e) {
      [events addObject:e];
    };
    _events = events;

    _currentUser = initialUser;

    _acknowledgedDocs = [NSMutableArray array];

    _rejectedDocs = [NSMutableArray array];
  }
  return self;
}

- (const FSTOutstandingWriteQueues &)outstandingWrites {
  return _outstandingWrites;
}

- (const DocumentKeySet &)expectedLimboDocuments {
  return _expectedLimboDocuments;
}

- (void)setExpectedLimboDocuments:(DocumentKeySet)docs {
  _expectedLimboDocuments = std::move(docs);
}

- (void)drainQueue {
  _workerQueue->EnqueueBlocking([] {});
}

- (const User &)currentUser {
  return _currentUser;
}

- (void)incrementSnapshotsInSyncEvents {
  _snapshotsInSyncEvents += 1;
}

- (void)resetSnapshotsInSyncEvents {
  _snapshotsInSyncEvents = 0;
}

- (void)addSnapshotsInSyncListener {
  std::shared_ptr<EventListener<Empty>> eventListener = EventListener<Empty>::Create(
      [self](const StatusOr<Empty> &) { [self incrementSnapshotsInSyncEvents]; });
  _snapshotsInSyncListeners.push_back(eventListener);
  _eventManager->AddSnapshotsInSyncListener(eventListener);
}

- (void)removeSnapshotsInSyncListener {
  if (_snapshotsInSyncListeners.empty()) {
    HARD_FAIL("There must be a listener to unlisten to");
  } else {
    _eventManager->RemoveSnapshotsInSyncListener(_snapshotsInSyncListeners.back());
    _snapshotsInSyncListeners.pop_back();
  }
}

- (int)snapshotsInSyncEvents {
  return _snapshotsInSyncEvents;
}

- (void)start {
  _workerQueue->EnqueueBlocking([&] {
    _localStore->Start();
    _remoteStore->Start();
  });
}

- (void)validateUsage {
  // We could relax this if we found a reason to.
  HARD_ASSERT(self.events.count == 0, "You must clear all pending events by calling"
                                      " capturedEventsSinceLastCall before calling shutdown.");
}

- (void)shutdown {
  _workerQueue->EnqueueBlocking([&] {
    _remoteStore->Shutdown();
    _persistence->Shutdown();
  });
}

- (void)validateNextWriteSent:(const Mutation &)expectedWrite {
  std::vector<Mutation> request = _datastore->NextSentWrite();
  // Make sure the write went through the pipe like we expected it to.
  HARD_ASSERT(request.size() == 1, "Only single mutation requests are supported at the moment");
  const Mutation &actualWrite = request[0];
  HARD_ASSERT(actualWrite == expectedWrite,
              "Mock datastore received write %s but first outstanding mutation was %s",
              actualWrite.ToString(), expectedWrite.ToString());
  LOG_DEBUG("A write was sent: %s", actualWrite.ToString());
}

- (int)sentWritesCount {
  return _datastore->WritesSent();
}

- (int)writeStreamRequestCount {
  return _datastore->write_stream_request_count();
}

- (int)watchStreamRequestCount {
  return _datastore->watch_stream_request_count();
}

- (void)disableNetwork {
  _workerQueue->EnqueueBlocking([&] {
    // Make sure to execute all writes that are currently queued. This allows us
    // to assert on the total number of requests sent before shutdown.
    _remoteStore->FillWritePipeline();
    _remoteStore->DisableNetwork();
  });
}

- (void)enableNetwork {
  _workerQueue->EnqueueBlocking([&] { _remoteStore->EnableNetwork(); });
}

- (void)runTimer:(TimerId)timerID {
  _workerQueue->RunScheduledOperationsUntil(timerID);
}

- (void)changeUser:(const User &)user {
  _currentUser = user;
  _workerQueue->EnqueueBlocking([&] { _syncEngine->HandleCredentialChange(user); });
}

- (FSTOutstandingWrite *)receiveWriteAckWithVersion:(const SnapshotVersion &)commitVersion
                                    mutationResults:(std::vector<MutationResult>)mutationResults {
  FSTOutstandingWrite *write = [self currentOutstandingWrites].firstObject;
  [[self currentOutstandingWrites] removeObjectAtIndex:0];
  [self validateNextWriteSent:write.write];

  _workerQueue->EnqueueBlocking(
      [&] { _datastore->AckWrite(commitVersion, std::move(mutationResults)); });

  return write;
}

- (FSTOutstandingWrite *)receiveWriteError:(int)errorCode
                                  userInfo:(NSDictionary<NSString *, id> *)userInfo
                               keepInQueue:(BOOL)keepInQueue {
  Status error{static_cast<Error>(errorCode), MakeString([userInfo description])};

  FSTOutstandingWrite *write = [self currentOutstandingWrites].firstObject;
  [self validateNextWriteSent:write.write];

  // If this is a permanent error, the mutation is not expected to be sent again so we remove it
  // from currentOutstandingWrites.
  if (!keepInQueue) {
    [[self currentOutstandingWrites] removeObjectAtIndex:0];
  }

  LOG_DEBUG("Failing a write.");
  _workerQueue->EnqueueBlocking([&] { _datastore->FailWrite(error); });

  return write;
}

- (NSArray<FSTQueryEvent *> *)capturedEventsSinceLastCall {
  NSArray<FSTQueryEvent *> *result = [self.events copy];
  [self.events removeAllObjects];
  return result;
}

- (NSArray<NSString *> *)capturedAcknowledgedWritesSinceLastCall {
  NSArray<NSString *> *result = [self.acknowledgedDocs copy];
  [self.acknowledgedDocs removeAllObjects];
  return result;
}

- (NSArray<NSString *> *)capturedRejectedWritesSinceLastCall {
  NSArray<NSString *> *result = [self.rejectedDocs copy];
  [self.rejectedDocs removeAllObjects];
  return result;
}

- (TargetId)addUserListenerWithQuery:(Query)query {
  // TODO(dimond): Allow customizing listen options in spec tests
  // TODO(dimond): Change spec tests to verify isFromCache on snapshots
  ListenOptions options = ListenOptions::FromIncludeMetadataChanges(true);
  auto listener = QueryListener::Create(
      query, options, [self, query](const StatusOr<ViewSnapshot> &maybe_snapshot) {
        FSTQueryEvent *event = [[FSTQueryEvent alloc] init];
        event.query = query;
        if (maybe_snapshot.ok()) {
          [event setViewSnapshot:maybe_snapshot.ValueOrDie()];
        } else {
          event.error = MakeNSError(maybe_snapshot.status());
        }

        [self.events addObject:event];
      });
  _queryListeners[query] = listener;
  TargetId targetID;
  _workerQueue->EnqueueBlocking([&] { targetID = _eventManager->AddQueryListener(listener); });
  return targetID;
}

- (void)removeUserListenerWithQuery:(const Query &)query {
  auto found_iter = _queryListeners.find(query);
  if (found_iter != _queryListeners.end()) {
    std::shared_ptr<QueryListener> listener = found_iter->second;
    _queryListeners.erase(found_iter);

    _workerQueue->EnqueueBlocking([&] { _eventManager->RemoveQueryListener(listener); });
  }
}

- (void)writeUserMutation:(Mutation)mutation {
  FSTOutstandingWrite *write = [[FSTOutstandingWrite alloc] init];
  write.write = mutation;
  [[self currentOutstandingWrites] addObject:write];
  LOG_DEBUG("sending a user write.");
  _workerQueue->EnqueueBlocking([=] {
    _syncEngine->WriteMutations({mutation}, [self, write, mutation](Status error) {
      LOG_DEBUG("A callback was called with error: %s", error.error_message());
      write.done = YES;
      write.error = error.ToNSError();

      NSString *mutationKey = MakeNSString(mutation.key().ToString());
      if (!error.ok()) {
        [self.rejectedDocs addObject:mutationKey];
      } else {
        [self.acknowledgedDocs addObject:mutationKey];
      }
    });
  });
}

- (void)receiveWatchChange:(const WatchChange &)change
           snapshotVersion:(const SnapshotVersion &)snapshot {
  _workerQueue->EnqueueBlocking([&] { _datastore->WriteWatchChange(change, snapshot); });
}

- (void)receiveWatchStreamError:(int)errorCode userInfo:(NSDictionary<NSString *, id> *)userInfo {
  Status error{static_cast<Error>(errorCode), MakeString([userInfo description])};

  _workerQueue->EnqueueBlocking([&] {
    _datastore->FailWatchStream(error);
    // Unlike web, stream should re-open synchronously (if we have any listeners)
    if (!_queryListeners.empty()) {
      HARD_ASSERT(_datastore->IsWatchStreamOpen(), "Watch stream is open");
    }
  });
}

- (std::map<DocumentKey, TargetId>)currentLimboDocuments {
  return _syncEngine->GetCurrentLimboDocuments();
}

- (const std::unordered_map<TargetId, QueryData> &)activeTargets {
  return _datastore->ActiveTargets();
}

- (const ActiveTargetMap &)expectedActiveTargets {
  return _expectedActiveTargets;
}

- (void)setExpectedActiveTargets:(ActiveTargetMap)targets {
  _expectedActiveTargets = std::move(targets);
}

#pragma mark - Helper Methods

- (NSMutableArray<FSTOutstandingWrite *> *)currentOutstandingWrites {
  NSMutableArray<FSTOutstandingWrite *> *writes = _outstandingWrites[_currentUser];
  if (!writes) {
    writes = [NSMutableArray array];
    _outstandingWrites[_currentUser] = writes;
  }
  return writes;
}

@end

NS_ASSUME_NONNULL_END
