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

#import "SEGDatabaseManager.h"

#import <OCMock/OCmock.h>

@interface SEGDatabaseManager (Test)
- (NSString *)pathForSegmentationDatabase;
@end

@interface SEGDatabaseManagerTests : XCTestCase {
  long _expectationTimeout;
}

@end

@implementation SEGDatabaseManagerTests

- (void)setUp {
  // Override the database path to create a test database.
  id databaseManagerMock = OCMClassMock([SEGDatabaseManager class]);
  OCMStub([databaseManagerMock pathForSegmentationDatabase])
      .andReturn([self pathForSegmentationTestDatabase]);

  // Expectation timeout for each test.
  _expectationTimeout = 2;
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each test method in the
  // class.
}

- (void)testDatabaseCreateOrOpen {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testDatabaseLoad"];
  // Initialize the database manager.
  SEGDatabaseManager *databaseManager = [[SEGDatabaseManager alloc] init];
  XCTAssertNotNil(databaseManager);
  // Load all data from the database.
  [databaseManager createOrOpenDatabaseWithCompletion:^(BOOL success, NSDictionary *result) {
    XCTAssertTrue(success);
    XCTAssertTrue(result.count == 0);
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:_expectationTimeout handler:nil];
}

- (void)testDatabaseInsertAndRead {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testDatabaseLoad"];
  // Initialize the database manager.
  SEGDatabaseManager *databaseManager = [[SEGDatabaseManager alloc] init];
  XCTAssertNotNil(databaseManager);
  // Load all data from the database.
  [databaseManager createOrOpenDatabaseWithCompletion:^(BOOL success, NSDictionary *result) {
    XCTAssertTrue(success);
    XCTAssertTrue(result.count == 0);

    // Insert data.
    [databaseManager
        insertMainTableApplicationNamed:@"firebase_test_app"
               customInstanceIdentifier:@"custom-123"
             firebaseInstanceIdentifier:@"firebase-123"
                      associationStatus:kSEGAssociationStatusPending
                      completionHandler:^(BOOL success, NSDictionary *result) {
                        XCTAssertTrue(success);
                        XCTAssertNil(result);

                        // Read data.
                        [databaseManager loadMainTableWithCompletion:^(BOOL success,
                                                                       NSDictionary *result) {
                          XCTAssertTrue(success);
                          XCTAssertEqual(result.count, 1);
                          NSDictionary *associations = [result objectForKey:@"firebase_test_app"];
                          XCTAssertNotNil(associations);
                          XCTAssertEqualObjects(
                              [associations objectForKey:kSEGCustomInstallationIdentifierKey],
                              @"custom-123");
                          XCTAssertEqualObjects(
                              [associations objectForKey:kSEGFirebaseInstallationIdentifierKey],
                              @"firebase-123");
                          XCTAssertEqualObjects(
                              [associations objectForKey:kSEGAssociationStatusKey],
                              kSEGAssociationStatusPending);
                          [expectation fulfill];
                        }];
                      }];
  }];
  [self waitForExpectationsWithTimeout:_expectationTimeout handler:nil];
}

#pragma mark Helpers
- (NSString *)pathForSegmentationTestDatabase {
  NSArray *dirPaths =
      NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
  NSString *appSupportPath = dirPaths.firstObject;
  NSString *databaseName =
      [NSString stringWithFormat:@"FirebaseSegmentation-test-%d.sqlite3", (arc4random() % 100)];
  NSArray *components = @[ appSupportPath, @"Google/FirebaseSegmentation", databaseName ];
  NSString *dbPath = [NSString pathWithComponents:components];
  NSLog(@"Created test database at: %@", dbPath);
  return dbPath;
}
@end
