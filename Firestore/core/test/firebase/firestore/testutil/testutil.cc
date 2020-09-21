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

#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

#include <algorithm>
#include <chrono>  // NOLINT(build/c++11)
#include <set>

#include "Firestore/core/include/firebase/firestore/geo_point.h"
#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/core/direction.h"
#include "Firestore/core/src/firebase/firestore/core/field_filter.h"
#include "Firestore/core/src/firebase/firestore/core/order_by.h"
#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/model/delete_mutation.h"
#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/document_set.h"
#include "Firestore/core/src/firebase/firestore/model/field_mask.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/field_transform.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/no_document.h"
#include "Firestore/core/src/firebase/firestore/model/patch_mutation.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/src/firebase/firestore/model/set_mutation.h"
#include "Firestore/core/src/firebase/firestore/model/transform_mutation.h"
#include "Firestore/core/src/firebase/firestore/model/transform_operation.h"
#include "Firestore/core/src/firebase/firestore/model/unknown_document.h"
#include "Firestore/core/src/firebase/firestore/model/verify_mutation.h"
#include "Firestore/core/src/firebase/firestore/nanopb/byte_string.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace testutil {

using model::Document;
using model::DocumentComparator;
using model::DocumentSet;
using model::DocumentState;
using model::FieldMask;
using model::FieldPath;
using model::FieldTransform;
using model::FieldValue;
using model::ObjectValue;
using model::Precondition;
using model::TransformOperation;
using nanopb::ByteString;

/**
 * A string sentinel that can be used with PatchMutation() to mark a field for
 * deletion.
 */
constexpr const char* kDeleteSentinel = "<DELETE>";

namespace details {

FieldValue BlobValue(std::initializer_list<uint8_t> octets) {
  nanopb::ByteString contents{octets};
  return FieldValue::FromBlob(std::move(contents));
}

}  // namespace details

ByteString Bytes(std::initializer_list<uint8_t> octets) {
  return ByteString(octets);
}

FieldValue Value(std::nullptr_t) {
  return FieldValue::Null();
}

FieldValue Value(double value) {
  return FieldValue::FromDouble(value);
}

FieldValue Value(Timestamp value) {
  return FieldValue::FromTimestamp(value);
}

FieldValue Value(const char* value) {
  return FieldValue::FromString(value);
}

FieldValue Value(const std::string& value) {
  return FieldValue::FromString(value);
}

FieldValue Value(const GeoPoint& value) {
  return FieldValue::FromGeoPoint(value);
}

FieldValue Value(const FieldValue& value) {
  return value;
}

FieldValue Value(const model::ObjectValue& value) {
  return value.AsFieldValue();
}

FieldValue Value(const FieldValue::Map& value) {
  return Value(model::ObjectValue::FromMap(value));
}

model::ObjectValue WrapObject(const model::FieldValue::Map& value) {
  return model::ObjectValue::FromMap(value);
}

model::DocumentKey Key(absl::string_view path) {
  return model::DocumentKey::FromPathString(std::string(path));
}

model::FieldPath Field(absl::string_view field) {
  return model::FieldPath::FromServerFormat(std::string(field));
}

model::DatabaseId DbId(std::string project) {
  size_t slash = project.find('/');
  if (slash == std::string::npos) {
    return model::DatabaseId(std::move(project), model::DatabaseId::kDefault);
  } else {
    std::string database_id = project.substr(slash + 1);
    project = project.substr(0, slash);
    return model::DatabaseId(std::move(project), std::move(database_id));
  }
}

FieldValue Ref(std::string project, absl::string_view path) {
  return FieldValue::FromReference(DbId(std::move(project)), Key(path));
}

model::ResourcePath Resource(absl::string_view field) {
  return model::ResourcePath::FromString(std::string(field));
}

model::SnapshotVersion Version(int64_t version) {
  namespace chr = std::chrono;
  auto timepoint =
      chr::time_point<chr::system_clock>(chr::microseconds(version));
  return model::SnapshotVersion{Timestamp::FromTimePoint(timepoint)};
}

