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

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "FIRIAMActionURLFollower.h"
#import "FIRIAMDisplayExecutor.h"
#import "FIRIAMDisplayTriggerDefinition.h"
#import "FIRIAMMessageContentData.h"
#import "FIRInAppMessaging.h"

// A class implementing protocol FIRIAMMessageContentData to be used for unit testing
@interface FIRIAMMessageContentDataForTesting : NSObject <FIRIAMMessageContentData>
@property(nonatomic, readwrite, nonnull) NSString *titleText;
@property(nonatomic, readwrite, nonnull) NSString *bodyText;
@property(nonatomic, nullable) NSString *actionButtonText;
@property(nonatomic, nullable) NSURL *actionURL;
@property(nonatomic, nullable) NSURL *imageURL;
@property BOOL errorEncountered;

- (instancetype)initWithMessageTitle:(NSString *)title
                         messageBody:(NSString *)body
                    actionButtonText:(nullable NSString *)actionButtonText
                           actionURL:(nullable NSURL *)actionURL
                            imageURL:(nullable NSURL *)imageURL
                       hasImageError:(BOOL)hasImageError;
@end

@implementation FIRIAMMessageContentDataForTesting
- (instancetype)initWithMessageTitle:(NSString *)title
                         messageBody:(NSString *)body
                    actionButtonText:(nullable NSString *)actionButtonText
                           actionURL:(nullable NSURL *)actionURL
                            imageURL:(nullable NSURL *)imageURL
                       hasImageError:(BOOL)hasImageError {
  if (self = [super init]) {
    _titleText = title;
    _bodyText = body;
    _imageURL = imageURL;
    _actionButtonText = actionButtonText;
    _actionURL = actionURL;
    _errorEncountered = hasImageError;
  }
  return self;
}

- (void)loadImageDataWithBlock:(void (^)(NSData *_Nullable imageData,
                                         NSError *_Nullable error))block {
  if (self.errorEncountered) {
    block(nil, [NSError errorWithDomain:@"image error" code:0 userInfo:nil]);
  } else {
    NSString *str = @"image data";
    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
    block(data, nil);
  }
}
@end

// Defines how the message display component triggers the delegate in unit testing
typedef NS_ENUM(NSInteger, FIRInAppMessagingDelegateInteraction) {
  FIRInAppMessagingDelegateInteractionDismiss,  // message display component triggers
  // messageDismissedWithType:
  FIRInAppMessagingDelegateInteractionClick,  // message display component triggers
  // messageClicked:
  FIRInAppMessagingDelegateInteractionError,  // message display component triggers
  // displayErrorEncountered:
  FIRInAppMessagingDelegateInteractionImpressionDetected,  // message has finished a valid
                                                           // impression, but it's not getting
                                                           // closed by the user.
};

// A class implementing protocol FIRInAppMessagingDisplay to be used for unit testing
@interface FIRIAMMessageDisplayForTesting : NSObject <FIRInAppMessagingDisplay>
@property FIRInAppMessagingDelegateInteraction delegateInteraction;

// used for interaction verificatio
@property FIRInAppMessagingDisplayMessage *message;
- (instancetype)initWithDelegateInteraction:(FIRInAppMessagingDelegateInteraction)interaction;
@end

@implementation FIRIAMMessageDisplayForTesting
- (instancetype)initWithDelegateInteraction:(FIRInAppMessagingDelegateInteraction)interaction {
  if (self = [super init]) {
    _delegateInteraction = interaction;
  }
  return self;
}

- (void)displayMessage:(FIRInAppMessagingDisplayMessage *)messageForDisplay
       displayDelegate:(id<FIRInAppMessagingDisplayDelegate>)displayDelegate {
  self.message = messageForDisplay;

  switch (self.delegateInteraction) {
    case FIRInAppMessagingDelegateInteractionClick:
      [displayDelegate messageClicked:messageForDisplay];
      break;
    case FIRInAppMessagingDelegateInteractionDismiss:
      [displayDelegate messageDismissed:messageForDisplay
                            dismissType:FIRInAppMessagingDismissTypeAuto];
      break;
    case FIRInAppMessagingDelegateInteractionError:
      [displayDelegate displayErrorForMessage:messageForDisplay
                                        error:[NSError errorWithDomain:NSURLErrorDomain
                                                                  code:0
                                                              userInfo:nil]];
      break;
    case FIRInAppMessagingDelegateInteractionImpressionDetected:
      [displayDelegate impressionDetectedForMessage:messageForDisplay];
      break;
  }
}
@end

@interface FIRInAppMessagingDisplayTestDelegate : NSObject <FIRInAppMessagingDisplayDelegate>

@property(nonatomic) BOOL receivedMessageErrorCallback;
@property(nonatomic) BOOL receivedMessageImpressionCallback;
@property(nonatomic) BOOL receivedMessageClickedCallback;
@property(nonatomic) BOOL receivedMessageDismissedCallback;

@end

@implementation FIRInAppMessagingDisplayTestDelegate

- (void)displayErrorForMessage:(nonnull FIRInAppMessagingDisplayMessage *)inAppMessage
                         error:(nonnull NSError *)error {
  self.receivedMessageErrorCallback = YES;
}

