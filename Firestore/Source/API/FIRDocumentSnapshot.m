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

#import "FIRDocumentSnapshot.h"

#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRFieldPath+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRSnapshotMetadata+Internal.h"
#import "Firestore/Source/API/FIRSnapshotOptions+Internal.h"
#import "Firestore/Source/Model/FSTDatabaseID.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Model/FSTFieldValue.h"
#import "Firestore/Source/Model/FSTPath.h"
#import "Firestore/Source/Util/FSTAssert.h"
#import "Firestore/Source/Util/FSTUsageValidation.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRDocumentSnapshot ()

- (instancetype)initWithFirestore:(FIRFirestore *)firestore
                      documentKey:(FSTDocumentKey *)documentKey
                         document:(nullable FSTDocument *)document
                        fromCache:(BOOL)fromCache NS_DESIGNATED_INITIALIZER;

@property(nonatomic, strong, readonly) FIRFirestore *firestore;
@property(nonatomic, strong, readonly) FSTDocumentKey *internalKey;
@property(nonatomic, strong, readonly, nullable) FSTDocument *internalDocument;
@property(nonatomic, assign, readonly) BOOL fromCache;

@end

@implementation FIRDocumentSnapshot (Internal)

+ (instancetype)snapshotWithFirestore:(FIRFirestore *)firestore
                          documentKey:(FSTDocumentKey *)documentKey
                             document:(nullable FSTDocument *)document
                            fromCache:(BOOL)fromCache {
  return [[[self class] alloc] initWithFirestore:firestore
                                     documentKey:documentKey
                                        document:document
                                       fromCache:fromCache];
}

@end

@implementation FIRDocumentSnapshot {
  FIRSnapshotMetadata *_cachedMetadata;
}

@dynamic metadata;

- (instancetype)initWithFirestore:(FIRFirestore *)firestore
                      documentKey:(FSTDocumentKey *)documentKey
                         document:(nullable FSTDocument *)document
                        fromCache:(BOOL)fromCache {
  if (self = [super init]) {
    _firestore = firestore;
    _internalKey = documentKey;
    _internalDocument = document;
    _fromCache = fromCache;
  }
  return self;
}

// NSObject Methods
- (BOOL)isEqual:(nullable id)other {
  if (other == self) return YES;
  // self class could be FIRDocumentSnapshot or subtype. So we compare with base type explicitly.
  if (![other isKindOfClass:[FIRDocumentSnapshot class]]) return NO;

  return [self isEqualToSnapshot:other];
}

- (BOOL)isEqualToSnapshot:(nullable FIRDocumentSnapshot *)snapshot {
  if (self == snapshot) return YES;
  if (snapshot == nil) return NO;
  if (self.firestore != snapshot.firestore && ![self.firestore isEqual:snapshot.firestore])
    return NO;
  if (self.internalKey != snapshot.internalKey && ![self.internalKey isEqual:snapshot.internalKey])
    return NO;
  if (self.internalDocument != snapshot.internalDocument &&
      ![self.internalDocument isEqual:snapshot.internalDocument])
    return NO;
  if (self.fromCache != snapshot.fromCache) return NO;
  return YES;
}

- (NSUInteger)hash {
  NSUInteger hash = [self.firestore hash];
  hash = hash * 31u + [self.internalKey hash];
  hash = hash * 31u + [self.internalDocument hash];
  hash = hash * 31u + (self.fromCache ? 1 : 0);
  return hash;
}

@dynamic exists;

- (BOOL)exists {
  return _internalDocument != nil;
}

- (FIRDocumentReference *)reference {
  return [FIRDocumentReference referenceWithKey:self.internalKey firestore:self.firestore];
}

- (NSString *)documentID {
  return [self.internalKey.path lastSegment];
}

- (FIRSnapshotMetadata *)metadata {
  if (!_cachedMetadata) {
    _cachedMetadata = [FIRSnapshotMetadata
        snapshotMetadataWithPendingWrites:self.internalDocument.hasLocalMutations
                                fromCache:self.fromCache];
  }
  return _cachedMetadata;
}

- (nullable NSDictionary<NSString *, id> *)data {
  return [self dataWithOptions:[FIRSnapshotOptions defaultOptions]];
}

- (nullable NSDictionary<NSString *, id> *)dataWithOptions:(FIRSnapshotOptions *)options {
  return self.internalDocument == nil
             ? nil
             : [self convertedObject:[self.internalDocument data]
                             options:[FSTFieldValueOptions optionsForSnapshotOptions:options]];
}