model::Document Doc(absl::string_view key,
                    int64_t version,
                    const model::FieldValue::Map& data) {
  return Doc(key, version, data, DocumentState::kSynced);
}

model::Document Doc(absl::string_view key,
                    int64_t version,
                    const model::FieldValue::Map& data,
                    model::DocumentState document_state) {
  return model::Document(model::ObjectValue::FromMap(data), Key(key),
                         Version(version), document_state);
}

model::Document Doc(absl::string_view key,
                    int64_t version,
                    const FieldValue& data) {
  return Doc(key, version, data, DocumentState::kSynced);
}

model::Document Doc(absl::string_view key,
                    int64_t version,
                    const FieldValue& data,
                    model::DocumentState document_state) {
  return model::Document(model::ObjectValue(data), Key(key), Version(version),
                         document_state);
}

model::NoDocument DeletedDoc(absl::string_view key,
                             int64_t version,
                             bool has_committed_mutations) {
  return model::NoDocument(Key(key), Version(version), has_committed_mutations);
}

model::NoDocument DeletedDoc(model::DocumentKey key,
                             int64_t version,
                             bool has_committed_mutations) {
  return model::NoDocument(std::move(key), Version(version),
                           has_committed_mutations);
}

model::UnknownDocument UnknownDoc(absl::string_view key, int64_t version) {
  return model::UnknownDocument(Key(key), Version(version));
}

DocumentComparator DocComparator(absl::string_view field_path) {
  return Query("docs").AddingOrderBy(OrderBy(field_path)).Comparator();
}

DocumentSet DocSet(DocumentComparator comp, std::vector<Document> docs) {
  DocumentSet set{std::move(comp)};
  for (const Document& doc : docs) {
    set = set.insert(doc);
  }
  return set;
}

core::Filter::Operator OperatorFromString(absl::string_view s) {
  if (s == "<") {
    return core::Filter::Operator::LessThan;
  } else if (s == "<=") {
    return core::Filter::Operator::LessThanOrEqual;
  } else if (s == "==") {
    return core::Filter::Operator::Equal;
  } else if (s == ">") {
    return core::Filter::Operator::GreaterThan;
  } else if (s == ">=") {
    return core::Filter::Operator::GreaterThanOrEqual;
    // Both are accepted for compatibility with spec tests and existing
    // canonical ids.
  } else if (s == "array_contains" || s == "array-contains") {
    return core::Filter::Operator::ArrayContains;
  } else if (s == "in") {
    return core::Filter::Operator::In;
  } else if (s == "array-contains-any") {
    return core::Filter::Operator::ArrayContainsAny;
  } else {
    HARD_FAIL("Unknown operator: %s", s);
  }
}

core::FieldFilter Filter(absl::string_view key,
                         absl::string_view op,
                         FieldValue value) {
  return core::FieldFilter::Create(Field(key), OperatorFromString(op),
                                   std::move(value));
}

core::FieldFilter Filter(absl::string_view key,
                         absl::string_view op,
                         FieldValue::Map value) {
  return Filter(key, op, FieldValue::FromMap(std::move(value)));
}

core::FieldFilter Filter(absl::string_view key,
                         absl::string_view op,
                         std::nullptr_t) {
  return Filter(key, op, FieldValue::Null());
}

core::FieldFilter Filter(absl::string_view key,
                         absl::string_view op,
                         const char* value) {
  return Filter(key, op, FieldValue::FromString(value));
}

core::FieldFilter Filter(absl::string_view key,
                         absl::string_view op,
                         int value) {
  return Filter(key, op, FieldValue::FromInteger(value));
}

core::FieldFilter Filter(absl::string_view key,
                         absl::string_view op,
                         double value) {
  return Filter(key, op, FieldValue::FromDouble(value));
}

core::Direction Direction(absl::string_view direction) {
  if (direction == "asc") {
    return core::Direction::Ascending;
  } else if (direction == "desc") {
    return core::Direction::Descending;
  } else {
    HARD_FAIL("Unknown direction: %s (use \"asc\" or \"desc\")", direction);
  }
}