- (void)impressionDetectedForMessage:(nonnull FIRInAppMessagingDisplayMessage *)inAppMessage {
  self.receivedMessageImpressionCallback = YES;
}

- (void)messageClicked:(nonnull FIRInAppMessagingDisplayMessage *)inAppMessage {
  self.receivedMessageClickedCallback = YES;
}

- (void)messageDismissed:(nonnull FIRInAppMessagingDisplayMessage *)inAppMessage
             dismissType:(FIRInAppMessagingDismissType)dismissType {
  self.receivedMessageDismissedCallback = YES;
}

@end

@interface FIRIAMDisplayExecutorTests : XCTestCase

@property(nonatomic) FIRIAMDisplaySetting *displaySetting;
@property FIRIAMMessageClientCache *clientMessageCache;
@property id<FIRIAMBookKeeper> mockBookkeeper;
@property id<FIRIAMTimeFetcher> mockTimeFetcher;

@property FIRIAMDisplayExecutor *displayExecutor;

@property FIRIAMActivityLogger *mockActivityLogger;
@property FIRInAppMessaging *mockInAppMessaging;
@property id<FIRIAMAnalyticsEventLogger> mockAnalyticsEventLogger;

@property FIRIAMActionURLFollower *mockActionURLFollower;

@property id<FIRInAppMessagingDisplay> mockMessageDisplayComponent;

// three pre-defined messages
@property FIRIAMMessageDefinition *m1, *m2, *m3, *m4;
@end

@implementation FIRIAMDisplayExecutorTests

- (void)setupMessageTexture {
  // startTime, endTime here ensures messages with them are active
  NSTimeInterval activeStartTime = 0;
  NSTimeInterval activeEndTime = [[NSDate date] timeIntervalSince1970] + 10000;

  // m1 & m3 will be of contextual trigger
  FIRIAMDisplayTriggerDefinition *contextualTriggerDefinition =
      [[FIRIAMDisplayTriggerDefinition alloc] initWithFirebaseAnalyticEvent:@"test_event"];

  // m2 and m4 will be of app open trigger
  FIRIAMDisplayTriggerDefinition *appOpentriggerDefinition =
      [[FIRIAMDisplayTriggerDefinition alloc] initForAppForegroundTrigger];

  FIRIAMMessageContentDataForTesting *m1ContentData = [[FIRIAMMessageContentDataForTesting alloc]
      initWithMessageTitle:@"m1 title"
               messageBody:@"message body"
          actionButtonText:nil
                 actionURL:[NSURL URLWithString:@"http://google.com"]
                  imageURL:[NSURL URLWithString:@"https://google.com/image"]
             hasImageError:NO];

  FIRIAMRenderingEffectSetting *renderSetting1 =
      [FIRIAMRenderingEffectSetting getDefaultRenderingEffectSetting];
  renderSetting1.viewMode = FIRIAMRenderAsBannerView;

  FIRIAMMessageRenderData *renderData1 =
      [[FIRIAMMessageRenderData alloc] initWithMessageID:@"m1"
                                             messageName:@"name"
                                             contentData:m1ContentData
                                         renderingEffect:renderSetting1];

  self.m1 = [[FIRIAMMessageDefinition alloc] initWithRenderData:renderData1
                                                      startTime:activeStartTime
                                                        endTime:activeEndTime
                                              triggerDefinition:@[ contextualTriggerDefinition ]];

  FIRIAMMessageContentDataForTesting *m2ContentData = [[FIRIAMMessageContentDataForTesting alloc]
      initWithMessageTitle:@"m2 title"
               messageBody:@"message body"
          actionButtonText:nil
                 actionURL:[NSURL URLWithString:@"http://google.com"]
                  imageURL:[NSURL URLWithString:@"https://unsplash.it/300/400"]
             hasImageError:NO];

  FIRIAMRenderingEffectSetting *renderSetting2 =
      [FIRIAMRenderingEffectSetting getDefaultRenderingEffectSetting];
  renderSetting2.viewMode = FIRIAMRenderAsModalView;

  FIRIAMMessageRenderData *renderData2 =
      [[FIRIAMMessageRenderData alloc] initWithMessageID:@"m2"
                                             messageName:@"name"
                                             contentData:m2ContentData
                                         renderingEffect:renderSetting2];

  self.m2 = [[FIRIAMMessageDefinition alloc] initWithRenderData:renderData2
                                                      startTime:activeStartTime
                                                        endTime:activeEndTime
                                              triggerDefinition:@[ appOpentriggerDefinition ]];

  FIRIAMMessageContentDataForTesting *m3ContentData = [[FIRIAMMessageContentDataForTesting alloc]
      initWithMessageTitle:@"m3 title"
               messageBody:@"message body"
          actionButtonText:nil
                 actionURL:[NSURL URLWithString:@"http://google.com"]
                  imageURL:[NSURL URLWithString:@"https://google.com/image"]
             hasImageError:NO];

  FIRIAMRenderingEffectSetting *renderSetting3 =
      [FIRIAMRenderingEffectSetting getDefaultRenderingEffectSetting];
  renderSetting3.viewMode = FIRIAMRenderAsImageOnlyView;

  FIRIAMMessageRenderData *renderData3 =
      [[FIRIAMMessageRenderData alloc] initWithMessageID:@"m3"
                                             messageName:@"name"
                                             contentData:m3ContentData
                                         renderingEffect:renderSetting3];

  self.m3 = [[FIRIAMMessageDefinition alloc] initWithRenderData:renderData3
                                                      startTime:activeStartTime
                                                        endTime:activeEndTime
                                              triggerDefinition:@[ contextualTriggerDefinition ]];

  FIRIAMMessageContentDataForTesting *m4ContentData = [[FIRIAMMessageContentDataForTesting alloc]
      initWithMessageTitle:@"m4 title"
               messageBody:@"message body"
          actionButtonText:nil
                 actionURL:[NSURL URLWithString:@"http://google.com"]
                  imageURL:[NSURL URLWithString:@"https://google.com/image"]
             hasImageError:NO];

  FIRIAMRenderingEffectSetting *renderSetting4 =
      [FIRIAMRenderingEffectSetting getDefaultRenderingEffectSetting];
  renderSetting4.viewMode = FIRIAMRenderAsImageOnlyView;

  FIRIAMMessageRenderData *renderData4 =
      [[FIRIAMMessageRenderData alloc] initWithMessageID:@"m4"
                                             messageName:@"name"
                                             contentData:m4ContentData
                                         renderingEffect:renderSetting4];

  self.m4 = [[FIRIAMMessageDefinition alloc] initWithRenderData:renderData4
                                                      startTime:activeStartTime
                                                        endTime:activeEndTime
                                              triggerDefinition:@[ appOpentriggerDefinition ]];
}

