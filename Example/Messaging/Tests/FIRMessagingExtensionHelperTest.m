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

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import <OCMock/OCMock.h>

#import "FIRMessaging.h"
#import "FIRMessagingExtensionHelper.h"

typedef void (^FIRMessagingContentHandler)(UNNotificationContent *content);

static NSString *const kFCMPayloadOptionsName = @"fcm_options";
static NSString *const kFCMPayloadOptionsImageURLName = @"image";
static NSString *const kValidImageURL =
    @"https://firebasestorage.googleapis.com/v0/b/fcm-ios-f7f9c.appspot.com/o/"
    @"chubbyBunny.jpg?alt=media&token=d6c56a57-c007-4b27-b20f-f267cc83e9e5";

@interface FIRMessagingExtensionHelper (ExposedForTest)
#if TARGET_OS_IOS && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
- (void)loadAttachmentForURL:(NSURL *)attachmentURL
           completionHandler:(void (^)(UNNotificationAttachment *))completionHandler;
#endif
@end

@interface FIRMessagingExtensionHelperTest : XCTestCase {
  id _mockExtensionHelper;
}
@end

@implementation FIRMessagingExtensionHelperTest

- (void)setUp {
  [super setUp];
  FIRMessagingExtensionHelper *extensionHelper = [FIRMessaging extensionHelper];
  _mockExtensionHelper = OCMPartialMock(extensionHelper);
}

- (void)tearDown {
  [_mockExtensionHelper stopMocking];
}

#if TARGET_OS_IOS && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
#ifdef COCOAPODS
// This test requires internet access.
- (void)testModifyNotificationWithValidPayloadData {
  XCTestExpectation *validPayloadExpectation =
      [self expectationWithDescription:@"Test payload is valid."];

  UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
  content.userInfo = @{kFCMPayloadOptionsName : @{kFCMPayloadOptionsImageURLName : kValidImageURL}};
  FIRMessagingContentHandler handler = ^(UNNotificationContent *content) {
    [validPayloadExpectation fulfill];
  };
  [_mockExtensionHelper populateNotificationContent:content withContentHandler:handler];

  OCMVerify([_mockExtensionHelper loadAttachmentForURL:[OCMArg any]
                                     completionHandler:[OCMArg any]]);
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}
#endif

- (void)testModifyNotificationWithInvalidPayloadData {
  XCTestExpectation *validPayloadExpectation =
      [self expectationWithDescription:@"Test payload is valid."];

  UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
  content.userInfo =
      @{kFCMPayloadOptionsName : @{kFCMPayloadOptionsImageURLName : @"a invalid URL"}};
  FIRMessagingContentHandler handler = ^(UNNotificationContent *content) {
    [validPayloadExpectation fulfill];
  };
  [_mockExtensionHelper populateNotificationContent:content withContentHandler:handler];

  OCMReject([_mockExtensionHelper loadAttachmentForURL:[OCMArg any]
                                     completionHandler:[OCMArg any]]);
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testModifyNotificationWithEmptyPayloadData {
  XCTestExpectation *validPayloadExpectation =
      [self expectationWithDescription:@"Test payload is valid."];

  UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
  content.userInfo =
      @{kFCMPayloadOptionsName : @{kFCMPayloadOptionsImageURLName : @"a invalid URL"}};
  FIRMessagingContentHandler handler = ^(UNNotificationContent *content) {
    [validPayloadExpectation fulfill];
  };
  [_mockExtensionHelper populateNotificationContent:content withContentHandler:handler];

  OCMReject([_mockExtensionHelper loadAttachmentForURL:[OCMArg any]
                                     completionHandler:[OCMArg any]]);
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}
#endif

@end