core::OrderBy OrderBy(absl::string_view key, absl::string_view direction) {
  return core::OrderBy(Field(key), Direction(direction));
}

core::OrderBy OrderBy(model::FieldPath field_path, core::Direction direction) {
  return core::OrderBy(std::move(field_path), direction);
}

core::Query Query(absl::string_view path) {
  return core::Query(Resource(path));
}

core::Query CollectionGroupQuery(absl::string_view collection_id) {
  return core::Query(model::ResourcePath::Empty(),
                     std::make_shared<const std::string>(collection_id));
}

model::SetMutation SetMutation(absl::string_view path,
                               const model::FieldValue::Map& values) {
  return model::SetMutation(Key(path), model::ObjectValue::FromMap(values),
                            model::Precondition::None());
}

model::PatchMutation PatchMutation(
    absl::string_view path,
    FieldValue::Map values,
    // TODO(rsgowman): Investigate changing update_mask to a set.
    std::vector<model::FieldPath> update_mask) {
  ObjectValue object_value = ObjectValue::Empty();
  std::set<FieldPath> field_mask_paths;

  for (const auto& kv : values) {
    FieldPath field_path = Field(kv.first);
    field_mask_paths.insert(field_path);

    const FieldValue& value = kv.second;
    if (!value.is_string() || value.string_value() != kDeleteSentinel) {
      object_value = object_value.Set(field_path, value);
    }
  }

  bool merge = !update_mask.empty();

  Precondition precondition =
      merge ? Precondition::None() : Precondition::Exists(true);
  FieldMask mask(
      merge ? std::set<FieldPath>(update_mask.begin(), update_mask.end())
            : field_mask_paths);

  return model::PatchMutation(Key(path), std::move(object_value),
                              std::move(mask), precondition);
}

model::TransformMutation TransformMutation(
    absl::string_view key,
    std::vector<std::pair<std::string, TransformOperation>> transforms) {
  std::vector<FieldTransform> field_transforms;

  for (auto&& pair : transforms) {
    auto path = Field(std::move(pair.first));
    TransformOperation&& op_ptr = std::move(pair.second);
    FieldTransform transform(std::move(path), std::move(op_ptr));
    field_transforms.push_back(std::move(transform));
  }

  return model::TransformMutation(Key(key), std::move(field_transforms));
}

std::pair<std::string, TransformOperation> Increment(std::string field,
                                                     FieldValue operand) {
  model::NumericIncrementTransform transform(std::move(operand));

  return std::pair<std::string, TransformOperation>(std::move(field),
                                                    std::move(transform));
}

std::pair<std::string, TransformOperation> ArrayUnion(
    std::string field, std::vector<FieldValue> operands) {
  model::ArrayTransform transform(TransformOperation::Type::ArrayUnion,
                                  std::move(operands));

  return std::pair<std::string, TransformOperation>(std::move(field),
                                                    std::move(transform));
}

model::DeleteMutation DeleteMutation(absl::string_view path) {
  return model::DeleteMutation(Key(path), Precondition::None());
}

model::VerifyMutation VerifyMutation(absl::string_view path, int64_t version) {
  return model::VerifyMutation(Key(path),
                               Precondition::UpdateTime(Version(version)));
}

model::MutationResult MutationResult(int64_t version) {
  return model::MutationResult(Version(version), absl::nullopt);
}

nanopb::ByteString ResumeToken(int64_t snapshot_version) {
  if (snapshot_version == 0) {
    // TODO(rsgowman): The other platforms return null here, though I'm not sure
    // if they ever rely on that. I suspect it'd be sufficient to return '{}'.
    // But for now, we'll just abort() until we hit a test case that actually
    // makes use of this.
    HARD_FAIL("Unsupported snapshot version %s", snapshot_version);
  }

  std::string snapshot_string =
      std::string("snapshot-") + std::to_string(snapshot_version);
  return nanopb::ByteString(snapshot_string);
}

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase
