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

#import <FirebaseMessaging/FIRMessagingExtensionHelper.h>

#import "FirebaseMessaging/Sources/Protogen/nanopb/me.nanopb.h"

#import <GoogleDataTransport/GDTCOREvent.h>
#import <GoogleDataTransport/GDTCORTargets.h>
#import <GoogleDataTransport/GDTCORTransport.h>
#import "FirebaseMessaging/Sources/FIRMMessageCode.h"
#import "FirebaseMessaging/Sources/FIRMessagingConstants.h"
#import "FirebaseMessaging/Sources/FIRMessagingLogger.h"
#import "GoogleDataTransport/GDTCCTLibrary/Private/GDTCCTNanopbHelpers.h"
#import "GoogleUtilities/Environment/Private/GULAppEnvironmentUtil.h"

#import <nanopb/pb.h>
#import <nanopb/pb_decode.h>
#import <nanopb/pb_encode.h>

static NSString *const kPayloadOptionsName = @"fcm_options";
static NSString *const kPayloadOptionsImageURLName = @"image";

@interface FIRMessagingMetricsLog : NSObject <GDTCOREventDataObject>

@property(nonatomic) fm_MessagingClientEventExtension eventExtension;

@end

@implementation FIRMessagingMetricsLog

- (instancetype)initWithEventExtension:(fm_MessagingClientEventExtension)eventExtension {
  self = [super init];
  if (self) {
    _eventExtension = eventExtension;
  }
  return self;
}

- (NSData *)transportBytes {
  pb_ostream_t sizestream = PB_OSTREAM_SIZING;

  // Encode 1 time to determine the size.
  if (!pb_encode(&sizestream, fm_MessagingClientEventExtension_fields, &_eventExtension)) {
    FIRMessagingLoggerError(kFIRMessagingServiceExtensionTransportBytesError,
                            @"Error in nanopb encoding for size: %s", PB_GET_ERROR(&sizestream));
  }

  // Encode a 2nd time to actually get the bytes from it.
  size_t bufferSize = sizestream.bytes_written;
  CFMutableDataRef dataRef = CFDataCreateMutable(CFAllocatorGetDefault(), bufferSize);
  CFDataSetLength(dataRef, bufferSize);
  pb_ostream_t ostream = pb_ostream_from_buffer((void *)CFDataGetBytePtr(dataRef), bufferSize);
  if (!pb_encode(&ostream, fm_MessagingClientEventExtension_fields, &_eventExtension)) {
    FIRMessagingLoggerError(kFIRMessagingServiceExtensionTransportBytesError,
                            @"Error in nanopb encoding for bytes: %s", PB_GET_ERROR(&ostream));
  }
  CFDataSetLength(dataRef, ostream.bytes_written);

  return CFBridgingRelease(dataRef);
}

@end

@interface FIRMessagingExtensionHelper ()
@property(nonatomic, strong) void (^contentHandler)(UNNotificationContent *contentToDeliver);
@property(nonatomic, strong) UNMutableNotificationContent *bestAttemptContent;

@end

@implementation FIRMessagingExtensionHelper

- (void)populateNotificationContent:(UNMutableNotificationContent *)content
                 withContentHandler:(void (^)(UNNotificationContent *_Nonnull))contentHandler {
  self.contentHandler = [contentHandler copy];
  self.bestAttemptContent = content;

  // The `userInfo` property isn't available on newer versions of tvOS.
#if TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_WATCH
  NSString *currentImageURL = content.userInfo[kPayloadOptionsName][kPayloadOptionsImageURLName];
  if (!currentImageURL) {
    [self deliverNotification];
    return;
  }
  NSURL *attachmentURL = [NSURL URLWithString:currentImageURL];
  if (attachmentURL) {
    [self loadAttachmentForURL:attachmentURL
             completionHandler:^(UNNotificationAttachment *attachment) {
               if (attachment != nil) {
                 self.bestAttemptContent.attachments = @[ attachment ];
               }
               [self deliverNotification];
             }];
  } else {
    FIRMessagingLoggerError(kFIRMessagingServiceExtensionImageInvalidURL,
                            @"The Image URL provided is invalid %@.", currentImageURL);
    [self deliverNotification];
  }
#else
  [self deliverNotification];
#endif
}

