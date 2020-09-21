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

#import "Firestore/Example/Tests/Util/XCTestCase+Await.h"

#import <Foundation/Foundation.h>

// TODO(b/72864027): Reduce this to 10 seconds again once we've resolved issues with Query
// Conformance Tests flakiness or gotten answers from GRPC about reconnect delays.
static const double kExpectationWaitSeconds = 25.0;

@implementation XCTestCase (Await)

- (void)awaitExpectations {
  [self waitForExpectationsWithTimeout:kExpectationWaitSeconds
                               handler:^(NSError *_Nullable expectationError) {
                                 if (expectationError) {
                                   XCTFail(@"Error waiting for timeout: %@", expectationError);
                                 }
                               }];
}

- (double)defaultExpectationWaitSeconds {
  return kExpectationWaitSeconds;
}

- (FSTVoidErrorBlock)completionForExpectationWithName:(NSString *)expectationName {
  XCTestExpectation *expectation = [self expectationWithDescription:expectationName];
  return ^(NSError *error) {
    XCTAssertNil(error);
    [expectation fulfill];
  };
}

@end
