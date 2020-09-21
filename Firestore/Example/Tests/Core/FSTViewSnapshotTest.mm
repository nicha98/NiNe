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

#include <vector>

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"

using firebase::firestore::core::DocumentViewChange;
using firebase::firestore::core::DocumentViewChangeSet;
using firebase::firestore::core::ViewSnapshot;
using firebase::firestore::model::DocumentKeySet;

NS_ASSUME_NONNULL_BEGIN

@interface FSTViewSnapshotTests : XCTestCase
@end

@implementation FSTViewSnapshotTests

- (void)testDocumentChangeConstructor {
  FSTDocument *doc = FSTTestDoc("a/b", 0, @{}, FSTDocumentStateSynced);
  DocumentViewChange::Type type = DocumentViewChange::Type::kModified;
  DocumentViewChange change{doc, type};
  XCTAssertEqual(change.document(), doc);
  XCTAssertEqual(change.type(), type);
}

- (void)testTrack {
  DocumentViewChangeSet set;

  FSTDocument *docAdded = FSTTestDoc("a/1", 0, @{}, FSTDocumentStateSynced);
  FSTDocument *docRemoved = FSTTestDoc("a/2", 0, @{}, FSTDocumentStateSynced);
  FSTDocument *docModified = FSTTestDoc("a/3", 0, @{}, FSTDocumentStateSynced);

  FSTDocument *docAddedThenModified = FSTTestDoc("b/1", 0, @{}, FSTDocumentStateSynced);
  FSTDocument *docAddedThenRemoved = FSTTestDoc("b/2", 0, @{}, FSTDocumentStateSynced);
  FSTDocument *docRemovedThenAdded = FSTTestDoc("b/3", 0, @{}, FSTDocumentStateSynced);
  FSTDocument *docModifiedThenRemoved = FSTTestDoc("b/4", 0, @{}, FSTDocumentStateSynced);
  FSTDocument *docModifiedThenModified = FSTTestDoc("b/5", 0, @{}, FSTDocumentStateSynced);

  set.AddChange(DocumentViewChange{docAdded, DocumentViewChange::Type::kAdded});
  set.AddChange(DocumentViewChange{docRemoved, DocumentViewChange::Type::kRemoved});
  set.AddChange(DocumentViewChange{docModified, DocumentViewChange::Type::kModified});
  set.AddChange(DocumentViewChange{docAddedThenModified, DocumentViewChange::Type::kAdded});
  set.AddChange(DocumentViewChange{docAddedThenModified, DocumentViewChange::Type::kModified});
  set.AddChange(DocumentViewChange{docAddedThenRemoved, DocumentViewChange::Type::kAdded});
  set.AddChange(DocumentViewChange{docAddedThenRemoved, DocumentViewChange::Type::kRemoved});
  set.AddChange(DocumentViewChange{docRemovedThenAdded, DocumentViewChange::Type::kRemoved});
  set.AddChange(DocumentViewChange{docRemovedThenAdded, DocumentViewChange::Type::kAdded});
  set.AddChange(DocumentViewChange{docModifiedThenRemoved, DocumentViewChange::Type::kModified});
  set.AddChange(DocumentViewChange{docModifiedThenRemoved, DocumentViewChange::Type::kRemoved});
  set.AddChange(DocumentViewChange{docModifiedThenModified, DocumentViewChange::Type::kModified});
  set.AddChange(DocumentViewChange{docModifiedThenModified, DocumentViewChange::Type::kModified});

  std::vector<DocumentViewChange> changes = set.GetChanges();
  XCTAssertEqual(changes.size(), 7);

  XCTAssertEqual(changes[0].document(), docAdded);
  XCTAssertEqual(changes[0].type(), DocumentViewChange::Type::kAdded);

  XCTAssertEqual(changes[1].document(), docRemoved);
  XCTAssertEqual(changes[1].type(), DocumentViewChange::Type::kRemoved);

  XCTAssertEqual(changes[2].document(), docModified);
  XCTAssertEqual(changes[2].type(), DocumentViewChange::Type::kModified);

  XCTAssertEqual(changes[3].document(), docAddedThenModified);
  XCTAssertEqual(changes[3].type(), DocumentViewChange::Type::kAdded);

  XCTAssertEqual(changes[4].document(), docRemovedThenAdded);
  XCTAssertEqual(changes[4].type(), DocumentViewChange::Type::kModified);

  XCTAssertEqual(changes[5].document(), docModifiedThenRemoved);
  XCTAssertEqual(changes[5].type(), DocumentViewChange::Type::kRemoved);

  XCTAssertEqual(changes[6].document(), docModifiedThenModified);
  XCTAssertEqual(changes[6].type(), DocumentViewChange::Type::kModified);
}

- (void)testViewSnapshotConstructor {
  FSTQuery *query = FSTTestQuery("a");
  FSTDocumentSet *documents = [FSTDocumentSet documentSetWithComparator:FSTDocumentComparatorByKey];
  FSTDocumentSet *oldDocuments = documents;
  documents =
      [documents documentSetByAddingDocument:FSTTestDoc("c/a", 1, @{}, FSTDocumentStateSynced)];
  std::vector<DocumentViewChange> documentChanges{DocumentViewChange{
      FSTTestDoc("c/a", 1, @{}, FSTDocumentStateSynced), DocumentViewChange::Type::kAdded}};

  BOOL fromCache = YES;
  DocumentKeySet mutatedKeys;
  BOOL syncStateChanged = YES;

  ViewSnapshot snapshot{query,
                        documents,
                        oldDocuments,
                        documentChanges,
                        mutatedKeys,
                        fromCache,
                        syncStateChanged,
                        /*excludes_metadata_changes=*/false};

  XCTAssertEqual(snapshot.query(), query);
  XCTAssertEqual(snapshot.documents(), documents);
  XCTAssertEqual(snapshot.old_documents(), oldDocuments);
  XCTAssertEqual(snapshot.document_changes(), documentChanges);
  XCTAssertEqual(snapshot.from_cache(), fromCache);
  XCTAssertEqual(snapshot.mutated_keys(), mutatedKeys);
  XCTAssertEqual(snapshot.sync_state_changed(), syncStateChanged);
}

@end

NS_ASSUME_NONNULL_END
