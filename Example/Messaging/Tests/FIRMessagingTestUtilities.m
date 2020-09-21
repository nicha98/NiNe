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

#import <OCMock/OCMock.h>

#import "Example/Messaging/Tests/FIRMessagingTestUtilities.h"

#import <FirebaseAnalyticsInterop/FIRAnalyticsInterop.h>
#import <FirebaseInstanceID/FirebaseInstanceID.h>
#import <GoogleUtilities/GULUserDefaults.h>
#import <FirebaseInstallations/FIRInstallations.h>

#import "Firebase/Messaging/FIRMessagingPubSub.h"
#import "Firebase/Messaging/FIRMessagingRmqManager.h"


NS_ASSUME_NONNULL_BEGIN
static NSString *const kFIRMessagingDefaultsTestDomain = @"com.messaging.tests";

@interface FIRInstanceID (ExposedForTest)

/// Private initializer to avoid singleton usage.
- (FIRInstanceID *)initPrivately;

/// Starts fetching and configuration of InstanceID. This is necessary after the `initPrivately`
/// call.
- (void)start;

@end

@interface FIRMessaging (ExposedForTest)

@property(nonatomic, readwrite, strong) FIRMessagingPubSub *pubsub;
@property(nonatomic, readwrite, strong) FIRMessagingRmqManager *rmq2Manager;

/// Surface internal initializer to avoid singleton usage during tests.
- (instancetype)initWithAnalytics:(nullable id<FIRAnalyticsInterop>)analytics
                   withInstanceID:(FIRInstanceID *)instanceID
                 withUserDefaults:(GULUserDefaults *)defaults;

/// Kicks off required calls for some messaging tests.
- (void)start;
- (void)setupRmqManager;

@end

@interface FIRMessagingRmqManager (ExposedForTest)

- (void)removeDatabase;

@end

@implementation FIRMessagingTestUtilities

- (instancetype)initWithUserDefaults:(GULUserDefaults *)userDefaults withRMQManager:(BOOL)withRMQManager {
  self = [super init];
  if (self) {
    // `+[FIRInstallations installations]` supposed to be used on `-[FIRInstanceID start]` to get
    // `FIRInstallations` default instance. Need to stub it before.
    _mockInstallations = OCMClassMock([FIRInstallations class]);
    OCMStub([self.mockInstallations installations]).andReturn(self.mockInstallations);

    _instanceID = [[FIRInstanceID alloc] initPrivately];
    [_instanceID start];

    // Create the messaging instance and call `start`.
    _messaging = [[FIRMessaging alloc] initWithAnalytics:nil
                                                       withInstanceID:_instanceID
                                                     withUserDefaults:userDefaults];
    if (withRMQManager) {
      [_messaging start];
    }
    _mockMessaging = OCMPartialMock(_messaging);
    if (!withRMQManager) {
      OCMStub([_mockMessaging setupRmqManager]).andDo(nil);
      [(FIRMessaging *)_mockMessaging start];

    }
    _mockInstanceID = OCMPartialMock(_instanceID);
    _mockPubsub = OCMPartialMock(_messaging.pubsub);
  }
  return self;
}

- (void)cleanupAfterTest {
  [_messaging.rmq2Manager removeDatabase];
  [_messaging.messagingUserDefaults removePersistentDomainForName:kFIRMessagingDefaultsTestDomain];
  _messaging.shouldEstablishDirectChannel = NO;
  [_mockPubsub stopMocking];
  [_mockMessaging stopMocking];
  [_mockInstanceID stopMocking];
}

@end

NS_ASSUME_NONNULL_END
