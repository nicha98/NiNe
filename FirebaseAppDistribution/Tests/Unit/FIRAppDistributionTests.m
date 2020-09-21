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

#import <FirebaseCore/FIRAppInternal.h>
#import "FIRAppDistribution.h"

@interface FIRAppDistributionSampleTests : XCTestCase

@property(nonatomic, strong) FIRAppDistribution *appDistribution;

@end

@interface FIRAppDistribution (PrivateUnitTesting)

- (instancetype)initWithApp:(FIRApp *)app appInfo:(NSDictionary *)appInfo;

@end

@implementation FIRAppDistributionSampleTests

- (void)setUp {
  [super setUp];

  NSDictionary<NSString *, NSString *> *dict = [[NSDictionary<NSString *, NSString *> alloc] init];
  self.appDistribution = [[FIRAppDistribution alloc] initWithApp:nil appInfo:dict];
}

- (void)testGetSingleton {
  XCTAssertNotNil(self.appDistribution);
}

@end