NSTimeInterval DISPLAY_MIN_INTERVALS = 1;

- (void)setUp {
  [super setUp];
  [self setupMessageTexture];

  self.displaySetting = [[FIRIAMDisplaySetting alloc] init];
  self.displaySetting.displayMinIntervalInMinutes = DISPLAY_MIN_INTERVALS;
  self.mockBookkeeper = OCMProtocolMock(@protocol(FIRIAMBookKeeper));

  FIRIAMFetchResponseParser *parser =
      [[FIRIAMFetchResponseParser alloc] initWithTimeFetcher:[[FIRIAMTimerWithNSDate alloc] init]];

  self.clientMessageCache = [[FIRIAMMessageClientCache alloc] initWithBookkeeper:self.mockBookkeeper
                                                             usingResponseParser:parser];
  self.mockTimeFetcher = OCMProtocolMock(@protocol(FIRIAMTimeFetcher));
  self.mockActivityLogger = OCMClassMock([FIRIAMActivityLogger class]);
  self.mockAnalyticsEventLogger = OCMProtocolMock(@protocol(FIRIAMAnalyticsEventLogger));
  self.mockInAppMessaging = OCMClassMock([FIRInAppMessaging class]);
  self.mockActionURLFollower = OCMClassMock([FIRIAMActionURLFollower class]);

  self.displayExecutor =
      [[FIRIAMDisplayExecutor alloc] initWithInAppMessaging:self.mockInAppMessaging
                                                    setting:self.displaySetting
                                               messageCache:self.clientMessageCache
                                                timeFetcher:self.mockTimeFetcher
                                                 bookKeeper:self.mockBookkeeper
                                          actionURLFollower:self.mockActionURLFollower
                                             activityLogger:self.mockActivityLogger
                                       analyticsEventLogger:self.mockAnalyticsEventLogger];

  OCMStub([self.mockBookkeeper recordNewImpressionForMessage:[OCMArg any]
                                 withStartTimestampInSeconds:1000]);
}

- (void)testRegularMessageAvailableCase {
  // This setup allows next message to be displayed from display interval perspective.
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds])
      .andReturn(DISPLAY_MIN_INTERVALS * 60 + 100);

  FIRIAMMessageDisplayForTesting *display = [[FIRIAMMessageDisplayForTesting alloc]
      initWithDelegateInteraction:FIRInAppMessagingDelegateInteractionClick];
  self.displayExecutor.messageDisplayComponent = display;
  [self.clientMessageCache setMessageData:@[ self.m2, self.m4 ]];
  [self.displayExecutor checkAndDisplayNextAppForegroundMessage];
  NSInteger remainingMsgCount = [self.clientMessageCache allRegularMessages].count;
  XCTAssertEqual(1, remainingMsgCount);

  // Verify that the message content handed to display component is expected
  XCTAssertEqualObjects(self.m2.renderData.messageID, display.message.campaignInfo.messageID);
}