- (nullable id)valueForField:(id)field {
  return [self valueForField:field options:[FIRSnapshotOptions defaultOptions]];
}

- (nullable id)valueForField:(id)field options:(FIRSnapshotOptions *)options {
  FIRFieldPath *fieldPath;

  if ([field isKindOfClass:[NSString class]]) {
    fieldPath = [FIRFieldPath pathWithDotSeparatedString:field];
  } else if ([field isKindOfClass:[FIRFieldPath class]]) {
    fieldPath = field;
  } else {
    FSTThrowInvalidArgument(@"Subscript key must be an NSString or FIRFieldPath.");
  }

  FSTFieldValue *fieldValue = [[self.internalDocument data] valueForPath:fieldPath.internalValue];
  return fieldValue == nil
             ? nil
             : [self convertedValue:fieldValue
                            options:[FSTFieldValueOptions optionsForSnapshotOptions:options]];
}

- (nullable id)objectForKeyedSubscript:(id)key {
  return [self valueForField:key];
}

- (id)convertedValue:(FSTFieldValue *)value options:(FSTFieldValueOptions *)options {
  if ([value isKindOfClass:[FSTObjectValue class]]) {
    return [self convertedObject:(FSTObjectValue *)value options:options];
  } else if ([value isKindOfClass:[FSTArrayValue class]]) {
    return [self convertedArray:(FSTArrayValue *)value options:options];
  } else if ([value isKindOfClass:[FSTReferenceValue class]]) {
    FSTReferenceValue *ref = (FSTReferenceValue *)value;
    FSTDatabaseID *refDatabase = ref.databaseID;
    FSTDatabaseID *database = self.firestore.databaseID;
    if (![refDatabase isEqualToDatabaseId:database]) {
      // TODO(b/32073923): Log this as a proper warning.
      NSLog(
          @"WARNING: Document %@ contains a document reference within a different database "
           "(%@/%@) which is not supported. It will be treated as a reference within the "
           "current database (%@/%@) instead.",
          self.reference.path, refDatabase.projectID, refDatabase.databaseID, database.projectID,
          database.databaseID);
    }
    return [FIRDocumentReference referenceWithKey:[ref valueWithOptions:options]
                                        firestore:self.firestore];
  } else {
    return [value valueWithOptions:options];
  }
}

- (NSDictionary<NSString *, id> *)convertedObject:(FSTObjectValue *)objectValue
                                          options:(FSTFieldValueOptions *)options {
  NSMutableDictionary *result = [NSMutableDictionary dictionary];
  [objectValue.internalValue
      enumerateKeysAndObjectsUsingBlock:^(NSString *key, FSTFieldValue *value, BOOL *stop) {
        result[key] = [self convertedValue:value options:options];
      }];
  return result;
}

- (NSArray<id> *)convertedArray:(FSTArrayValue *)arrayValue
                        options:(FSTFieldValueOptions *)options {
  NSArray<FSTFieldValue *> *internalValue = arrayValue.internalValue;
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:internalValue.count];
  [internalValue enumerateObjectsUsingBlock:^(id value, NSUInteger idx, BOOL *stop) {
    [result addObject:[self convertedValue:value options:options]];
  }];
  return result;
}

@end

@interface FIRQueryDocumentSnapshot ()

- (instancetype)initWithFirestore:(FIRFirestore *)firestore
                      documentKey:(FSTDocumentKey *)documentKey
                         document:(FSTDocument *)document
                        fromCache:(BOOL)fromCache NS_DESIGNATED_INITIALIZER;

@end

@implementation FIRQueryDocumentSnapshot

- (instancetype)initWithFirestore:(FIRFirestore *)firestore
                      documentKey:(FSTDocumentKey *)documentKey
                         document:(FSTDocument *)document
                        fromCache:(BOOL)fromCache {
  self = [super initWithFirestore:firestore
                      documentKey:documentKey
                         document:document
                        fromCache:fromCache];
  return self;
}

- (NSDictionary<NSString *, id> *)data {
  NSDictionary<NSString *, id> *data = [super data];
  FSTAssert(data, @"Document in a QueryDocumentSnapshot should exist");
  return data;
}

- (NSDictionary<NSString *, id> *)dataWithOptions:(FIRSnapshotOptions *)options {
  NSDictionary<NSString *, id> *data = [super dataWithOptions:options];
  FSTAssert(data, @"Document in a QueryDocumentSnapshot should exist");
  return data;
}

@end

NS_ASSUME_NONNULL_END
