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

#import <XCTest/XCTest.h>

#import <nanopb/pb_decode.h>

#import "GDTCCTTests/Unit/Helpers/GDTCCTEventGenerator.h"

#import "GDTCCTLibrary/Private/GDTCCTNanopbHelpers.h"

@interface GDTCCTNanopbHelpersTest : XCTestCase

/** An event generator for testing. */
@property(nonatomic) GDTCCTEventGenerator *generator;

@end

@implementation GDTCCTNanopbHelpersTest

- (void)setUp {
  self.generator = [[GDTCCTEventGenerator alloc] initWithTarget:kGDTCORTargetCCT];
}

- (void)tearDown {
  [super tearDown];
  [self.generator deleteGeneratedFilesFromDisk];
}

/** Tests that the event generator is generating consistent events. */
- (void)testGeneratingFiveConsistentEvents {
  NSArray<GDTCOREvent *> *events1 = [self.generator generateTheFiveConsistentEvents];
  NSArray<GDTCOREvent *> *events2 = [self.generator generateTheFiveConsistentEvents];
  XCTAssertEqual(events1.count, events2.count);
  XCTAssertEqual(events1.count, 5);
  for (int i = 0; i < events1.count; i++) {
    GDTCOREvent *storedEvent1 = events1[i];
    GDTCOREvent *storedEvent2 = events2[i];
    NSData *storedEvent1Data = [NSData dataWithContentsOfURL:storedEvent1.fileURL];
    NSData *storedEvent2Data = [NSData dataWithContentsOfURL:storedEvent2.fileURL];
    XCTAssertEqualObjects(storedEvent1Data, storedEvent2Data);
  }
}

/** Tests constructing a batched log request. */
- (void)testConstructBatchedLogRequest {
  NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
  NSArray *testData = @[
    @"message-32347456.dat", @"message-35458880.dat", @"message-39882816.dat",
    @"message-40043840.dat", @"message-40657984.dat"
  ];
  NSMutableSet *storedEvents = [[NSMutableSet alloc] init];
  for (NSString *dataFile in testData) {
    NSData *messageData = [NSData dataWithContentsOfURL:[testBundle URLForResource:dataFile
                                                                     withExtension:nil]];
    XCTAssertNotNil(messageData);
    NSString *filePath = [NSString stringWithFormat:@"test-%lf.txt", CFAbsoluteTimeGetCurrent()];
    [messageData writeToFile:filePath atomically:YES];
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    XCTAssertNotNil(fileURL);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:filePath]);
    [storedEvents addObject:[_generator generateEvent:GDTCOREventQosDefault fileURL:fileURL]];
  }
  gdt_cct_BatchedLogRequest batch = gdt_cct_BatchedLogRequest_init_default;
  XCTAssertNoThrow((batch = GDTCCTConstructBatchedLogRequest(@{@"1018" : storedEvents})));
  pb_release(gdt_cct_BatchedLogRequest_fields, &batch);
}

/** Tests encoding a batched log request generates bytes equivalent to canonical protobuf. */
- (void)testEncodeBatchedLogRequest {
  NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
  NSArray *testData = @[
    @"message-32347456.dat", @"message-35458880.dat", @"message-39882816.dat",
    @"message-40043840.dat", @"message-40657984.dat"
  ];
  NSMutableSet *storedEvents = [[NSMutableSet alloc] init];
  for (NSString *dataFile in testData) {
    NSData *messageData = [NSData dataWithContentsOfURL:[testBundle URLForResource:dataFile
                                                                     withExtension:nil]];
    XCTAssertNotNil(messageData);
    NSString *filePath = [NSString stringWithFormat:@"test-%lf.txt", CFAbsoluteTimeGetCurrent()];
    [messageData writeToFile:filePath atomically:YES];
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    XCTAssertNotNil(fileURL);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:filePath]);
    [storedEvents addObject:[_generator generateEvent:GDTCOREventQosDefault fileURL:fileURL]];
  }
  gdt_cct_BatchedLogRequest batch = GDTCCTConstructBatchedLogRequest(@{@"1018" : storedEvents});
  NSData *encodedBatchLogRequest;
  XCTAssertNoThrow((encodedBatchLogRequest = GDTCCTEncodeBatchedLogRequest(&batch)));
  XCTAssertNotNil(encodedBatchLogRequest);
  pb_release(gdt_cct_BatchedLogRequest_fields, &batch);
}

