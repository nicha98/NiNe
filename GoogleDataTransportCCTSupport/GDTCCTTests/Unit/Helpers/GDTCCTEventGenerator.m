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

#import "GDTCCTTests/Unit/Helpers/GDTCCTEventGenerator.h"

#import <GoogleDataTransport/GDTCORAssert.h>
#import <GoogleDataTransport/GDTCOREventDataObject.h>
#import <GoogleDataTransport/GDTCORTargets.h>

@interface GDTCCTEventGeneratorDataObject : NSObject <GDTCOREventDataObject>

@property(nullable, nonatomic) NSURL *dataFile;

@end

@implementation GDTCCTEventGeneratorDataObject

- (NSData *)transportBytes {
  return [NSData dataWithContentsOfURL:self.dataFile];
}

@end

@implementation GDTCCTEventGenerator

- (instancetype)initWithTarget:(GDTCORTarget)target {
  self = [super init];
  if (self) {
    _target = target;
    _allGeneratedEvents = [[NSMutableSet alloc] init];
  }
  return self;
}

- (void)deleteGeneratedFilesFromDisk {
  for (GDTCOREvent *event in self.allGeneratedEvents) {
    NSError *error;
    [[NSFileManager defaultManager] removeItemAtURL:event.fileURL error:&error];
    GDTCORAssert(error == nil, @"There was an error deleting a temporary event file.");
  }
}

- (GDTCOREvent *)generateEvent:(GDTCOREventQoS)qosTier {
  NSString *filePath = [NSString stringWithFormat:@"test-%lf.txt", CFAbsoluteTimeGetCurrent()];
  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"1018" target:_target];
  event.clockSnapshot = [GDTCORClock snapshot];
  event.qosTier = qosTier;
  [[NSFileManager defaultManager] createFileAtPath:filePath contents:[NSData data] attributes:nil];
  NSURL *fileURL = [NSURL fileURLWithPath:filePath];
  GDTCCTEventGeneratorDataObject *dataObject = [[GDTCCTEventGeneratorDataObject alloc] init];
  dataObject.dataFile = fileURL;
  event.dataObject = dataObject;
  [self.allGeneratedEvents addObject:event];
  return event;
}

- (GDTCOREvent *)generateEvent:(GDTCOREventQoS)qosTier fileURL:(NSURL *)fileURL {
  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"1018" target:_target];
  event.clockSnapshot = [GDTCORClock snapshot];
  event.qosTier = qosTier;
  GDTCCTEventGeneratorDataObject *dataObject = [[GDTCCTEventGeneratorDataObject alloc] init];
  dataObject.dataFile = fileURL;
  event.dataObject = dataObject;
  [self.allGeneratedEvents addObject:event];
  return event;
}

/** Generates a file URL that has the message resource data copied into it.
 *
 * @param messageResource The message resource name to copy.
 * @return A new file containing the data of the message resource.
 */
- (NSURL *)writeConsistentMessageToDisk:(NSString *)messageResource {
  NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
  NSString *filePath = [NSString stringWithFormat:@"test-%lf.txt", CFAbsoluteTimeGetCurrent()];
  NSAssert([[NSFileManager defaultManager] fileExistsAtPath:filePath] == NO,
           @"There should be no duplicate files generated.");
  NSData *messageData = [NSData dataWithContentsOfURL:[testBundle URLForResource:messageResource
                                                                   withExtension:nil]];
  [messageData writeToFile:filePath atomically:YES];
  return [NSURL fileURLWithPath:filePath];
}

