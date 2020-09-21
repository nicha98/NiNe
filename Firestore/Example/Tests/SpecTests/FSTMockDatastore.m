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

#import "FSTMockDatastore.h"

#import "Auth/FSTEmptyCredentialsProvider.h"
#import "Core/FSTDatabaseInfo.h"
#import "Core/FSTSnapshotVersion.h"
#import "Local/FSTQueryData.h"
#import "Model/FSTDatabaseID.h"
#import "Model/FSTMutation.h"
#import "Util/FSTAssert.h"
#import "Util/FSTLogger.h"

#import "FSTWatchChange+Testing.h"

@class GRPCProtoCall;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTMockWatchStream

@interface FSTMockWatchStream : FSTWatchStream

- (instancetype)initWithDatabase:(FSTDatabaseInfo *)database
             workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue
                     credentials:(id<FSTCredentialsProvider>)credentials
                        delegate:(id<FSTWatchStreamDelegate>)delegate NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithDatabase:(FSTDatabaseInfo *)database
             workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue
                     credentials:(id<FSTCredentialsProvider>)credentials
            responseMessageClass:(Class)responseMessageClass
                        delegate:(id<FSTWatchStreamDelegate>)delegate NS_UNAVAILABLE;

@property(nonatomic, assign) BOOL open;

@property(nonatomic, strong, readonly)
    NSMutableDictionary<FSTBoxedTargetID *, FSTQueryData *> *activeTargets;

@end

@implementation FSTMockWatchStream

- (instancetype)initWithDatabase:(FSTDatabaseInfo *)database
             workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue
                     credentials:(id<FSTCredentialsProvider>)credentials
                        delegate:(id<FSTWatchStreamDelegate>)delegate {
  self = [super initWithDatabase:database
             workerDispatchQueue:workerDispatchQueue
                     credentials:credentials
            responseMessageClass:[FSTWatchChange class]
                        delegate:delegate];
  if (self) {
    FSTAssert(database, @"Database must not be nil");
    _activeTargets = [NSMutableDictionary dictionary];
  }
  return self;
}

#pragma mark - Overridden FSTWatchStream methods.

- (void)start {
  FSTAssert(!self.open, @"Trying to start already started watch stream");
  self.open = YES;
  [self handleStreamOpen];
}

- (BOOL)isOpen {
  return self.open;
}

- (BOOL)isStarted {
  return self.open;
}

- (void)handleStreamOpen {
  [self.delegate watchStreamDidOpen];
}

- (void)watchQuery:(FSTQueryData *)query {
  FSTLog(@"watchQuery: %d: %@", query.targetID, query.query);
  // Snapshot version is ignored on the wire
  FSTQueryData *sentQueryData =
      [query queryDataByReplacingSnapshotVersion:[FSTSnapshotVersion noVersion]
                                     resumeToken:query.resumeToken];
  self.activeTargets[@(query.targetID)] = sentQueryData;
}

- (void)unwatchTargetID:(FSTTargetID)targetID {
  FSTLog(@"unwatchTargetID: %d", targetID);
  [self.activeTargets removeObjectForKey:@(targetID)];
}

- (void)failStreamWithError:(NSError *)error {
  self.open = NO;
  [self.delegate watchStreamDidClose:error];
}

#pragma mark - Helper methods.

- (void)writeWatchChange:(FSTWatchChange *)change snapshotVersion:(FSTSnapshotVersion *)snap {
  if ([change isKindOfClass:[FSTWatchTargetChange class]]) {
    FSTWatchTargetChange *targetChange = (FSTWatchTargetChange *)change;
    if (targetChange.cause) {
      for (NSNumber *targetID in targetChange.targetIDs) {
        if (!self.activeTargets[targetID]) {
          // Technically removing an unknown target is valid (e.g. it could race with a
          // server-side removal), but we want to pay extra careful attention in tests
          // that we only remove targets we listened too.
          FSTFail(@"Removing a non-active target");
        }
        [self.activeTargets removeObjectForKey:targetID];
      }
    }
  }
  [self.delegate watchStreamDidChange:change snapshotVersion:snap];
}

