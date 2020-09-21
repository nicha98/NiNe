// Copyright 2019 Google
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

#import "FIRCLSMockReportManager.h"

#import "FIRCLSApplicationIdentifierModel.h"
#import "FIRCLSContext.h"
#import "FIRCLSMockNetworkClient.h"
#import "FIRCLSMockReportUploader.h"

@interface FIRCLSMockReportManager () {
  FIRCLSMockReportUploader *_uploader;
}

// Made this a property so we can override this with mocked values
@property(nonatomic, strong) FIRCLSApplicationIdentifierModel *appIDModel;

@end

@implementation FIRCLSMockReportManager

// these have to be synthesized, to override the pre-existing method
@synthesize bundleIdentifier;

- (instancetype)initWithFileManager:(FIRCLSFileManager *)fileManager
                         instanceID:(FIRInstanceID *)instanceID
                          analytics:(id<FIRAnalyticsInterop>)analytics
                        googleAppID:(nonnull NSString *)googleAppID
                        dataArbiter:(FIRCLSDataCollectionArbiter *)dataArbiter
                         appIDModel:(FIRCLSApplicationIdentifierModel *)appIDModel {
  self = [super initWithFileManager:fileManager
                         instanceID:instanceID
                          analytics:analytics
                        googleAppID:googleAppID
                        dataArbiter:dataArbiter];
  if (!self) {
    return nil;
  }

  _appIDModel = appIDModel;

  _uploader = [[FIRCLSMockReportUploader alloc] initWithQueue:self.operationQueue
                                                     delegate:self
                                                   dataSource:self
                                                       client:self.networkClient
                                                  fileManager:fileManager
                                                    analytics:analytics];

  return self;
}

- (FIRCLSNetworkClient *)clientWithOperationQueue:(NSOperationQueue *)queue {
  return [[FIRCLSMockNetworkClient alloc] initWithQueue:queue
                                            fileManager:self.fileManager
                                               delegate:(id<FIRCLSNetworkClientDelegate>)self];
}

- (FIRCLSReportUploader *)uploader {
  return _uploader;
}

- (BOOL)startCrashReporterWithProfilingMark:(FIRCLSProfileMark)mark
                                     report:(FIRCLSInternalReport *)report {
  NSLog(@"Crash Reporting system disabled for testing");

  return YES;
}

- (BOOL)installCrashReportingHandlers:(FIRCLSContextInitData *)initData {
  return YES;
  // This actually installs crash handlers, there is no need to do that during testing.
}

- (void)crashReportingSetupCompleted {
  // This stuff does operations on the main thread, which we don't want during tests.
}

@end
