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

#import "FIRMessagingTopicOperation.h"

#import "FIRMessagingCheckinService.h"
#import "FIRMessagingDefines.h"
#import "FIRMessagingLogger.h"
#import "FIRMessagingUtilities.h"
#import "NSError+FIRMessaging.h"

#define DEBUG_LOG_SUBSCRIPTION_OPERATION_DURATIONS 0

static NSString *const kFIRMessagingSubscribeServerHost =
    @"https://iid.googleapis.com/iid/register";

NSString *FIRMessagingSubscriptionsServer() {
  static NSString *serverHost = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSDictionary *environment = [[NSProcessInfo processInfo] environment];
    NSString *customServerHost = environment[@"FCM_SERVER_ENDPOINT"];
    if (customServerHost.length) {
      serverHost = customServerHost;
    } else {
      serverHost = kFIRMessagingSubscribeServerHost;
    }
  });
  return serverHost;
}

@interface FIRMessagingTopicOperation () {
  BOOL _isFinished;
  BOOL _isExecuting;
}

@property(nonatomic, readwrite, copy) NSString *topic;
@property(nonatomic, readwrite, assign) FIRMessagingTopicAction action;
@property(nonatomic, readwrite, copy) NSString *token;
@property(nonatomic, readwrite, copy) NSDictionary *options;
@property(nonatomic, readwrite, strong) FIRMessagingCheckinService *checkinService;
@property(nonatomic, readwrite, copy) FIRMessagingTopicOperationCompletion completion;

@property(atomic, strong) NSURLSessionDataTask *dataTask;

@end

@implementation FIRMessagingTopicOperation

+ (NSURLSession *)sharedSession {
  static NSURLSession *subscriptionOperationSharedSession;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForResource = 60.0f;  // 1 minute
    subscriptionOperationSharedSession = [NSURLSession sessionWithConfiguration:config];
    subscriptionOperationSharedSession.sessionDescription = @"com.google.fcm.topics.session";
  });
  return subscriptionOperationSharedSession;
}

- (instancetype)initWithTopic:(NSString *)topic
                       action:(FIRMessagingTopicAction)action
                        token:(NSString *)token
                      options:(NSDictionary *)options
               checkinService:(FIRMessagingCheckinService *)checkinService
                   completion:(FIRMessagingTopicOperationCompletion)completion {
  if (self = [super init]) {
    _topic = topic;
    _action = action;
    _token = token;
    _checkinService = checkinService;
    _completion = completion;

    _isExecuting = NO;
    _isFinished = NO;
  }
  return self;
}

- (void)dealloc {
  _topic = nil;
  _token = nil;
  _checkinService = nil;
  _completion = nil;
}

- (BOOL)isAsynchronous {
  return YES;
}

- (BOOL)isExecuting {
  return _isExecuting;
}

- (void)setExecuting:(BOOL)executing {
  [self willChangeValueForKey:@"isExecuting"];
  _isExecuting = executing;
  [self didChangeValueForKey:@"isExecuting"];
}

- (BOOL)isFinished {
  return _isFinished;
}

- (void)setFinished:(BOOL)finished {
  [self willChangeValueForKey:@"isFinished"];
  _isFinished = finished;
  [self didChangeValueForKey:@"isFinished"];
}

- (void)start {
  if (self.isCancelled) {
    [self finishWithResult:FIRMessagingTopicOperationResultCancelled error:nil];
    return;
  }

  [self setExecuting:YES];

  [self performSubscriptionChange];
}

- (void)finishWithResult:(FIRMessagingTopicOperationResult)result error:(NSError *)error {
  // Add a check to prevent this finish from being called more than once.
  if (self.isFinished) {
    return;
  }
  self.dataTask = nil;
  if (self.completion) {
    self.completion(result, error);
  }

  [self setExecuting:NO];
  [self setFinished:YES];
}

- (void)cancel {
  [super cancel];
  [self.dataTask cancel];
  [self finishWithResult:FIRMessagingTopicOperationResultCancelled error:nil];
}

