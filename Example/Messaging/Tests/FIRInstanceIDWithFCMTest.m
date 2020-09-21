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
#import <FirebaseMessaging/FIRMessaging.h>

#import "Firebase/Messaging/FIRMessaging_Private.h"
#import "Example/Messaging/Tests/FIRMessagingTestUtilities.h"

@interface FIRInstanceID (ExposedForTest)
- (BOOL)isFCMAutoInitEnabled;
- (instancetype)initPrivately;
- (void)start;
@end

@interface FIRMessaging (ExposedForTest)
@property(nonatomic, readwrite, strong) FIRInstanceID *instanceID;

+ (FIRMessaging *)messagingForTests;
@end

@interface FIRInstanceIDTest : XCTestCase

@property(nonatomic, readwrite, strong) FIRInstanceID *instanceID;
@property(nonatomic, readwrite, strong) id mockFirebaseApp;

@end

@implementation FIRInstanceIDTest

- (void)setUp {
  [super setUp];
  _mockFirebaseApp = OCMClassMock([FIRApp class]);
  OCMStub([_mockFirebaseApp defaultApp]).andReturn(_mockFirebaseApp);
}

- (void)tearDown {
  self.instanceID = nil;
  [_mockFirebaseApp stopMocking];
  [super tearDown];
}

// TODO: Disabled until #4198 is fixed.
- (void)DISABLED_testFCMAutoInitEnabled {
  // Use the standardUserDefaults since that's what IID expects and depends on.
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  FIRMessaging *messaging = [FIRMessagingTestUtilities messagingForTestsWithUserDefaults:defaults];
  OCMStub([_mockFirebaseApp isDataCollectionDefaultEnabled]).andReturn(YES);
  messaging.autoInitEnabled = YES;
  XCTAssertTrue(
      [messaging.instanceID isFCMAutoInitEnabled],
      @"When FCM is available, FCM Auto Init Enabled should be FCM's autoInitEnable property.");

  messaging.autoInitEnabled = NO;
  XCTAssertFalse(
      [_instanceID isFCMAutoInitEnabled],
      @"When FCM is available, FCM Auto Init Enabled should be FCM's autoInitEnable property.");

  messaging.autoInitEnabled = YES;
  XCTAssertTrue([messaging.instanceID isFCMAutoInitEnabled]);
}

@end
