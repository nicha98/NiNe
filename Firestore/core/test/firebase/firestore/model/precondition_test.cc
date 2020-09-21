/*
 * Copyright 2018 Google
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

#include "Firestore/core/src/firebase/firestore/model/precondition.h"

#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/no_document.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

TEST(Precondition, None) {
  const Precondition none = Precondition::None();
  EXPECT_EQ(Precondition::Type::None, none.type());
  EXPECT_TRUE(none.IsNone());
  EXPECT_EQ(SnapshotVersion::None(), none.update_time());

  const NoDocument deleted_doc = testutil::DeletedDoc("foo/doc", 1234567);
  const Document doc = testutil::Doc("bar/doc", 7654321);
  EXPECT_TRUE(none.IsValidFor(deleted_doc));
  EXPECT_TRUE(none.IsValidFor(doc));
}

TEST(Precondition, Exists) {
  const Precondition exists = Precondition::Exists(true);
  const Precondition no_exists = Precondition::Exists(false);
  EXPECT_EQ(Precondition::Type::Exists, exists.type());
  EXPECT_EQ(Precondition::Type::Exists, no_exists.type());
  EXPECT_FALSE(exists.IsNone());
  EXPECT_FALSE(no_exists.IsNone());
  EXPECT_EQ(SnapshotVersion::None(), exists.update_time());
  EXPECT_EQ(SnapshotVersion::None(), no_exists.update_time());

  const NoDocument deleted_doc = testutil::DeletedDoc("foo/doc", 1234567);
  const Document doc = testutil::Doc("bar/doc", 7654321);
  EXPECT_FALSE(exists.IsValidFor(deleted_doc));
  EXPECT_TRUE(exists.IsValidFor(doc));
  EXPECT_TRUE(no_exists.IsValidFor(deleted_doc));
  EXPECT_FALSE(no_exists.IsValidFor(doc));
}

TEST(Precondition, UpdateTime) {
  const Precondition update_time =
      Precondition::UpdateTime(testutil::Version(1234567));
  EXPECT_EQ(Precondition::Type::UpdateTime, update_time.type());
  EXPECT_FALSE(update_time.IsNone());
  EXPECT_EQ(testutil::Version(1234567), update_time.update_time());

  const NoDocument deleted_doc = testutil::DeletedDoc("foo/doc", 1234567);
  const Document not_match = testutil::Doc("bar/doc", 7654321);
  const Document match = testutil::Doc("baz/doc", 1234567);
  EXPECT_FALSE(update_time.IsValidFor(deleted_doc));
  EXPECT_FALSE(update_time.IsValidFor(not_match));
  EXPECT_TRUE(update_time.IsValidFor(match));
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
