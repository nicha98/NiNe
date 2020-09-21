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

#import <XCTest/XCTest.h>

#import "SEGContentManager.h"
#import "SEGDatabaseManager.h"
#import "SEGNetworkManager.h"

#import <FirebaseCore/FirebaseCore.h>
#import <FirebaseInstallations/FirebaseInstallations.h>
#import <OCMock/OCMock.h>
#import "FIRInstallationsIDController.h"

@interface SEGContentManager (ForTest)
- (instancetype)initWithDatabaseManager:databaseManager networkManager:networkManager;
@end

@interface FIRInstallations (Tests)
@property(nonatomic, readwrite, strong) FIROptions *appOptions;
@property(nonatomic, readwrite, strong) NSString *appName;

- (instancetype)initWithAppOptions:(FIROptions *)appOptions
                           appName:(NSString *)appName
         installationsIDController:(FIRInstallationsIDController *)installationsIDController
                 prefetchAuthToken:(BOOL)prefetchAuthToken;
@end

@interface FIRInstallationsAuthTokenResult (ForTest)
- (instancetype)initWithToken:(NSString *)token expirationDate:(NSDate *)expirationTime;
@end

@interface SEGContentManagerTests : XCTestCase
@property(nonatomic) SEGContentManager *contentManager;
@property(nonatomic) id instanceIDMock;
@property(nonatomic) id networkManagerMock;
@property(nonatomic) FIRInstallations *installationsMock;
@property(nonatomic) id mockIDController;
@property(nonatomic) FIROptions *appOptions;

@end

@implementation SEGContentManagerTests

- (void)setUp {
  // Setup FIRApp.
  XCTAssertNoThrow([FIRApp configureWithOptions:[self FIRAppOptions]]);
  // TODO (mandard): Investigate replacing the partial mock with a class mock.
  //  self.instanceIDMock = OCMPartialMock([FIRInstanceID instanceIDForTests]);
  //  FIRInstanceIDResult *result = [[FIRInstanceIDResult alloc] init];
  //  result.instanceID = @"test-instance-id";
  //  result.token = @"test-instance-id-token";
  //  OCMStub([self.instanceIDMock
  //      instanceIDWithHandler:([OCMArg invokeBlockWithArgs:result, [NSNull null], nil])]);

  // Installations Mock
  NSString *FID = @"fid-is-better-than-iid";
  FIRInstallationsAuthTokenResult *FISToken =
      [[FIRInstallationsAuthTokenResult alloc] initWithToken:@"fake-fis-token" expirationDate:nil];
  self.installationsMock = OCMPartialMock([FIRInstallations installations]);
  OCMStub([self.installationsMock
      installationIDWithCompletion:([OCMArg invokeBlockWithArgs:FID, [NSNull null], nil])]);
  OCMStub([self.installationsMock
      authTokenWithCompletion:([OCMArg invokeBlockWithArgs:FISToken, [NSNull null], nil])]);

  // Mock the network manager.
  FIROptions *options = [[FIROptions alloc] init];
  options.projectID = @"test-project-id";
  options.APIKey = @"test-api-key";
  self.networkManagerMock = OCMClassMock([SEGNetworkManager class]);
  OCMStub([self.networkManagerMock
      makeAssociationRequestToBackendWithData:[OCMArg any]
                                        token:[OCMArg any]
                                   completion:([OCMArg
                                                  invokeBlockWithArgs:@YES, [NSNull null], nil])]);

  // Initialize the content manager.
  self.contentManager =
      [[SEGContentManager alloc] initWithDatabaseManager:[SEGDatabaseManager sharedInstance]
                                          networkManager:self.networkManagerMock];
}

- (void)tearDown {
  [self.networkManagerMock stopMocking];
  self.networkManagerMock = nil;
  [self.instanceIDMock stopMocking];
  self.instanceIDMock = nil;
  self.contentManager = nil;
  self.installationsMock = nil;
  self.mockIDController = nil;
}

// Associate a fake custom installation id and fake firebase installation id.
// TODO(mandard): check for result and add more tests.
- (void)testAssociateCustomInstallationIdentifierSuccessfully {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"associateCustomInstallation for contentmanager"];
  [_contentManager
      associateCustomInstallationIdentiferNamed:@"my-custom-id"
                                    firebaseApp:@"my-firebase-app-id"
                                     completion:^(BOOL success, NSDictionary *result) {
                                       XCTAssertTrue(success,
                                                     @"Could not associate custom installation ID");
                                       [expectation fulfill];
                                     }];
  [self waitForExpectationsWithTimeout:10 handler:nil];
}

#pragma mark private

- (FIROptions *)FIRAppOptions {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:@"1:123:ios:123abc"
                                                    GCMSenderID:@"correct_gcm_sender_id"];
  options.APIKey = @"AIzaSyabcdefghijklmnopqrstuvwxyz1234567";
  options.projectID = @"abc-xyz-123";
  return options;
}
@end
