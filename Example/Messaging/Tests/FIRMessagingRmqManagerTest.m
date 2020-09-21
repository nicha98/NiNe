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

#import <XCTest/XCTest.h>

#import "Firebase/Messaging/FIRMessagingPersistentSyncMessage.h"
#import "Firebase/Messaging/FIRMessagingRmqManager.h"
#import "Firebase/Messaging/FIRMessagingUtilities.h"
#import "Firebase/Messaging/Protos/GtalkCore.pbobjc.h"

static NSString *const kRmqDatabaseName = @"rmq-test-db";
static NSString *const kRmqDataMessageCategory = @"com.google.gcm-rmq-test";
static const NSTimeInterval kAsyncTestTimout = 0.5;

@interface FIRMessagingRmqManager (ExposedForTest)

- (void)removeDatabase;

@end

@interface FIRMessagingRmqManagerTest : XCTestCase

@property(nonatomic, readwrite, strong) FIRMessagingRmqManager *rmqManager;

@end

@implementation FIRMessagingRmqManagerTest

- (void)setUp {
  [super setUp];
  // Make sure we start off with a clean state each time
  _rmqManager = [[FIRMessagingRmqManager alloc] initWithDatabaseName:kRmqDatabaseName];

}

- (void)tearDown {
  [self.rmqManager removeDatabase];
  [super tearDown];
}

/**
 *  Add s2d messages with different RMQ-ID's to the RMQ. Fetch the messages
 *  and verify that all messages were successfully saved.
 */
- (void)testSavingS2dMessages {
  NSArray *messageIDs = @[ @"message1", @"message2", @"123456" ];
  for (NSString *messageID in messageIDs) {
    [self.rmqManager saveS2dMessageWithRmqId:messageID];
  }
  NSArray *rmqMessages = [self.rmqManager unackedS2dRmqIds];
  XCTAssertEqual(messageIDs.count, rmqMessages.count);
  for (NSString *messageID in rmqMessages) {
    XCTAssertTrue([messageIDs containsObject:messageID]);
  }
}

/**
 *  Add s2d messages with different RMQ-ID's to the RMQ. Delete some of the
 *  messages stored, assuming we received a server ACK for them. The remaining
 *  messages should be fetched successfully.
 */
- (void)testDeletingS2dMessages {
  NSArray *addMessages = @[ @"message1", @"message2", @"message3", @"message4"];
  for (NSString *messageID in addMessages) {
    [self.rmqManager saveS2dMessageWithRmqId:messageID];
  }
  NSArray *removeMessages = @[ addMessages[1], addMessages[3] ];
  [self.rmqManager removeS2dIds:removeMessages];
  NSArray *remainingMessages = [self.rmqManager unackedS2dRmqIds];
  XCTAssertEqual(2, remainingMessages.count);
  XCTAssertTrue([remainingMessages containsObject:addMessages[0]]);
  XCTAssertTrue([remainingMessages containsObject:addMessages[2]]);
}

/**
 *  Test deleting a s2d message that is not in the persistent store. This shouldn't
 *  crash or alter the valid contents of the RMQ store.
 */
- (void)testDeletingInvalidS2dMessage {
  NSString *validMessageID = @"validMessage123";
  [self.rmqManager saveS2dMessageWithRmqId:validMessageID];
  NSString *invalidMessageID = @"invalidMessage123";
  [self.rmqManager removeS2dIds:@[invalidMessageID]];
  NSArray *remainingMessages = [self.rmqManager unackedS2dRmqIds];
  XCTAssertEqual(1, remainingMessages.count);
  XCTAssertEqualObjects(validMessageID, remainingMessages[0]);
}


/**
 *  Test that outgoing RMQ messages are correctly saved
 */
- (void)testOutgoingRmqWithValidMessages {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Scan outgoing messages is complete"];

  NSString *from = @"rmq-test";
  [self.rmqManager loadRmqId];
  GtalkDataMessageStanza *message1 = [self dataMessageWithMessageID:@"message1"
                                                               from:from
                                                               data:nil];
  // should successfully save the message to RMQ
  [self.rmqManager saveRmqMessage:message1 withCompletionHandler:^(BOOL success) {
    XCTAssertTrue(success);
    GtalkDataMessageStanza *message2 = [self dataMessageWithMessageID:@"message2"
                                                                 from:from
                                                                 data:nil];

    // should successfully save the second message to RMQ
    [self.rmqManager saveRmqMessage:message2 withCompletionHandler:^(BOOL success) {
      XCTAssertTrue(success);
      // message1 should have RMQ-ID = 2, message2 = 3
      [self.rmqManager scanWithRmqMessageHandler:^(NSDictionary *messages) {
        XCTAssertTrue([[messages allKeys] containsObject:@(2)]);
        XCTAssertTrue([[messages allKeys] containsObject:@(3)]);
        [expectation fulfill];
      }];

    }];
  }];
  [self waitForExpectationsWithTimeout:kAsyncTestTimout handler:nil];

}