/** Tests that the bytes generated are decodable. */
- (void)testBytesAreDecodable {
  NSArray<GDTCOREvent *> *storedEventsA = [self.generator generateTheFiveConsistentEvents];
  NSSet<GDTCOREvent *> *storedEvents = [NSSet setWithArray:storedEventsA];
  gdt_cct_BatchedLogRequest batch = GDTCCTConstructBatchedLogRequest(@{@"1018" : storedEvents});
  NSData *encodedBatchLogRequest = GDTCCTEncodeBatchedLogRequest(&batch);
  gdt_cct_BatchedLogRequest decodedBatch = gdt_cct_BatchedLogRequest_init_default;
  pb_istream_t istream =
      pb_istream_from_buffer([encodedBatchLogRequest bytes], [encodedBatchLogRequest length]);
  XCTAssertTrue(pb_decode(&istream, gdt_cct_BatchedLogRequest_fields, &decodedBatch));
  XCTAssert(decodedBatch.log_request_count == batch.log_request_count);
  XCTAssert(decodedBatch.log_request[0].log_event_count == batch.log_request[0].log_event_count);
  XCTAssert(decodedBatch.log_request[0].log_event[0].event_time_ms ==
            batch.log_request[0].log_event[0].event_time_ms);
  pb_release(gdt_cct_BatchedLogRequest_fields, &batch);
  pb_release(gdt_cct_BatchedLogRequest_fields, &decodedBatch);
}

/** Tests that creating a message above the apparent threshold of 16320 bytes works. */
- (void)testEncodingProtoAboveDefaultOSThreshold {
  NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
  NSArray *testData = @[
    @"message-32347456.dat", @"message-35458880.dat", @"message-39882816.dat",
    @"message-40043840.dat", @"message-40657984.dat"
  ];
  NSMutableSet *events = [[NSMutableSet alloc] init];
  // 250 messages results in a total size of 16337 which is > 16320, the apparent OS limit. Changing
  // to 249 would've caused test to pass previously.
  for (int i = 0; i < 250; i++) {
    NSString *dataFile = testData[arc4random_uniform((uint32_t)testData.count)];
    NSData *messageData = [NSData dataWithContentsOfURL:[testBundle URLForResource:dataFile
                                                                     withExtension:nil]];
    XCTAssertNotNil(messageData);
    NSString *filePath = [NSString stringWithFormat:@"test-%lf.txt", CFAbsoluteTimeGetCurrent()];
    [messageData writeToFile:filePath atomically:YES];
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    XCTAssertNotNil(fileURL);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:filePath]);
    [events addObject:[_generator generateEvent:GDTCOREventQosDefault fileURL:fileURL]];
  }
  gdt_cct_BatchedLogRequest batch = gdt_cct_BatchedLogRequest_init_default;
  XCTAssertNoThrow((batch = GDTCCTConstructBatchedLogRequest(@{@"1018" : events})));
  NSData *data = GDTCCTEncodeBatchedLogRequest(&batch);
  XCTAssertNotNil(data);
  const char *bytes = (const char *)[data bytes];
  BOOL allZeroes = YES;
  for (int i = 0; i < data.length; i++) {
    char aByte = bytes[i];
    if (aByte != '\0') {
      allZeroes = NO;
    }
  }
  XCTAssertFalse(allZeroes);
  pb_release(gdt_cct_BatchedLogRequest_fields, &batch);
}

@end
