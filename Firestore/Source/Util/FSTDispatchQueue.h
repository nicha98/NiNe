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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Well-known "timer" IDs used when scheduling delayed callbacks on the FSTDispatchQueue. These IDs
 * can then be used from tests to check for the presence of callbacks or to run them early.
 */
typedef NS_ENUM(NSInteger, FSTTimerID) {
  FSTTimerIDAll,  // Sentinel value to be used with runDelayedCallbacksUntil: to run all blocks.
  FSTTimerIDListenStreamIdle,
  FSTTimerIDListenStreamConnection,
  FSTTimerIDWriteStreamIdle,
  FSTTimerIDWriteStreamConnection
};

/**
 * Handle to a callback scheduled via [FSTDispatchQueue dispatchAfterDelay:]. Supports cancellation
 * via the cancel method.
 */
@interface FSTDelayedCallback : NSObject

/**
 * Cancels the callback if it hasn't already been executed or canceled.
 *
 * As long as the callback has not yet been run, calling cancel() (from a callback already running
 * on the dispatch queue) provides a guarantee that the operation will not be run.
 */
- (void)cancel;

@end

@interface FSTDispatchQueue : NSObject

/** Creates and returns an FSTDispatchQueue wrapping the specified dispatch_queue_t. */
+ (instancetype)queueWith:(dispatch_queue_t)dispatchQueue;

- (instancetype)initWithQueue:(dispatch_queue_t)queue NS_DESIGNATED_INITIALIZER;

- (instancetype)init __attribute__((unavailable("Use static constructor method.")));

/**
 * Asserts that we are already running on this queue (actually, we can only verify that the
 * queue's label is the same, but hopefully that's good enough.)
 */
- (void)verifyIsCurrentQueue;

/**
 * Same as dispatch_async() except it asserts that we're not already on the queue, since this
 * generally indicates a bug (and can lead to re-ordering of operations, etc).
 *
 * @param block The block to run.
 */
- (void)dispatchAsync:(void (^)(void))block;

/**
 * Unlike dispatchAsync: this method does not require you to dispatch to a different queue than
 * the current one (thus it is equivalent to a raw dispatch_async()).
 *
 * This is useful, e.g. for dispatching to the user's queue directly from user API call (in which
 * case we don't know if we're already on the user's queue or not).
 *
 * @param block The block to run.
 */
- (void)dispatchAsyncAllowingSameQueue:(void (^)(void))block;

/**
 * Schedules a callback after the specified delay.
 *
 * Unlike dispatchAsync: this method does not require you to dispatch to a different queue than
 * the current one.
 *
 * The returned FSTDelayedCallback handle can be used to cancel the callback prior to its running.
 *
 * @param block The block to run.
 * @param delay The delay (in seconds) after which to run the block.
 * @param timerID An FSTTimerID that can be used from tests to check for the presence of this
 *   callback or to schedule it to run early.
 * @return A FSTDelayedCallback instance that can be used for cancellation.
 */
- (FSTDelayedCallback *)dispatchAfterDelay:(NSTimeInterval)delay
                                   timerID:(FSTTimerID)timerID
                                     block:(void (^)(void))block;

/**
 * For Tests: Determine if a delayed callback with a particular FSTTimerID exists.
 */
- (BOOL)containsDelayedCallbackWithTimerID:(FSTTimerID)timerID;

/**
 * For Tests: Runs delayed callbacks early, blocking until completion.
 *
 * @param lastTimerID Only delayed callbacks up to and including one that was scheduled using this
 *   FSTTimerID will be run. Method throws if no matching callback exists.
 */
- (void)runDelayedCallbacksUntil:(FSTTimerID)lastTimerID;

/** The underlying wrapped dispatch_queue_t */
@property(nonatomic, strong, readonly) dispatch_queue_t queue;

@end

NS_ASSUME_NONNULL_END
