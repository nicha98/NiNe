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
#import <XCTest/XCTest.h>

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseInstanceID/FirebaseInstanceID.h>
#import <GoogleUtilities/GULUserDefaults.h>

#import <FirebaseMessaging/FIRMessaging.h>

#import "Firebase/Messaging/FIRMessaging_Private.h"
#import "Example/Messaging/Tests/FIRMessagingTestUtilities.h"

@interface FIRInstanceID (ExposedForTest)
- (BOOL)isFCMAutoInitEnabled;
- (instancetype)initPrivately;
@end

@interface FIRInstanceIDTest : XCTestCase

@property(nonatomic, readwrite, strong) FIRInstanceID *instanceID;
@property(nonatomic, readwrite, strong) id mockFirebaseApp;
@property(nonatomic, readwrite, strong) FIRMessagingTestUtilities *testUtil;
@property(nonatomic, strong) FIRMessaging *messaging;


@end

@implementation FIRInstanceIDTest

- (void)setUp {
  [super setUp];
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  _testUtil = [[FIRMessagingTestUtilities alloc] initWithUserDefaults:defaults withRMQManager:NO];
  _instanceID = _testUtil.instanceID;
  _messaging = _testUtil.messaging;
  _mockFirebaseApp = OCMClassMock([FIRApp class]);
  OCMStub([_mockFirebaseApp defaultApp]).andReturn(_mockFirebaseApp);
}

- (void)tearDown {
  [_testUtil cleanupAfterTest];
  _instanceID = nil;
  _messaging = nil;
  [_mockFirebaseApp stopMocking];
  [super tearDown];
}

- (void)testFCMAutoInitEnabled {
  OCMStub([_mockFirebaseApp isDataCollectionDefaultEnabled]).andReturn(YES);
  _messaging.autoInitEnabled = YES;
  XCTAssertTrue(
      [_instanceID isFCMAutoInitEnabled],
      @"When FCM is available, FCM Auto Init Enabled should be FCM's autoInitEnable property.");

  _messaging.autoInitEnabled = NO;
  XCTAssertFalse(
      [_instanceID isFCMAutoInitEnabled],
      @"When FCM is available, FCM Auto Init Enabled should be FCM's autoInitEnable property.");

  _messaging.autoInitEnabled = YES;
  XCTAssertTrue([_instanceID isFCMAutoInitEnabled]);
}

@end