- (void)testFollowingActionURL {
  // This setup allows next message to be displayed from display interval perspective.
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds])
      .andReturn(DISPLAY_MIN_INTERVALS * 60 + 100);

  FIRIAMMessageDisplayForTesting *display = [[FIRIAMMessageDisplayForTesting alloc]
      initWithDelegateInteraction:FIRInAppMessagingDelegateInteractionClick];
  self.displayExecutor.messageDisplayComponent = display;
  [self.clientMessageCache setMessageData:@[ self.m2 ]];

  // not expecting triggering analytics recording
  OCMExpect([self.mockActionURLFollower
          followActionURL:[OCMArg isEqual:self.m2.renderData.contentData.actionURL]
      withCompletionBlock:[OCMArg any]]);
  [self.displayExecutor checkAndDisplayNextAppForegroundMessage];

  OCMVerifyAll((id)self.mockActionURLFollower);
}

- (void)testFollowingActionURLForTestMessage {
  // This setup allows next message to be displayed from display interval perspective.
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds])
      .andReturn(DISPLAY_MIN_INTERVALS * 60 + 100);

  FIRIAMMessageDefinition *testMessage =
      [[FIRIAMMessageDefinition alloc] initTestMessageWithRenderData:self.m1.renderData];

  FIRIAMMessageDisplayForTesting *display = [[FIRIAMMessageDisplayForTesting alloc]
      initWithDelegateInteraction:FIRInAppMessagingDelegateInteractionClick];
  self.displayExecutor.messageDisplayComponent = display;
  [self.clientMessageCache setMessageData:@[ testMessage ]];

  // not expecting triggering analytics recording
  OCMExpect([self.mockActionURLFollower
          followActionURL:[OCMArg isEqual:testMessage.renderData.contentData.actionURL]
      withCompletionBlock:[OCMArg any]]);
  [self.displayExecutor checkAndDisplayNextAppForegroundMessage];

  OCMVerifyAll((id)self.mockActionURLFollower);
}

- (void)testClientTestMessageAvailableCase {
  // When test message is present in cache, even if the display time interval has not been
  // reached, we still render.

  // 10 seconds is less than DISPLAY_MIN_INTERVALS minutes, so we have not reached
  // minimal display time interval yet.
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds]).andReturn(10);
  FIRIAMMessageDefinition *testMessage =
      [[FIRIAMMessageDefinition alloc] initTestMessageWithRenderData:self.m1.renderData];

  [self.clientMessageCache setMessageData:@[ self.m2, testMessage, self.m4 ]];

  // We have test message in the cache now.
  XCTAssertTrue([self.clientMessageCache hasTestMessage]);

  FIRIAMMessageDisplayForTesting *display = [[FIRIAMMessageDisplayForTesting alloc]
      initWithDelegateInteraction:FIRInAppMessagingDelegateInteractionClick];
  self.displayExecutor.messageDisplayComponent = display;

  [self.displayExecutor checkAndDisplayNextAppForegroundMessage];

  // No more test message in the cache now.
  XCTAssertFalse([self.clientMessageCache hasTestMessage]);
}

// If a message is still being displayed, we won't try to display a second one on top of it
- (void)testNoDualDisplay {
  // This setup allows next message to be displayed from display interval perspective.
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds])
      .andReturn(DISPLAY_MIN_INTERVALS * 60 + 100);

  // This display component only detects a valid impression, but does not end the renderig
  FIRIAMMessageDisplayForTesting *display = [[FIRIAMMessageDisplayForTesting alloc]
      initWithDelegateInteraction:FIRInAppMessagingDelegateInteractionImpressionDetected];
  self.displayExecutor.messageDisplayComponent = display;

  [self.clientMessageCache setMessageData:@[ self.m2, self.m4 ]];
  [self.displayExecutor checkAndDisplayNextAppForegroundMessage];

  // m2 is being rendered
  XCTAssertEqualObjects(self.m2.renderData.messageID, display.message.campaignInfo.messageID);

  NSInteger remainingMsgCount = [self.clientMessageCache allRegularMessages].count;
  XCTAssertEqual(1, remainingMsgCount);

  // try to display again when the in-display flag is already turned on (and not turned off yet)
  [self.displayExecutor checkAndDisplayNextAppForegroundMessage];

  // Verify that the message in display component is still m2
  XCTAssertEqualObjects(self.m2.renderData.messageID, display.message.campaignInfo.messageID);

  // message in cache remain unchanged for the second checkAndDisplayNext call
  remainingMsgCount = [self.clientMessageCache allRegularMessages].count;
  XCTAssertEqual(1, remainingMsgCount);
}

// this test case contracts testNoAnalyticsTrackingOnTestMessage to cover both positive
// and negative cases
- (void)testDoesAnalyticsTrackingOnNonTestMessage {
  // This setup allows next message to be displayed from display interval perspective.
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds])
      .andReturn(DISPLAY_MIN_INTERVALS * 60 + 100);

  // not expecting triggering analytics recording
  OCMExpect([self.mockAnalyticsEventLogger
      logAnalyticsEventForType:FIRIAMAnalyticsEventMessageImpression
                 forCampaignID:[OCMArg isEqual:self.m2.renderData.messageID]
              withCampaignName:[OCMArg any]
                 eventTimeInMs:[OCMArg any]
                    completion:[OCMArg any]]);
  [self.clientMessageCache setMessageData:@[ self.m2 ]];

  FIRIAMMessageDisplayForTesting *display = [[FIRIAMMessageDisplayForTesting alloc]
      initWithDelegateInteraction:FIRInAppMessagingDelegateInteractionClick];
  self.displayExecutor.messageDisplayComponent = display;
  [self.displayExecutor checkAndDisplayNextAppForegroundMessage];
  OCMVerifyAll((id)self.mockAnalyticsEventLogger);
}