/**
 *  Test that an outgoing message with different properties is correctly saved to the RMQ.
 */
- (void)testOutgoingDataMessageIsCorrectlySaved {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Messages are saved"];

  NSString *from = @"rmq-test";
  NSString *messageID = @"message123";
  NSString *to = @"to-senderID-123";
  int32_t ttl = 2400;
  NSString *registrationToken = @"registration-token";
  NSDictionary *data = @{
    @"hello" : @"world",
    @"count" : @"2",
  };

  [self.rmqManager loadRmqId];
  GtalkDataMessageStanza *message = [self dataMessageWithMessageID:messageID
                                                               from:from
                                                               data:data];
  [message setTo:to];
  [message setTtl:ttl];
  [message setRegId:registrationToken];

  // should successfully save the message to RMQ
  [self.rmqManager saveRmqMessage:message withCompletionHandler:^(BOOL success) {
    XCTAssertTrue(success);
    [self.rmqManager scanWithRmqMessageHandler:^(NSDictionary *messages) {
      for (NSString *rmqID in messages) {
        GtalkDataMessageStanza *stanza = (GtalkDataMessageStanza *)messages[rmqID];
        XCTAssertEqualObjects(from, stanza.from);
        XCTAssertEqualObjects(messageID, stanza.id_p);
        XCTAssertEqualObjects(to, stanza.to);
        XCTAssertEqualObjects(registrationToken, stanza.regId);
        XCTAssertEqual(ttl, stanza.ttl);
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        for (GtalkAppData *appData in stanza.appDataArray) {
          d[appData.key] = appData.value;
        }
        XCTAssertTrue([data isEqualToDictionary:d]);
      }
      [expectation fulfill];
    }];
  }];
  [self waitForExpectationsWithTimeout:kAsyncTestTimout handler:nil];
}

/**
 *  Test D2S messages being deleted from RMQ.
 */
- (void)testDeletingD2SMessagesFromRMQ {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Messages are deleted"];
  NSString *message1 = @"message123";
  NSString *ackedMessage = @"message234";
  NSString *from = @"from-rmq-test";
  GtalkDataMessageStanza *stanza1 = [self dataMessageWithMessageID:message1 from:from data:nil];
  GtalkDataMessageStanza *stanza2 = [self dataMessageWithMessageID:ackedMessage
                                                              from:from
                                                              data:nil];
  [self.rmqManager saveRmqMessage:stanza1 withCompletionHandler:^(BOOL success) {
    XCTAssertTrue(success);
    [self.rmqManager saveRmqMessage:stanza2 withCompletionHandler:^(BOOL success) {
      XCTAssertTrue(success);
      __block int64_t ackedMessageRmqID = -1;
       [self.rmqManager scanWithRmqMessageHandler:^(NSDictionary *messages) {
         for (NSString *rmqID in messages) {
           GtalkDataMessageStanza *stanza = (GtalkDataMessageStanza *)messages[rmqID];
                                 if ([stanza.id_p isEqualToString:ackedMessage]) {
                                   ackedMessageRmqID = rmqID.intValue;
                                   // should be a valid RMQ ID
                                   XCTAssertTrue(ackedMessageRmqID > 0);

                                   // delete the acked message
                                   NSString *rmqIDString = [NSString stringWithFormat:@"%lld", ackedMessageRmqID];
                                   [self.rmqManager removeRmqMessagesWithRmqIds:@[rmqIDString]];

                                   // should only have one message in the d2s RMQ
                                   [self.rmqManager scanWithRmqMessageHandler:^(NSDictionary *messages) {
                                     for (NSString *rmqID in messages) {
                                       GtalkDataMessageStanza *stanza2 = (GtalkDataMessageStanza *)messages[rmqID];
                                       // the acked message was queued later so should have
                                       // rmqID = ackedMessageRMQID - 1
                                       XCTAssertEqual(ackedMessageRmqID - 1, rmqID.intValue);
                                       XCTAssertEqual(message1, stanza2.id_p);
                                     }
                                     [expectation fulfill];
                                   }];
                                 }
         }
       }];

    }];
  }];
  [self waitForExpectationsWithTimeout:kAsyncTestTimout handler:nil];
}

