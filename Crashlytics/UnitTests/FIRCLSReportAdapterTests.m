// Copyright 2020 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "FIRCLSRecordApplication.h"
#import "FIRCLSRecordHost.h"
#import "FIRCLSRecordIdentity.h"
#import "FIRCLSReportAdapter.h"
#import "FIRCLSReportAdapter_Private.h"

#import "FIRCLSFile.h"

#import <GoogleDataTransport/GDTCOREvent.h>
#import <GoogleDataTransport/GDTCORTargets.h>
#import <GoogleDataTransport/GDTCORTransport.h>

@interface FIRCLSReportAdapterTests : XCTestCase

@end

@implementation FIRCLSReportAdapterTests

/// Attempt sending a proto report to the reporting endpoint
- (void)testSendProtoReport {
  NSString *minCrash =
      [[FIRCLSReportAdapterTests resourcePath] stringByAppendingPathComponent:@"bare_min_crash"];

  FIRCLSReportAdapter *adapter =
      [[FIRCLSReportAdapter alloc] initWithPath:minCrash
                                    googleAppId:@"1:17586535263:ios:83778f4dc7e8a26ef794ea"
                                          orgId:@"5bec84f69ea6961d03000dc5"];

  GDTCORTransport *transport = [[GDTCORTransport alloc] initWithMappingID:@"1206"
                                                             transformers:nil
                                                                   target:kGDTCORTargetCSH];
  GDTCOREvent *event = [transport eventForTransport];
  event.dataObject = adapter;
  event.qosTier = GDTCOREventQoSFast;  // Bypass batching and have the event get sent out ASAP
  [transport sendDataEvent:event];
}

/// This test is useful for testing the binary output of the proto message
- (void)testProtoOutput {
  NSString *minCrash =
      [[FIRCLSReportAdapterTests resourcePath] stringByAppendingPathComponent:@"bare_min_crash"];

  FIRCLSReportAdapter *adapter =
      [[FIRCLSReportAdapter alloc] initWithPath:minCrash
                                    googleAppId:@"1:17586535263:ios:83778f4dc7e8a26ef794ea"
                                          orgId:@"5bec84f69ea6961d03000dc5"];

  NSData *data = adapter.transportBytes;

  NSError *error = nil;
  NSString *outputPath =
      [[FIRCLSReportAdapterTests resourcePath] stringByAppendingPathComponent:@"output.proto"];

  [data writeToFile:outputPath options:NSDataWritingAtomic error:&error];
  NSLog(@"Output path: %@", outputPath);
  if (error) {
    NSLog(@"Write returned error: %@", [error localizedDescription]);
  }

  // Put a breakpoint here to copy the file from the output path.
}

/// It is important that a crash does not occur when reading persisted crash files
/// Verify various invalid input cases.
- (void)testInvalidRecordCases {
  id adapter __unused = [[FIRCLSReportAdapter alloc] initWithPath:@"nonExistentPath"
                                                      googleAppId:@"appID"
                                                            orgId:@"orgID"];

  id application __unused = [[FIRCLSRecordApplication alloc] initWithDict:nil];
  id host __unused = [[FIRCLSRecordHost alloc] initWithDict:nil];
  id identity __unused = [[FIRCLSRecordIdentity alloc] initWithDict:nil];

  NSDictionary *emptyDict = [[NSDictionary alloc] init];
  id application2 __unused = [[FIRCLSRecordApplication alloc] initWithDict:emptyDict];
  id host2 __unused = [[FIRCLSRecordHost alloc] initWithDict:emptyDict];
  id identity2 __unused = [[FIRCLSRecordIdentity alloc] initWithDict:emptyDict];
}

- (void)testCorruptMetadataCLSRecordFile {
  id adapter __unused = [FIRCLSReportAdapterTests adapterForCorruptMetadata];
}