- (void)testDoesAnalyticsTrackingOnDisplayError {
  // 1000 seconds is larger than DISPLAY_MIN_INTERVALS minutes
  // last display time is set to 0 by default
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds]).andReturn(1000);

  // not expecting triggering analytics recording
  OCMExpect([self.mockAnalyticsEventLogger
      logAnalyticsEventForType:FIRIAMAnalyticsEventImageFetchError
                 forCampaignID:[OCMArg isEqual:self.m2.renderData.messageID]
              withCampaignName:[OCMArg any]
                 eventTimeInMs:[OCMArg any]
                    completion:[OCMArg any]]);

  [self.clientMessageCache setMessageData:@[ self.m2 ]];

  FIRIAMMessageDisplayForTesting *display = [[FIRIAMMessageDisplayForTesting alloc]
      initWithDelegateInteraction:FIRInAppMessagingDelegateInteractionError];
  self.displayExecutor.messageDisplayComponent = display;

  [self.displayExecutor checkAndDisplayNextAppForegroundMessage];
  OCMVerifyAll((id)self.mockAnalyticsEventLogger);
}

- (void)testAnalyticsTrackingOnMessageDismissCase {
  // This setup allows next message to be displayed from display interval perspective.
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds])
      .andReturn(DISPLAY_MIN_INTERVALS * 60 + 100);

  // not expecting triggering analytics recording
  OCMExpect([self.mockAnalyticsEventLogger
      logAnalyticsEventForType:FIRIAMAnalyticsEventMessageDismissAuto
                 forCampaignID:[OCMArg isEqual:self.m2.renderData.messageID]
              withCampaignName:[OCMArg any]
                 eventTimeInMs:[OCMArg any]
                    completion:[OCMArg any]]);

  // Make sure we don't log the url follow event.
  OCMReject([self.mockAnalyticsEventLogger
      logAnalyticsEventForType:FIRIAMAnalyticsEventActionURLFollow
                 forCampaignID:[OCMArg isEqual:self.m2.renderData.messageID]
              withCampaignName:[OCMArg any]
                 eventTimeInMs:[OCMArg any]
                    completion:[OCMArg any]]);

  [self.clientMessageCache setMessageData:@[ self.m2 ]];

  FIRIAMMessageDisplayForTesting *display = [[FIRIAMMessageDisplayForTesting alloc]
      initWithDelegateInteraction:FIRInAppMessagingDelegateInteractionDismiss];
  self.displayExecutor.messageDisplayComponent = display;

  [self.displayExecutor checkAndDisplayNextAppForegroundMessage];
  OCMVerifyAll((id)self.mockAnalyticsEventLogger);
}

- (void)testAnalyticsTrackingOnMessageClickCase {
  // This setup allows next message to be displayed from display interval perspective.
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds])
      .andReturn(DISPLAY_MIN_INTERVALS * 60 + 100);

  // We expect two analytics events for a click action:
  // An impression event and an action URL follow event
  OCMExpect([self.mockAnalyticsEventLogger
      logAnalyticsEventForType:FIRIAMAnalyticsEventMessageImpression
                 forCampaignID:[OCMArg isEqual:self.m2.renderData.messageID]
              withCampaignName:[OCMArg any]
                 eventTimeInMs:[OCMArg any]
                    completion:[OCMArg any]]);

  OCMExpect([self.mockAnalyticsEventLogger
      logAnalyticsEventForType:FIRIAMAnalyticsEventActionURLFollow
                 forCampaignID:[OCMArg isEqual:self.m2.renderData.messageID]
              withCampaignName:[OCMArg any]
                 eventTimeInMs:[OCMArg any]
                    completion:[OCMArg any]]);

  [self.clientMessageCache setMessageData:@[ self.m2 ]];

  FIRIAMMessageDisplayForTesting *display = [[FIRIAMMessageDisplayForTesting alloc]
      initWithDelegateInteraction:FIRInAppMessagingDelegateInteractionClick];
  self.displayExecutor.messageDisplayComponent = display;

  [self.displayExecutor checkAndDisplayNextAppForegroundMessage];
  OCMVerifyAll((id)self.mockAnalyticsEventLogger);
}

