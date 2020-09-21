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

#import "GDTCORTests/Common/Categories/GDTCORFlatFileStorage+Testing.h"

#import <GoogleDataTransport/GDTCORClock.h>
#import <GoogleDataTransport/GDTCOREvent.h>

@implementation GDTCORFlatFileStorage (Testing)

- (void)reset {
  dispatch_sync(self.storageQueue, ^{
    [self.targetToEventSet removeAllObjects];
    [self.storedEvents removeAllObjects];
    [[NSFileManager defaultManager] removeItemAtPath:[GDTCORFlatFileStorage archivePath] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[GDTCORFlatFileStorage baseEventStoragePath]
                                               error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[GDTCORFlatFileStorage libraryDataStoragePath]
                                               error:nil];
  });
  dispatch_semaphore_t sema = dispatch_semaphore_create(0);
  [[GDTCORFlatFileStorage sharedInstance] storageSizeWithCallback:^(uint64_t storageSize) {
    NSAssert(storageSize == 0, @"Storage should contain nothing after a reset");
    dispatch_semaphore_signal(sema);
  }];
  dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
}

@end