/**
 *  Test saving a sync message to SYNC_RMQ.
 */
- (void)testSavingSyncMessage {
  NSString *rmqID = @"fake-rmq-id-1";
  int64_t expirationTime = FIRMessagingCurrentTimestampInSeconds() + 1;
  [self.rmqManager saveSyncMessageWithRmqID:rmqID
                             expirationTime:expirationTime
                               apnsReceived:YES
                                mcsReceived:NO];

  FIRMessagingPersistentSyncMessage *persistentMessage = [self.rmqManager querySyncMessageWithRmqID:rmqID];
  XCTAssertEqual(persistentMessage.expirationTime, expirationTime);
  XCTAssertTrue(persistentMessage.apnsReceived);
  XCTAssertFalse(persistentMessage.mcsReceived);
}

/**
 *  Test updating a sync message initially received via MCS, now being received via APNS.
 */
- (void)testUpdateMessageReceivedViaAPNS {
  NSString *rmqID = @"fake-rmq-id-1";
  int64_t expirationTime = FIRMessagingCurrentTimestampInSeconds() + 1;
  [self.rmqManager saveSyncMessageWithRmqID:rmqID
                             expirationTime:expirationTime
                               apnsReceived:NO
                                mcsReceived:YES];

  // Message was now received via APNS
  [self.rmqManager updateSyncMessageViaAPNSWithRmqID:rmqID];

  FIRMessagingPersistentSyncMessage *persistentMessage = [self.rmqManager querySyncMessageWithRmqID:rmqID];
  XCTAssertTrue(persistentMessage.apnsReceived);
  XCTAssertTrue(persistentMessage.mcsReceived);
}

/**
 *  Test updating a sync message initially received via APNS, now being received via MCS.
 */
- (void)testUpdateMessageReceivedViaMCS {
  NSString *rmqID = @"fake-rmq-id-1";
  int64_t expirationTime = FIRMessagingCurrentTimestampInSeconds() + 1;
  [self.rmqManager saveSyncMessageWithRmqID:rmqID
                             expirationTime:expirationTime
                               apnsReceived:YES
                                mcsReceived:NO];

  // Message was now received via APNS
  [self.rmqManager updateSyncMessageViaMCSWithRmqID:rmqID];

  FIRMessagingPersistentSyncMessage *persistentMessage = [self.rmqManager querySyncMessageWithRmqID:rmqID];
  XCTAssertTrue(persistentMessage.apnsReceived);
  XCTAssertTrue(persistentMessage.mcsReceived);
}

/**
 *  Test deleting sync messages from SYNC_RMQ.
 */
- (void)testDeleteSyncMessage {
  NSString *rmqID = @"fake-rmq-id-1";
  int64_t expirationTime = FIRMessagingCurrentTimestampInSeconds() + 1;
  [self.rmqManager saveSyncMessageWithRmqID:rmqID
                             expirationTime:expirationTime
                               apnsReceived:YES
                                mcsReceived:NO];
  XCTAssertNotNil([self.rmqManager querySyncMessageWithRmqID:rmqID]);

  // should successfully delete the message
  [self.rmqManager deleteSyncMessageWithRmqID:rmqID];
  XCTAssertNil([self.rmqManager querySyncMessageWithRmqID:rmqID]);
}

#pragma mark - Private Helpers

- (GtalkDataMessageStanza *)dataMessageWithMessageID:(NSString *)messageID
                                                from:(NSString *)from
                                                data:(NSDictionary *)data {
  GtalkDataMessageStanza *stanza = [[GtalkDataMessageStanza alloc] init];
  [stanza setId_p:messageID];
  [stanza setFrom:from];
  [stanza setCategory:kRmqDataMessageCategory];

  for (NSString *key in data) {
    NSString *val = data[key];
    GtalkAppData *appData = [[GtalkAppData alloc] init];
    [appData setKey:key];
    [appData setValue:val];
    [[stanza appDataArray] addObject:appData];
  }

  return stanza;
}

@end