#if TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_WATCH
- (void)loadAttachmentForURL:(NSURL *)attachmentURL
           completionHandler:(void (^)(UNNotificationAttachment *))completionHandler {
  __block UNNotificationAttachment *attachment = nil;

  NSURLSession *session = [NSURLSession
      sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
  [[session
      downloadTaskWithURL:attachmentURL
        completionHandler:^(NSURL *temporaryFileLocation, NSURLResponse *response, NSError *error) {
          if (error != nil) {
            FIRMessagingLoggerError(kFIRMessagingServiceExtensionImageNotDownloaded,
                                    @"Failed to download image given URL %@, error: %@\n",
                                    attachmentURL, error);
            completionHandler(attachment);
            return;
          }

          NSFileManager *fileManager = [NSFileManager defaultManager];
          NSString *fileExtension =
              [NSString stringWithFormat:@".%@", [response.suggestedFilename pathExtension]];
          NSURL *localURL = [NSURL
              fileURLWithPath:[temporaryFileLocation.path stringByAppendingString:fileExtension]];
          [fileManager moveItemAtURL:temporaryFileLocation toURL:localURL error:&error];
          if (error) {
            FIRMessagingLoggerError(
                kFIRMessagingServiceExtensionLocalFileNotCreated,
                @"Failed to move the image file to local location: %@, error: %@\n", localURL,
                error);
            completionHandler(attachment);
            return;
          }

          attachment = [UNNotificationAttachment attachmentWithIdentifier:@""
                                                                      URL:localURL
                                                                  options:nil
                                                                    error:&error];
          if (error) {
            FIRMessagingLoggerError(kFIRMessagingServiceExtensionImageNotAttached,
                                    @"Failed to create attachment with URL %@, error: %@\n",
                                    localURL, error);
            completionHandler(attachment);
            return;
          }
          completionHandler(attachment);
        }] resume];
}
#endif

- (void)deliverNotification {
  if (self.contentHandler) {
    self.contentHandler(self.bestAttemptContent);
  }
}

- (void)exportDeliveryMetricsToBigQueryWithMessageInfo:(NSDictionary *)info {
  GDTCORTransport *transport = [[GDTCORTransport alloc] initWithMappingID:@"1249"
                                                             transformers:nil
                                                                   target:kGDTCORTargetFLL];

  fm_MessagingClientEventExtension eventExtension = fm_MessagingClientEventExtension_init_default;

  fm_MessagingClientEvent foo = fm_MessagingClientEvent_init_default;
  foo.project_number = (int64_t)[info[kFIRMessagingSenderID] longLongValue];
  foo.message_id = GDTCCTEncodeString(info[kFIRMessagingMessageIDKey]);
  foo.instance_id = GDTCCTEncodeString(info[kFIRMessagingFID]);

  if ([info[@"aps"][kFIRMessagingMessageAPNSContentAvailableKey] intValue] == 1 &&
      ![GULAppEnvironmentUtil isAppExtension]) {
    foo.message_type = fm_MessagingClientEvent_MessageType_DATA_MESSAGE;
  } else {
    foo.message_type = fm_MessagingClientEvent_MessageType_DISPLAY_NOTIFICATION;
  }
  foo.sdk_platform = fm_MessagingClientEvent_SDKPlatform_IOS;

  NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;
  if ([GULAppEnvironmentUtil isAppExtension]) {
    foo.package_name =
        GDTCCTEncodeString([[self class] bundleIdentifierByRemovingLastPartFrom:bundleID]);
  } else {
    foo.package_name = GDTCCTEncodeString(bundleID);
  }
  foo.event = fm_MessagingClientEvent_Event_MESSAGE_DELIVERED;
  foo.analytics_label = GDTCCTEncodeString(info[kFIRMessagingAnalyticsMessageLabel]);
  foo.campaign_id = (int64_t)[info[kFIRMessagingAnalyticsComposerIdentifier] longLongValue];
  foo.composer_label = GDTCCTEncodeString(info[kFIRMessagingAnalyticsComposerLabel]);

  eventExtension.messaging_client_event = &foo;
  FIRMessagingMetricsLog *log =
      [[FIRMessagingMetricsLog alloc] initWithEventExtension:eventExtension];

  GDTCOREvent *event = [transport eventForTransport];
  event.dataObject = log;
  event.qosTier = GDTCOREventQoSFast;

  // Use this API for SDK service data events.
  [transport sendDataEvent:event];
}

+ (NSString *)bundleIdentifierByRemovingLastPartFrom:(NSString *)bundleIdentifier {
  NSString *bundleIDComponentsSeparator = @".";

  NSMutableArray<NSString *> *bundleIDComponents =
      [[bundleIdentifier componentsSeparatedByString:bundleIDComponentsSeparator] mutableCopy];
  [bundleIDComponents removeLastObject];

  return [bundleIDComponents componentsJoinedByString:bundleIDComponentsSeparator];
}

@end