- (void)testRecordMetadataFile {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForValidMetadata];

  // Verify identity
  XCTAssertTrue([adapter.identity.build_version isEqualToString:@"4.0.0-beta.1"]);
  XCTAssertTrue(
      [adapter.identity.install_id isEqualToString:@"169DB25B-8F1D-4115-8364-3887DA9DE73C"]);

  // Verify host
  XCTAssertTrue([adapter.host.platform isEqualToString:@"ios"]);

  // Verify application
  XCTAssertTrue([adapter.application.build_version isEqualToString:@"1"]);
  XCTAssertTrue([adapter.application.display_version isEqualToString:@"1.0"]);
}

- (void)testReportProto {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForAllCrashes];
  google_crashlytics_Report report = [adapter protoReport];
  XCTAssertTrue([self isPBData:report.sdk_version equalToString:adapter.identity.build_version]);
  XCTAssertTrue([self isPBData:report.gmp_app_id equalToString:@"appID"]);
  XCTAssertEqual(report.platform, google_crashlytics_Platforms_IOS);
  XCTAssertTrue([self isPBData:report.installation_uuid equalToString:adapter.identity.install_id]);
  XCTAssertTrue([self isPBData:report.display_version
                 equalToString:adapter.application.display_version]);

  // Files payload
  XCTAssertTrue([self isPBData:report.apple_payload.org_id equalToString:@"orgID"]);
  XCTAssertEqual(report.apple_payload.files_count, 10);

  NSArray<NSString *> *clsRecords = adapter.clsRecordFilePaths;
  for (NSUInteger i = 0; i < clsRecords.count; i++) {
    XCTAssertTrue([self isPBData:report.apple_payload.files[i].filename
                   equalToString:clsRecords[i].lastPathComponent]);
    NSData *data = [NSData dataWithContentsOfFile:clsRecords[i] options:0 error:nil];
    XCTAssertTrue([self isPBData:report.apple_payload.files[i].contents equalToData:data]);
  }
}

// Helper functions
#pragma mark - Helper Functions

+ (FIRCLSReportAdapter *)adapterForAllCrashes {
  return [[FIRCLSReportAdapter alloc]
      initWithPath:[[FIRCLSReportAdapterTests resourcePath]
                       stringByAppendingPathComponent:@"ios_all_files_crash"]
       googleAppId:@"appID"
             orgId:@"orgID"];
}

+ (FIRCLSReportAdapter *)adapterForCorruptMetadata {
  return [[FIRCLSReportAdapter alloc]
      initWithPath:[[FIRCLSReportAdapterTests resourcePath]
                       stringByAppendingPathComponent:@"corrupt_metadata"]
       googleAppId:@"appID"
             orgId:@"orgID"];
}

+ (FIRCLSReportAdapter *)adapterForValidMetadata {
  return [[FIRCLSReportAdapter alloc]
      initWithPath:[[FIRCLSReportAdapterTests resourcePath]
                       stringByAppendingPathComponent:@"valid_metadata"]
       googleAppId:@"appID"
             orgId:@"orgID"];
}

+ (NSString *)resourcePath {
  return [[NSBundle bundleForClass:[self class]] resourcePath];
}

#pragma mark - Assertion Helpers for NanoPB Types

- (BOOL)isPBData:(pb_bytes_array_t *)pbString equalToString:(NSString *)str {
  pb_bytes_array_t *expected = FIRCLSEncodeString(str);
  return [self isPBArray:pbString equalToArray:expected];
}

- (BOOL)isPBData:(pb_bytes_array_t *)pbString equalToData:(NSData *)data {
  pb_bytes_array_t *expected = FIRCLSEncodeData(data);
  return [self isPBArray:pbString equalToArray:expected];
}

- (BOOL)isPBArray:(pb_bytes_array_t *)array equalToArray:(pb_bytes_array_t *)expected {
  // Treat the empty string as the same as a missing field
  if ((!array) && expected->size == 0) {
    return true;
  }

  if (array->size != expected->size) {
    return false;
  }

  for (int i = 0; i < array->size; i++) {
    if (expected->bytes[i] != array->bytes[i]) {
      return false;
    }
  }

  return true;
}

@end