- (void)testAnalyticsTrackingOnTestMessageClickCase {
  // 1000 seconds is larger than DISPLAY_MIN_INTERVALS minutes
  // last display time is set to 0 by default
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds]).andReturn(1000);

  // We expect two analytics events for a click action:
  // An test message impression event and a test message click event
  OCMExpect([self.mockAnalyticsEventLogger
      logAnalyticsEventForType:FIRIAMAnalyticsEventTestMessageImpression
                 forCampaignID:[OCMArg isEqual:self.m2.renderData.messageID]
              withCampaignName:[OCMArg any]
                 eventTimeInMs:[OCMArg any]
                    completion:[OCMArg any]]);

  OCMExpect([self.mockAnalyticsEventLogger
      logAnalyticsEventForType:FIRIAMAnalyticsEventTestMessageClick
                 forCampaignID:[OCMArg isEqual:self.m2.renderData.messageID]
              withCampaignName:[OCMArg any]
                 eventTimeInMs:[OCMArg any]
                    completion:[OCMArg any]]);

  FIRIAMMessageDefinition *testMessage =
      [[FIRIAMMessageDefinition alloc] initTestMessageWithRenderData:self.m2.renderData];

  [self.clientMessageCache setMessageData:@[ testMessage ]];

  FIRIAMMessageDisplayForTesting *display = [[FIRIAMMessageDisplayForTesting alloc]
      initWithDelegateInteraction:FIRInAppMessagingDelegateInteractionClick];
  self.displayExecutor.messageDisplayComponent = display;

  [self.displayExecutor checkAndDisplayNextAppForegroundMessage];
  OCMVerifyAll((id)self.mockAnalyticsEventLogger);
}

- (void)testAnalyticsTrackingOnTestMessageDismissCase {
  // 1000 seconds is larger than DISPLAY_MIN_INTERVALS minutes
  // last display time is set to 0 by default
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds]).andReturn(1000);

  // We expect a test message impression
  OCMExpect([self.mockAnalyticsEventLogger
      logAnalyticsEventForType:FIRIAMAnalyticsEventTestMessageImpression
                 forCampaignID:[OCMArg isEqual:self.m2.renderData.messageID]
              withCampaignName:[OCMArg any]
                 eventTimeInMs:[OCMArg any]
                    completion:[OCMArg any]]);
  // No click event
  OCMReject([self.mockAnalyticsEventLogger
      logAnalyticsEventForType:FIRIAMAnalyticsEventTestMessageClick
                 forCampaignID:[OCMArg isEqual:self.m2.renderData.messageID]
              withCampaignName:[OCMArg any]
                 eventTimeInMs:[OCMArg any]
                    completion:[OCMArg any]]);

  FIRIAMMessageDefinition *testMessage =
      [[FIRIAMMessageDefinition alloc] initTestMessageWithRenderData:self.m2.renderData];

  [self.clientMessageCache setMessageData:@[ testMessage ]];

  FIRIAMMessageDisplayForTesting *display = [[FIRIAMMessageDisplayForTesting alloc]
      initWithDelegateInteraction:FIRInAppMessagingDelegateInteractionDismiss];
  self.displayExecutor.messageDisplayComponent = display;

  [self.displayExecutor checkAndDisplayNextAppForegroundMessage];
  OCMVerifyAll((id)self.mockAnalyticsEventLogger);
}

- (void)testAnalyticsTrackingImpressionOnValidImpressionDetectedCase {
  // This setup allows next message to be displayed from display interval perspective.
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds])
      .andReturn(DISPLAY_MIN_INTERVALS * 60 + 100);

  // not expecting triggering analytics recording
  OCMExpect([self.mockAnalyticsEventLogger
      logAnalyticsEventForType:FIRIAMAnalyticsEventMessageImpression
                 forCampaignID:[OCMArg isEqual:self.m2.renderData.messageID]
              withCampaignName:[OCMArg any]
                 eventTimeInMs:[OCMArg any]
                    completion:[OCMArg any]]);

  [self.clientMessageCache setMessageData:@[ self.m2 ]];

  FIRIAMMessageDisplayForTesting *display = [[FIRIAMMessageDisplayForTesting alloc]
      initWithDelegateInteraction:FIRInAppMessagingDelegateInteractionImpressionDetected];
  self.displayExecutor.messageDisplayComponent = display;

  [self.displayExecutor checkAndDisplayNextAppForegroundMessage];
  OCMVerifyAll((id)self.mockAnalyticsEventLogger);
}

- (void)testNoAnalyticsTrackingOnTestMessage {
  // This setup allows next message to be displayed from display interval perspective.
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds])
      .andReturn(DISPLAY_MIN_INTERVALS * 60 + 100);

  FIRIAMMessageDefinition *testMessage =
      [[FIRIAMMessageDefinition alloc] initTestMessageWithRenderData:self.m1.renderData];

  // not expecting triggering analytics recording
  OCMReject([self.mockAnalyticsEventLogger
      logAnalyticsEventForType:FIRIAMAnalyticsEventMessageImpression
                 forCampaignID:[OCMArg isEqual:self.m1.renderData.messageID]
              withCampaignName:[OCMArg any]
                 eventTimeInMs:[OCMArg any]
                    completion:[OCMArg any]]);
  [self.clientMessageCache setMessageData:@[ testMessage ]];

  FIRIAMMessageDisplayForTesting *display = [[FIRIAMMessageDisplayForTesting alloc]
      initWithDelegateInteraction:FIRInAppMessagingDelegateInteractionClick];
  self.displayExecutor.messageDisplayComponent = display;
  [self.displayExecutor checkAndDisplayNextAppForegroundMessage];
  OCMVerifyAll((id)self.mockAnalyticsEventLogger);
}

