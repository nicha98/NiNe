/*
 * Copyright 2019 Google
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

#import <FirebaseMessaging/FIRMessaging.h>
#import <FirebaseInstanceID/FIRInstanceID.h>

@class GULUserDefaults;

NS_ASSUME_NONNULL_BEGIN

@interface FIRMessaging (TestUtilities)
// Surface the user defaults instance to clean up after tests.
@property(nonatomic, strong) NSUserDefaults *messagingUserDefaults;

@end

@interface FIRMessagingTestUtilities : NSObject

@property(nonatomic, strong) id mockInstanceID;
@property(nonatomic, strong) id mockPubsub;
@property(nonatomic, strong) id mockMessaging;
@property(nonatomic, strong) id mockInstallations;
@property(nonatomic, readonly, strong) FIRMessaging *messaging;
@property(nonatomic, readonly, strong) FIRInstanceID *instanceID;


- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults withRMQManager:(BOOL)withRMQManager;

- (void)cleanupAfterTest;

@end

NS_ASSUME_NONNULL_END
