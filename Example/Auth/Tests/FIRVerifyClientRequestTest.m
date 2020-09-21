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

#import "FIRAuthBackend.h"
#import "FIRVerifyClientRequest.h"
#import "FIRVerifyClientResponse.h"
#import "FIRFakeBackendRPCIssuer.h"

/** @var kFakeAppToken
    @brief The fake app token to use in the test request.
 */
static NSString *const kFakeAppToken = @"appToken";

/** @var kFakeAPIKey
    @brief The fake API key to use in the test request.
 */
static NSString *const kFakeAPIKey = @"APIKey";

/** @var kAppTokenKey
    @brief The key for the appToken request paramenter.
 */
static NSString *const kAPPTokenKey = @"appToken";

/** @var kIsSandboxKey
    @brief The key for the isSandbox request parameter
 */
static NSString *const kIsSandboxKey = @"isSandbox";

/** @var kExpectedAPIURL
    @brief The expected URL for the test calls.
 */
static NSString *const kExpectedAPIURL =
    @"https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyClient?key=APIKey";

/** @class FIRVerifyClientRequestTest
    @brief Tests for @c FIRVerifyClientRequests.
 */
@interface FIRVerifyClientRequestTest : XCTestCase
@end

@implementation FIRVerifyClientRequestTest {
  /** @var _RPCIssuer
      @brief This backend RPC issuer is used to fake network responses for each test in the suite.
          In the @c setUp method we initialize this and set @c FIRAuthBackend's RPC issuer to it.
   */
  FIRFakeBackendRPCIssuer *_RPCIssuer;
}

- (void)setUp {
    [super setUp];
    FIRFakeBackendRPCIssuer *RPCIssuer = [[FIRFakeBackendRPCIssuer alloc] init];
    [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:RPCIssuer];
    _RPCIssuer = RPCIssuer;
}

- (void)tearDown {
  _RPCIssuer = nil;
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:nil];
  [super tearDown];
}

/** @fn testVerifyClientRequest
    @brief Tests the verify client request.
 */
- (void)testVerifyClientRequest {
  FIRVerifyClientRequest *request =
      [[FIRVerifyClientRequest alloc] initWithAppToken:kFakeAppToken
                                             isSandbox:YES
                                                APIKey:kFakeAPIKey];
  [FIRAuthBackend verifyClient:request callback:^(FIRVerifyClientResponse *_Nullable response,
                                                  NSError *_Nullable error) {
  }];
  XCTAssertEqualObjects(_RPCIssuer.requestURL.absoluteString, kExpectedAPIURL);
  XCTAssertNotNil(_RPCIssuer.decodedRequest);
  XCTAssertEqualObjects(_RPCIssuer.decodedRequest[kAPPTokenKey], kFakeAppToken);
  XCTAssertTrue(_RPCIssuer.decodedRequest[kIsSandboxKey]);
}

@end