- (void)testNoMessageAvailableCase {
  // This setup allows next message to be displayed from display interval perspective.
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds])
      .andReturn(DISPLAY_MIN_INTERVALS * 60 + 100);

  FIRIAMMessageDisplayForTesting *display = [[FIRIAMMessageDisplayForTesting alloc]
      initWithDelegateInteraction:FIRInAppMessagingDelegateInteractionClick];
  self.displayExecutor.messageDisplayComponent = display;
  [self.clientMessageCache setMessageData:@[]];
  [self.displayExecutor checkAndDisplayNextAppForegroundMessage];

  // No display has happened so the message stored in the display component should be nil
  XCTAssertNil(display.message);
  NSInteger remainingMsgCount = [self.clientMessageCache allRegularMessages].count;
  XCTAssertEqual(0, remainingMsgCount);
}

- (void)testIntervalBetweenOnAppOpenDisplays {
  self.displaySetting.displayMinIntervalInMinutes = 10;

  // last display time is set to 0 by default
  // 10 seconds is not long enough for satisfying the 10-min internal requirement
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds]).andReturn(10);

  FIRIAMMessageDisplayForTesting *display = [[FIRIAMMessageDisplayForTesting alloc]
      initWithDelegateInteraction:FIRInAppMessagingDelegateInteractionClick];
  self.displayExecutor.messageDisplayComponent = display;

  [self.clientMessageCache setMessageData:@[ self.m1 ]];
  [self.displayExecutor checkAndDisplayNextAppForegroundMessage];

  NSInteger remainingMsgCount = [self.clientMessageCache allRegularMessages].count;
  // No display has happened so the message stored in the display component should be nil
  XCTAssertNil(display.message);

  // still got one in the queue
  XCTAssertEqual(1, remainingMsgCount);
}

// making sure that we match on the event names for analytics based events
- (void)testOnFirebaseAnalyticsEventDisplayMessages {
  // This setup allows next message to be displayed from display interval perspective.
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds])
      .andReturn(DISPLAY_MIN_INTERVALS * 60 + 100);

  FIRIAMMessageDisplayForTesting *display = [[FIRIAMMessageDisplayForTesting alloc]
      initWithDelegateInteraction:FIRInAppMessagingDelegateInteractionClick];
  self.displayExecutor.messageDisplayComponent = display;

  // m1 and m3 are messages triggered by 'test_event' analytics events
  [self.clientMessageCache setMessageData:@[ self.m1, self.m3 ]];

  [self.displayExecutor checkAndDisplayNextContextualMessageForAnalyticsEvent:@"different event"];
  NSInteger remainingMsgCount = [self.clientMessageCache allRegularMessages].count;

  // No message matching event "different event", so no message is nil
  XCTAssertNil(display.message);
  // still got 2 in the queue
  XCTAssertEqual(2, remainingMsgCount);

  // now trigger it with 'test_event' and we would expect one message to be displayed and removed
  // from cache
  [self.displayExecutor checkAndDisplayNextContextualMessageForAnalyticsEvent:@"test_event"];
  // Expecting the m1 being used for display
  XCTAssertEqualObjects(self.m1.renderData.messageID, display.message.campaignInfo.messageID);

  remainingMsgCount = [self.clientMessageCache allRegularMessages].count;

  // Now only one message remaining in the queue
  XCTAssertEqual(1, remainingMsgCount);
}

// no regular message rendering if suppress message display flag is turned on
- (void)testNoRenderingIfMessageDisplayIsSuppressed {
  // This setup allows next message to be displayed from display interval perspective.
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds])
      .andReturn(DISPLAY_MIN_INTERVALS * 60 + 100);

  [self.clientMessageCache setMessageData:@[ self.m2, self.m4 ]];

  FIRIAMMessageDisplayForTesting *display = [[FIRIAMMessageDisplayForTesting alloc]
      initWithDelegateInteraction:FIRInAppMessagingDelegateInteractionClick];
  self.displayExecutor.messageDisplayComponent = display;
  self.displayExecutor.suppressMessageDisplay = YES;
  [self.displayExecutor checkAndDisplayNextAppForegroundMessage];

  // no message display has happened
  XCTAssertNil(display.message);

  NSInteger remainingMsgCount = [self.clientMessageCache allRegularMessages].count;
  // no message is removed from the cache
  XCTAssertEqual(2, remainingMsgCount);

  // now allow message rendering again
  self.displayExecutor.suppressMessageDisplay = NO;
  [self.displayExecutor checkAndDisplayNextAppForegroundMessage];
  NSInteger remainingMsgCount2 = [self.clientMessageCache allRegularMessages].count;
  // one message was rendered and removed from the cache
  XCTAssertEqual(1, remainingMsgCount2);
}

