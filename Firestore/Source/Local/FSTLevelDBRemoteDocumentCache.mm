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

#import "FSTLevelDBRemoteDocumentCache.h"

#include <leveldb/db.h>
#include <leveldb/write_batch.h>
#include <string>

#import "FSTAssert.h"
#import "FSTDocument.h"
#import "FSTDocumentDictionary.h"
#import "FSTDocumentKey.h"
#import "FSTDocumentSet.h"
#import "FSTLevelDBKey.h"
#import "FSTLocalSerializer.h"
#import "FSTWriteGroup.h"
#import "MaybeDocument.pbobjc.h"

#include "ordered_code.h"
#include "string_util.h"

NS_ASSUME_NONNULL_BEGIN

using Firestore::OrderedCode;
using leveldb::DB;
using leveldb::Iterator;
using leveldb::ReadOptions;
using leveldb::Slice;
using leveldb::Status;
using leveldb::WriteOptions;

@interface FSTLevelDBRemoteDocumentCache ()

@property(nonatomic, strong, readonly) FSTLocalSerializer *serializer;

@end

/**
 * Returns a standard set of read options.
 *
 * For now this is paranoid, but perhaps disable that in production builds.
 */
static ReadOptions StandardReadOptions() {
  ReadOptions options;
  options.verify_checksums = true;
  return options;
}

@implementation FSTLevelDBRemoteDocumentCache {
  // The DB pointer is shared with all cooperating LevelDB-related objects.
  std::shared_ptr<DB> _db;
}

- (instancetype)initWithDB:(std::shared_ptr<DB>)db serializer:(FSTLocalSerializer *)serializer {
  if (self = [super init]) {
    _db = db;
    _serializer = serializer;
  }
  return self;
}

- (void)shutdown {
  _db.reset();
}

- (void)addEntry:(FSTMaybeDocument *)document group:(FSTWriteGroup *)group {
  std::string key = [self remoteDocumentKey:document.key];
  [group setMessage:[self.serializer encodedMaybeDocument:document] forKey:key];
}

- (void)removeEntryForKey:(FSTDocumentKey *)documentKey group:(FSTWriteGroup *)group {
  std::string key = [self remoteDocumentKey:documentKey];
  [group removeMessageForKey:key];
}

- (nullable FSTMaybeDocument *)entryForKey:(FSTDocumentKey *)documentKey {
  std::string key = [FSTLevelDBRemoteDocumentKey keyWithDocumentKey:documentKey];
  std::string value;
  Status status = _db->Get(StandardReadOptions(), key, &value);
  if (status.IsNotFound()) {
    return nil;
  } else if (status.ok()) {
    return [self decodedMaybeDocument:value withKey:documentKey];
  } else {
    FSTFail(@"Fetch document for key (%@) failed with status: %s", documentKey,
            status.ToString().c_str());
  }
}

- (FSTDocumentDictionary *)documentsMatchingQuery:(FSTQuery *)query {
  // TODO(mikelehen): PERF: At least filter to the documents that match the path of the query.
  FSTDocumentDictionary *results = [FSTDocumentDictionary documentDictionary];

  std::string startKey = [FSTLevelDBRemoteDocumentKey keyPrefix];
  std::unique_ptr<Iterator> it(_db->NewIterator(StandardReadOptions()));
  it->Seek(startKey);

  FSTLevelDBRemoteDocumentKey *currentKey = [[FSTLevelDBRemoteDocumentKey alloc] init];
  for (; it->Valid() && [currentKey decodeKey:it->key()]; it->Next()) {
    FSTMaybeDocument *maybeDoc =
        [self decodedMaybeDocument:it->value() withKey:currentKey.documentKey];
    if ([maybeDoc isKindOfClass:[FSTDocument class]]) {
      results = [results dictionaryBySettingObject:(FSTDocument *)maybeDoc forKey:maybeDoc.key];
    }
  }

  Status status = it->status();
  if (!status.ok()) {
    FSTFail(@"Find documents matching query (%@) failed with status: %s", query,
            status.ToString().c_str());
  }

  return results;
}

- (std::string)remoteDocumentKey:(FSTDocumentKey *)key {
  return [FSTLevelDBRemoteDocumentKey keyWithDocumentKey:key];
}

- (FSTMaybeDocument *)decodedMaybeDocument:(Slice)slice withKey:(FSTDocumentKey *)documentKey {
  NSData *data =
      [[NSData alloc] initWithBytesNoCopy:(void *)slice.data() length:slice.size() freeWhenDone:NO];

  NSError *error;
  FSTPBMaybeDocument *proto = [FSTPBMaybeDocument parseFromData:data error:&error];
  if (!proto) {
    FSTFail(@"FSTPBMaybeDocument failed to parse: %@", error);
  }

  FSTMaybeDocument *maybeDocument = [self.serializer decodedMaybeDocument:proto];
  FSTAssert([maybeDocument.key isEqualToKey:documentKey],
            @"Read document has key (%@) instead of expected key (%@).", maybeDocument.key,
            documentKey);
  return maybeDocument;
}

@end

NS_ASSUME_NONNULL_END