- (NSArray<GDTCOREvent *> *)generateTheFiveConsistentEvents {
  NSMutableArray<GDTCOREvent *> *events = [[NSMutableArray alloc] init];
  {
    GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"1018" target:_target];
    event.clockSnapshot = [GDTCORClock snapshot];
    [event.clockSnapshot setValue:@(1111111111111) forKeyPath:@"timeMillis"];
    [event.clockSnapshot setValue:@(-25200) forKeyPath:@"timezoneOffsetSeconds"];
    [event.clockSnapshot setValue:@(1111111111111222) forKeyPath:@"kernelBootTime"];
    [event.clockSnapshot setValue:@(1235567890) forKeyPath:@"uptime"];
    event.qosTier = GDTCOREventQosDefault;
    event.customPrioritizationParams = @{@"customParam" : @1337};
    NSURL *messageDataURL = [self writeConsistentMessageToDisk:@"message-32347456.dat"];
    GDTCCTEventGeneratorDataObject *dataObject = [[GDTCCTEventGeneratorDataObject alloc] init];
    dataObject.dataFile = messageDataURL;
    event.dataObject = dataObject;
    [events addObject:event];
  }

  {
    GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"1018" target:_target];
    event.clockSnapshot = [GDTCORClock snapshot];
    [event.clockSnapshot setValue:@(1111111111111) forKeyPath:@"timeMillis"];
    [event.clockSnapshot setValue:@(-25200) forKeyPath:@"timezoneOffsetSeconds"];
    [event.clockSnapshot setValue:@(1111111111111333) forKeyPath:@"kernelBootTime"];
    [event.clockSnapshot setValue:@(1236567890) forKeyPath:@"uptime"];
    event.qosTier = GDTCOREventQoSWifiOnly;
    NSURL *messageDataURL = [self writeConsistentMessageToDisk:@"message-35458880.dat"];
    GDTCCTEventGeneratorDataObject *dataObject = [[GDTCCTEventGeneratorDataObject alloc] init];
    dataObject.dataFile = messageDataURL;
    event.dataObject = dataObject;
    [events addObject:event];
  }

  {
    GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"1018" target:_target];
    event.clockSnapshot = [GDTCORClock snapshot];
    [event.clockSnapshot setValue:@(1111111111111) forKeyPath:@"timeMillis"];
    [event.clockSnapshot setValue:@(-25200) forKeyPath:@"timezoneOffsetSeconds"];
    [event.clockSnapshot setValue:@(1111111111111444) forKeyPath:@"kernelBootTime"];
    [event.clockSnapshot setValue:@(1237567890) forKeyPath:@"uptime"];
    event.qosTier = GDTCOREventQosDefault;
    NSURL *messageDataURL = [self writeConsistentMessageToDisk:@"message-39882816.dat"];
    GDTCCTEventGeneratorDataObject *dataObject = [[GDTCCTEventGeneratorDataObject alloc] init];
    dataObject.dataFile = messageDataURL;
    event.dataObject = dataObject;
    [events addObject:event];
  }

  {
    GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"1018" target:_target];
    event.clockSnapshot = [GDTCORClock snapshot];
    [event.clockSnapshot setValue:@(1111111111111) forKeyPath:@"timeMillis"];
    [event.clockSnapshot setValue:@(-25200) forKeyPath:@"timezoneOffsetSeconds"];
    [event.clockSnapshot setValue:@(1111111111111555) forKeyPath:@"kernelBootTime"];
    [event.clockSnapshot setValue:@(1238567890) forKeyPath:@"uptime"];
    event.qosTier = GDTCOREventQosDefault;
    event.customPrioritizationParams = @{@"customParam1" : @"aValue1"};
    NSURL *messageDataURL = [self writeConsistentMessageToDisk:@"message-40043840.dat"];
    GDTCCTEventGeneratorDataObject *dataObject = [[GDTCCTEventGeneratorDataObject alloc] init];
    dataObject.dataFile = messageDataURL;
    event.dataObject = dataObject;
    [events addObject:event];
  }

  {
    GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"1018" target:_target];
    event.clockSnapshot = [GDTCORClock snapshot];
    [event.clockSnapshot setValue:@(1111111111111) forKeyPath:@"timeMillis"];
    [event.clockSnapshot setValue:@(-25200) forKeyPath:@"timezoneOffsetSeconds"];
    [event.clockSnapshot setValue:@(1111111111111666) forKeyPath:@"kernelBootTime"];
    [event.clockSnapshot setValue:@(1239567890) forKeyPath:@"uptime"];
    event.qosTier = GDTCOREventQoSTelemetry;
    event.customPrioritizationParams = @{@"customParam2" : @(34)};
    NSURL *messageDataURL = [self writeConsistentMessageToDisk:@"message-40657984.dat"];
    GDTCCTEventGeneratorDataObject *dataObject = [[GDTCCTEventGeneratorDataObject alloc] init];
    dataObject.dataFile = messageDataURL;
    event.dataObject = dataObject;
    [events addObject:event];
  }
  return events;
}

@end