- (void)performSubscriptionChange {

  NSURL *url = [NSURL URLWithString:FIRMessagingSubscriptionsServer()];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
  NSString *appIdentifier = FIRMessagingAppIdentifier();
  NSString *deviceAuthID = self.checkinService.deviceAuthID;
  NSString *secretToken = self.checkinService.secretToken;
  NSString *authString = [NSString stringWithFormat:@"AidLogin %@:%@", deviceAuthID, secretToken];
  [request setValue:authString forHTTPHeaderField:@"Authorization"];
  [request setValue:appIdentifier forHTTPHeaderField:@"app"];
  [request setValue:self.checkinService.versionInfo forHTTPHeaderField:@"info"];

  NSMutableString *content = [NSMutableString stringWithFormat:
                              @"sender=%@&app=%@&device=%@&"
                              @"app_ver=%@&X-gcm.topic=%@&X-scope=%@",
                              self.token,
                              appIdentifier,
                              deviceAuthID,
                              FIRMessagingCurrentAppVersion(),
                              self.topic,
                              self.topic];

  if (self.action == FIRMessagingTopicActionUnsubscribe) {
    [content appendString:@"&delete=true"];
  }

  FIRMessagingLoggerInfo(kFIRMessagingMessageCodeTopicOption000, @"Topic subscription request: %@",
                         content);

  request.HTTPBody = [content dataUsingEncoding:NSUTF8StringEncoding];
  [request setHTTPMethod:@"POST"];

#if DEBUG_LOG_SUBSCRIPTION_OPERATION_DURATIONS
  NSDate *start = [NSDate date];
#endif

  FIRMessaging_WEAKIFY(self)
  void(^requestHandler)(NSData *, NSURLResponse *, NSError *) =
      ^(NSData *data, NSURLResponse *URLResponse, NSError *error) {
        FIRMessaging_STRONGIFY(self)
    if (error) {
      // Our operation could have been cancelled, which would result in our data task's error being
      // NSURLErrorCancelled
      if (error.code == NSURLErrorCancelled) {
        // We would only have been cancelled in the -cancel method, which will call finish for us
        // so just return and do nothing.
        return;
      }
      FIRMessagingLoggerDebug(kFIRMessagingMessageCodeTopicOption001,
                              @"Device registration HTTP fetch error. Error Code: %ld",
                              _FIRMessaging_L(error.code));
      [self finishWithResult:FIRMessagingTopicOperationResultError error:error];
      return;
    }
    NSString *response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (response.length == 0) {
      [self finishWithResult:FIRMessagingTopicOperationResultError
                       error:[NSError errorWithFCMErrorCode:kFIRMessagingErrorCodeUnknown]];
      return;
    }
    NSArray *parts = [response componentsSeparatedByString:@"="];
    _FIRMessagingDevAssert(parts.count, @"Invalid registration response");
    if (![parts[0] isEqualToString:@"token"] || parts.count <= 1) {
      FIRMessagingLoggerDebug(kFIRMessagingMessageCodeTopicOption002,
                              @"Invalid registration request, response");
      [self finishWithResult:FIRMessagingTopicOperationResultError
                       error:[NSError errorWithFCMErrorCode:kFIRMessagingErrorCodeUnknown]];
      return;
    }
#if DEBUG_LOG_SUBSCRIPTION_OPERATION_DURATIONS
    NSTimeInterval duration = -[start timeIntervalSinceNow];
    FIRMessagingLoggerDebug(@"%@ change took %.2fs", self.topic, duration);
#endif
    [self finishWithResult:FIRMessagingTopicOperationResultSucceeded error:nil];

  };

  NSURLSession *urlSession = [FIRMessagingTopicOperation sharedSession];

  self.dataTask = [urlSession dataTaskWithRequest:request completionHandler:requestHandler];
  NSString *description;
  if (_action == FIRMessagingTopicActionSubscribe) {
    description = [NSString stringWithFormat:@"com.google.fcm.topics.subscribe: %@", _topic];
  } else {
    description = [NSString stringWithFormat:@"com.google.fcm.topics.unsubscribe: %@", _topic];
  }
  self.dataTask.taskDescription = description;
  [self.dataTask resume];
}

@end