// No contextual message rendering if suppress message display flag is turned on
- (void)testNoContextualMsgRenderingIfMessageDisplayIsSuppressed {
  // This setup allows next message to be displayed from display interval perspective.
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds])
      .andReturn(DISPLAY_MIN_INTERVALS * 60 + 100);

  [self.clientMessageCache setMessageData:@[ self.m1, self.m3 ]];

  FIRIAMMessageDisplayForTesting *display = [[FIRIAMMessageDisplayForTesting alloc]
      initWithDelegateInteraction:FIRInAppMessagingDelegateInteractionClick];
  self.displayExecutor.messageDisplayComponent = display;

  self.displayExecutor.suppressMessageDisplay = YES;
  [self.displayExecutor checkAndDisplayNextContextualMessageForAnalyticsEvent:@"test_event"];

  // no message display has happened
  XCTAssertNil(display.message);

  NSInteger remainingMsgCount = [self.clientMessageCache allRegularMessages].count;
  // No message is removed from the cache.
  XCTAssertEqual(2, remainingMsgCount);

  // now re-enable message rendering again
  self.displayExecutor.suppressMessageDisplay = NO;
  [self.displayExecutor checkAndDisplayNextContextualMessageForAnalyticsEvent:@"test_event"];

  NSInteger remainingMsgCount2 = [self.clientMessageCache allRegularMessages].count;
  // one message was rendered and removed from the cache
  XCTAssertEqual(1, remainingMsgCount2);
}

- (void)testMessageClickedCallback {
  FIRInAppMessagingDisplayTestDelegate *delegate =
      [[FIRInAppMessagingDisplayTestDelegate alloc] init];
  self.mockInAppMessaging.delegate = delegate;

  // This setup allows next message to be displayed from display interval perspective.
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds])
      .andReturn(DISPLAY_MIN_INTERVALS * 60 + 100);
  OCMStub(self.mockInAppMessaging.delegate).andReturn(delegate);

  FIRIAMMessageDisplayForTesting *display = [[FIRIAMMessageDisplayForTesting alloc]
      initWithDelegateInteraction:FIRInAppMessagingDelegateInteractionClick];
  self.displayExecutor.messageDisplayComponent = display;
  [self.clientMessageCache setMessageData:@[ self.m2, self.m4 ]];
  [self.displayExecutor checkAndDisplayNextAppForegroundMessage];

  XCTAssertTrue(delegate.receivedMessageClickedCallback);
}

- (void)testMessageImpressionCallback {
  FIRInAppMessagingDisplayTestDelegate *delegate =
      [[FIRInAppMessagingDisplayTestDelegate alloc] init];
  self.mockInAppMessaging.delegate = delegate;

  // This setup allows next message to be displayed from display interval perspective.
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds])
      .andReturn(DISPLAY_MIN_INTERVALS * 60 + 100);
  OCMStub(self.mockInAppMessaging.delegate).andReturn(delegate);

  FIRIAMMessageDisplayForTesting *display = [[FIRIAMMessageDisplayForTesting alloc]
      initWithDelegateInteraction:FIRInAppMessagingDelegateInteractionImpressionDetected];
  self.displayExecutor.messageDisplayComponent = display;
  [self.clientMessageCache setMessageData:@[ self.m2, self.m4 ]];
  [self.displayExecutor checkAndDisplayNextAppForegroundMessage];

  // Verify that the message content handed to display component is expected
  XCTAssertTrue(delegate.receivedMessageImpressionCallback);
}

- (void)testMessageErrorCallback {
  FIRInAppMessagingDisplayTestDelegate *delegate =
      [[FIRInAppMessagingDisplayTestDelegate alloc] init];
  self.mockInAppMessaging.delegate = delegate;

  // This setup allows next message to be displayed from display interval perspective.
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds])
      .andReturn(DISPLAY_MIN_INTERVALS * 60 + 100);
  OCMStub(self.mockInAppMessaging.delegate).andReturn(delegate);

  FIRIAMMessageDisplayForTesting *display = [[FIRIAMMessageDisplayForTesting alloc]
      initWithDelegateInteraction:FIRInAppMessagingDelegateInteractionError];
  self.displayExecutor.messageDisplayComponent = display;
  [self.clientMessageCache setMessageData:@[ self.m2, self.m4 ]];
  [self.displayExecutor checkAndDisplayNextAppForegroundMessage];

  // Verify that the message content handed to display component is expected
  XCTAssertTrue(delegate.receivedMessageErrorCallback);
}

- (void)testMessageDismissedCallback {
  FIRInAppMessagingDisplayTestDelegate *delegate =
      [[FIRInAppMessagingDisplayTestDelegate alloc] init];
  self.mockInAppMessaging.delegate = delegate;

  // This setup allows next message to be displayed from display interval perspective.
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds])
      .andReturn(DISPLAY_MIN_INTERVALS * 60 + 100);
  OCMStub(self.mockInAppMessaging.delegate).andReturn(delegate);

  FIRIAMMessageDisplayForTesting *display = [[FIRIAMMessageDisplayForTesting alloc]
      initWithDelegateInteraction:FIRInAppMessagingDelegateInteractionDismiss];
  self.displayExecutor.messageDisplayComponent = display;
  [self.clientMessageCache setMessageData:@[ self.m2, self.m4 ]];
  [self.displayExecutor checkAndDisplayNextAppForegroundMessage];

  // Verify that the message content handed to display component is expected
  XCTAssertTrue(delegate.receivedMessageDismissedCallback);
}

@end
