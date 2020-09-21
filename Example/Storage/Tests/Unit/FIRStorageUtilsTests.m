// Copyright 2017 Google
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

#import "FIRStorageUtils.h"

#import "FIRStoragePath.h"

@interface FIRStorageUtilsTests : XCTestCase

@end

@implementation FIRStorageUtilsTests

- (void)testCommonExtensionToMIMEType {
  NSDictionary<NSString *, NSString *> *extensionToMIMEType = @{
    @"txt" : @"text/plain",
    @"png" : @"image/png",
    @"mp3" : @"audio/mpeg",
    @"mov" : @"video/quicktime",
    @"gif" : @"image/gif"
  };
  [extensionToMIMEType
      enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull extension, NSString *_Nonnull MIMEType,
                                          BOOL *_Nonnull stop) {
        XCTAssertEqualObjects([FIRStorageUtils MIMETypeForExtension:extension], MIMEType);
      }];
}

- (void)testParseGoodDataToDict {
  NSString *JSONString = @"{\"hello\" : \"world\"}";
  NSData *JSONData = [JSONString dataUsingEncoding:NSUTF8StringEncoding];
  NSDictionary *JSONDictionary = [NSDictionary frs_dictionaryFromJSONData:JSONData];
  NSDictionary *expectedDictionary = @{@"hello" : @"world"};
  XCTAssertEqualObjects(JSONDictionary, expectedDictionary);
}

- (void)testParseBadDataToDict {
  NSString *JSONString = @"Invalid JSON Object";
  NSData *JSONData = [JSONString dataUsingEncoding:NSUTF8StringEncoding];
  NSDictionary *JSONDictionary = [NSDictionary frs_dictionaryFromJSONData:JSONData];
  XCTAssertNil(JSONDictionary);
}

- (void)testParseNilToDict {
  NSDictionary *JSONDictionary = [NSDictionary frs_dictionaryFromJSONData:nil];
  XCTAssertNil(JSONDictionary);
}

- (void)testParseGoodDictToData {
  NSDictionary *JSONDictionary = @{@"hello" : @"world"};
  NSData *expectedData = [NSData frs_dataFromJSONDictionary:JSONDictionary];
  NSString *JSONString = [[NSString alloc] initWithData:expectedData encoding:NSUTF8StringEncoding];
  NSString *expectedString = @"{\"hello\":\"world\"}";
  XCTAssertEqualObjects(JSONString, expectedString);
}

- (void)testParseNilToData {
  NSData *JSONData = [NSData frs_dataFromJSONDictionary:nil];
  XCTAssertNil(JSONData);
}

- (void)testNilDictToQueryString {
  NSDictionary *params;
  NSString *queryString = [FIRStorageUtils queryStringForDictionary:params];
  XCTAssertEqualObjects(queryString, @"");
}

- (void)testEmptyDictToQueryString {
  NSDictionary *params = @{};
  NSString *queryString = [FIRStorageUtils queryStringForDictionary:params];
  XCTAssertEqualObjects(queryString, @"");
}

- (void)testSingleItemToQueryString {
  NSDictionary *params = @{@"foo" : @"bar"};
  NSString *queryString = [FIRStorageUtils queryStringForDictionary:params];
  XCTAssertEqualObjects(queryString, @"foo=bar");
}

- (void)testMultiItemDictToQueryString {
  NSDictionary *params = @{@"foo" : @"bar", @"baz" : @"qux"};
  NSString *queryString = [FIRStorageUtils queryStringForDictionary:params];
  XCTAssertEqualObjects(queryString, @"foo=bar&baz=qux");
}

- (void)testDefaultRequestForFullPath {
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:@"path/to/object"];
  NSURLRequest *request = [FIRStorageUtils defaultRequestForPath:path];
  XCTAssertEqualObjects([request.URL absoluteString],
                        @"https://firebasestorage.googleapis.com/v0/b/bucket/o/path%2Fto%2Fobject");
}

- (void)testDefaultRequestForNoPath {
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:nil];
  NSURLRequest *request = [FIRStorageUtils defaultRequestForPath:path];
  XCTAssertEqualObjects([request.URL absoluteString],
                        @"https://firebasestorage.googleapis.com/v0/b/bucket/o");
}

- (void)testEncodedURLForFullPath {
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:@"path/to/object"];
  NSString *encodedURL = [FIRStorageUtils encodedURLForPath:path];
  XCTAssertEqualObjects(encodedURL, @"/v0/b/bucket/o/path%2Fto%2Fobject");
}

- (void)testEncodedURLForNoPath {
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:nil];
  NSString *encodedURL = [FIRStorageUtils encodedURLForPath:path];
  XCTAssertEqualObjects(encodedURL, @"/v0/b/bucket/o");
}

@end