@end

#pragma mark - FSTMockWriteStream

@interface FSTMockWriteStream : FSTWriteStream

- (instancetype)initWithDatabase:(FSTDatabaseInfo *)database
             workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue
                     credentials:(id<FSTCredentialsProvider>)credentials
                        delegate:(id<FSTWriteStreamDelegate>)delegate NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithDatabase:(FSTDatabaseInfo *)database
             workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue
                     credentials:(id<FSTCredentialsProvider>)credentials
            responseMessageClass:(Class)responseMessageClass
                        delegate:(id<FSTWatchStreamDelegate>)delegate NS_UNAVAILABLE;

@property(nonatomic, assign) BOOL open;
@property(nonatomic, strong, readonly) NSMutableArray<NSArray<FSTMutation *> *> *sentMutations;

@end

@implementation FSTMockWriteStream

- (instancetype)initWithDatabase:(FSTDatabaseInfo *)database
             workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue
                     credentials:(id<FSTCredentialsProvider>)credentials
                        delegate:(id<FSTWriteStreamDelegate>)delegate {
  self = [super initWithDatabase:database
             workerDispatchQueue:workerDispatchQueue
                     credentials:credentials
            responseMessageClass:[FSTMutationResult class]
                        delegate:delegate];
  if (self) {
    _sentMutations = [NSMutableArray array];
  }
  return self;
}

#pragma mark - Overridden FSTWriteStream methods.

- (void)start {
  FSTAssert(!self.open, @"Trying to start already started write stream");
  self.open = YES;
  [self.sentMutations removeAllObjects];
  [self handleStreamOpen];
}

- (BOOL)isOpen {
  return self.open;
}

- (BOOL)isStarted {
  return self.open;
}

- (void)writeHandshake {
  self.handshakeComplete = YES;
  [self.delegate writeStreamDidCompleteHandshake];
}

- (void)writeMutations:(NSArray<FSTMutation *> *)mutations {
  [self.sentMutations addObject:mutations];
}

- (void)handleStreamOpen {
  [self.delegate writeStreamDidOpen];
}

#pragma mark - Helper methods.

/** Injects a write ack as though it had come from the backend in response to a write. */
- (void)ackWriteWithVersion:(FSTSnapshotVersion *)commitVersion
            mutationResults:(NSArray<FSTMutationResult *> *)results {
  [self.delegate writeStreamDidReceiveResponseWithVersion:commitVersion mutationResults:results];
}

/** Injects a failed write response as though it had come from the backend. */
- (void)failStreamWithError:(NSError *)error {
  self.open = NO;
  [self.delegate writeStreamDidClose:error];
}

/**
 * Returns the next write that was "sent to the backend", failing if there are no queued sent
 */
- (NSArray<FSTMutation *> *)nextSentWrite {
  FSTAssert(self.sentMutations.count > 0,
            @"Writes need to happen before you can call nextSentWrite.");
  NSArray<FSTMutation *> *result = [self.sentMutations objectAtIndex:0];
  [self.sentMutations removeObjectAtIndex:0];
  return result;
}

/**
 * Returns the number of mutations that have been sent to the backend but not retrieved via
 * nextSentWrite yet.
 */
- (int)sentMutationsCount {
  return (int)self.sentMutations.count;
}

@end

#pragma mark - FSTMockDatastore

@interface FSTMockDatastore ()
@property(nonatomic, strong, nullable) FSTMockWatchStream *watchStream;
@property(nonatomic, strong, nullable) FSTMockWriteStream *writeStream;

/** Properties implemented in FSTDatastore that are nonpublic. */
@property(nonatomic, strong, readonly) FSTDispatchQueue *workerDispatchQueue;
@property(nonatomic, strong, readonly) id<FSTCredentialsProvider> credentials;

@end

@implementation FSTMockDatastore

+ (instancetype)mockDatastoreWithWorkerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue {
  FSTDatabaseID *databaseID = [FSTDatabaseID databaseIDWithProject:@"project" database:@"database"];
  FSTDatabaseInfo *databaseInfo = [FSTDatabaseInfo databaseInfoWithDatabaseID:databaseID
                                                               persistenceKey:@"persistence"
                                                                         host:@"host"
                                                                   sslEnabled:NO];

  FSTEmptyCredentialsProvider *credentials = [[FSTEmptyCredentialsProvider alloc] init];

  return [[FSTMockDatastore alloc] initWithDatabaseInfo:databaseInfo
                                    workerDispatchQueue:workerDispatchQueue
                                            credentials:credentials];
}

#pragma mark - Overridden FSTDatastore methods.

- (FSTWatchStream *)createWatchStreamWithDelegate:(id<FSTWatchStreamDelegate>)delegate {
  FSTAssert(self.databaseInfo, @"DatabaseInfo must not be nil");
  self.watchStream = [[FSTMockWatchStream alloc] initWithDatabase:self.databaseInfo
                                              workerDispatchQueue:self.workerDispatchQueue
                                                      credentials:self.credentials
                                                         delegate:delegate];
  return self.watchStream;
}

- (FSTWriteStream *)createWriteStreamWithDelegate:(id<FSTWriteStreamDelegate>)delegate {
  FSTAssert(self.databaseInfo, @"DatabaseInfo must not be nil");
  self.writeStream = [[FSTMockWriteStream alloc] initWithDatabase:self.databaseInfo
                                              workerDispatchQueue:self.workerDispatchQueue
                                                      credentials:self.credentials
                                                         delegate:delegate];
  return self.writeStream;
}

- (void)authorizeAndStartRPC:(GRPCProtoCall *)rpc completion:(FSTVoidErrorBlock)completion {
  FSTFail(@"FSTMockDatastore shouldn't be starting any RPCs.");
}

#pragma mark - Method exposed for tests to call.

- (NSArray<FSTMutation *> *)nextSentWrite {
  return [self.writeStream nextSentWrite];
}

- (int)writesSent {
  return [self.writeStream sentMutationsCount];
}

- (void)ackWriteWithVersion:(FSTSnapshotVersion *)commitVersion
            mutationResults:(NSArray<FSTMutationResult *> *)results {
  [self.writeStream ackWriteWithVersion:commitVersion mutationResults:results];
}

- (void)failWriteWithError:(NSError *_Nullable)error {
  [self.writeStream failStreamWithError:error];
}

- (void)writeWatchTargetAddedWithTargetIDs:(NSArray<FSTBoxedTargetID *> *)targetIDs {
  FSTWatchTargetChange *change =
      [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateAdded
                                  targetIDs:targetIDs
                                      cause:nil];
  [self writeWatchChange:change snapshotVersion:[FSTSnapshotVersion noVersion]];
}

- (void)writeWatchCurrentWithTargetIDs:(NSArray<FSTBoxedTargetID *> *)targetIDs
                       snapshotVersion:(FSTSnapshotVersion *)snapshotVersion
                           resumeToken:(NSData *)resumeToken {
  FSTWatchTargetChange *change =
      [FSTWatchTargetChange changeWithState:FSTWatchTargetChangeStateCurrent
                                  targetIDs:targetIDs
                                resumeToken:resumeToken];
  [self writeWatchChange:change snapshotVersion:snapshotVersion];
}

- (void)writeWatchChange:(FSTWatchChange *)change snapshotVersion:(FSTSnapshotVersion *)snap {
  [self.watchStream writeWatchChange:change snapshotVersion:snap];
}

- (void)failWatchStreamWithError:(NSError *)error {
  [self.watchStream failStreamWithError:error];
}

- (NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *)activeTargets {
  return [self.watchStream.activeTargets copy];
}

- (BOOL)isWatchStreamOpen {
  return self.watchStream.isOpen;
}

@end

NS_ASSUME_NONNULL_END
