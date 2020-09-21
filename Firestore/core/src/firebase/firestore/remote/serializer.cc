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

#include "Firestore/core/src/firebase/firestore/remote/serializer.h"

#include <pb_decode.h>
#include <pb_encode.h>

#include <functional>
#include <map>
#include <string>
#include <utility>

#include "Firestore/Protos/nanopb/google/firestore/v1beta1/document.nanopb.h"
#include "Firestore/Protos/nanopb/google/firestore/v1beta1/firestore.nanopb.h"
#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/mutation.h"
#include "Firestore/core/src/firebase/firestore/model/no_document.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/nanopb/reader.h"
#include "Firestore/core/src/firebase/firestore/nanopb/writer.h"
#include "Firestore/core/src/firebase/firestore/timestamp_internal.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/string_format.h"
#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace remote {

using firebase::Timestamp;
using firebase::TimestampInternal;
using firebase::firestore::core::Query;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::DeleteMutation;
using firebase::firestore::model::Document;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::MaybeDocument;
using firebase::firestore::model::Mutation;
using firebase::firestore::model::NoDocument;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::model::PatchMutation;
using firebase::firestore::model::Precondition;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::model::SetMutation;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::nanopb::Reader;
using firebase::firestore::nanopb::Writer;
using firebase::firestore::util::Status;
using firebase::firestore::util::StringFormat;

pb_bytes_array_t* Serializer::EncodeString(const std::string& str) {
  auto size = static_cast<pb_size_t>(str.size());
  auto result =
      static_cast<pb_bytes_array_t*>(malloc(PB_BYTES_ARRAY_T_ALLOCSIZE(size)));
  result->size = size;
  memcpy(result->bytes, str.c_str(), size);
  return result;
}

std::string Serializer::DecodeString(const pb_bytes_array_t* str) {
  if (str == nullptr) return "";
  return std::string{reinterpret_cast<const char*>(str->bytes), str->size};
}

pb_bytes_array_t* Serializer::EncodeBytes(const std::vector<uint8_t>& bytes) {
  auto size = static_cast<pb_size_t>(bytes.size());
  auto result =
      static_cast<pb_bytes_array_t*>(malloc(PB_BYTES_ARRAY_T_ALLOCSIZE(size)));
  result->size = size;
  memcpy(result->bytes, bytes.data(), size);
  return result;
}

std::vector<uint8_t> Serializer::DecodeBytes(const pb_bytes_array_t* bytes) {
  if (bytes == nullptr) return {};
  return std::vector<uint8_t>(bytes->bytes, bytes->bytes + bytes->size);
}

namespace {

ObjectValue::Map DecodeMapValue(
    Reader* reader, const google_firestore_v1beta1_MapValue& map_value);

ObjectValue::Map::value_type DecodeFieldsEntry(
    Reader* reader,
    const google_firestore_v1beta1_Document_FieldsEntry& fields) {
  std::string key = Serializer::DecodeString(fields.key);
  FieldValue value = Serializer::DecodeFieldValue(reader, fields.value);

  if (key.empty()) {
    reader->Fail(
        "Invalid message: Empty key while decoding a Map field value.");
    return {};
  }

  return ObjectValue::Map::value_type{std::move(key), std::move(value)};
}

ObjectValue::Map DecodeFields(
    Reader* reader,
    size_t count,
    const google_firestore_v1beta1_Document_FieldsEntry* fields) {
  ObjectValue::Map result;
  for (size_t i = 0; i < count; i++) {
    result.emplace(DecodeFieldsEntry(reader, fields[i]));
  }

  return result;
}

google_firestore_v1beta1_MapValue EncodeMapValue(
    const ObjectValue::Map& object_value_map) {
  google_firestore_v1beta1_MapValue result{};

  size_t count = object_value_map.size();

  result.fields_count = count;
  result.fields =
      MakeArray<google_firestore_v1beta1_MapValue_FieldsEntry>(count);

  int i = 0;
  for (const auto& kv : object_value_map) {
    result.fields[i].key = Serializer::EncodeString(kv.first);
    result.fields[i].value = Serializer::EncodeFieldValue(kv.second);
    i++;
  }

  return result;
}

ObjectValue::Map DecodeMapValue(
    Reader* reader, const google_firestore_v1beta1_MapValue& map_value) {
  ObjectValue::Map result;

  for (size_t i = 0; i < map_value.fields_count; i++) {
    std::string key = Serializer::DecodeString(map_value.fields[i].key);
    FieldValue value =
        Serializer::DecodeFieldValue(reader, map_value.fields[i].value);

    result[key] = value;
  }

  return result;
}

/**
 * Creates the prefix for a fully qualified resource path, without a local path
 * on the end.
 */
ResourcePath EncodeDatabaseId(const DatabaseId& database_id) {
  return ResourcePath{"projects", database_id.project_id(), "databases",
                      database_id.database_id()};
}

/**
 * Encodes a databaseId and resource path into the following form:
 * /projects/$projectId/database/$databaseId/documents/$path
 */
std::string EncodeResourceName(const DatabaseId& database_id,
                               const ResourcePath& path) {
  return EncodeDatabaseId(database_id)
      .Append("documents")
      .Append(path)
      .CanonicalString();
}

/**
 * Validates that a path has a prefix that looks like a valid encoded
 * databaseId.
 */
bool IsValidResourceName(const ResourcePath& path) {
  // Resource names have at least 4 components (project ID, database ID)
  // and commonly the (root) resource type, e.g. documents
  return path.size() >= 4 && path[0] == "projects" && path[2] == "databases";
}

/**
 * Decodes a fully qualified resource name into a resource path and validates
 * that there is a project and database encoded in the path. There are no
 * guarantees that a local path is also encoded in this resource name.
 */
ResourcePath DecodeResourceName(Reader* reader, absl::string_view encoded) {
  ResourcePath resource = ResourcePath::FromString(encoded);
  if (!IsValidResourceName(resource)) {
    reader->Fail(StringFormat("Tried to deserialize an invalid key %s",
                              resource.CanonicalString()));
  }
  return resource;
}

/**
 * Decodes a fully qualified resource name into a resource path and validates
 * that there is a project and database encoded in the path along with a local
 * path.
 */
ResourcePath ExtractLocalPathFromResourceName(
    Reader* reader, const ResourcePath& resource_name) {
  if (resource_name.size() <= 4 || resource_name[4] != "documents") {
    reader->Fail(StringFormat("Tried to deserialize invalid key %s",
                              resource_name.CanonicalString()));
    return ResourcePath{};
  }
  return resource_name.PopFirst(5);
}

}  // namespace

Serializer::Serializer(
    const firebase::firestore::model::DatabaseId& database_id)
    : database_id_(database_id),
      database_name_(EncodeDatabaseId(database_id).CanonicalString()) {
}

void Serializer::FreeNanopbMessage(const pb_field_t fields[],
                                   void* dest_struct) {
  pb_release(fields, dest_struct);
}

google_firestore_v1beta1_Value Serializer::EncodeFieldValue(
    const FieldValue& field_value) {
  // TODO(rsgowman): some refactoring is in order... but will wait until after a
  // non-varint, non-fixed-size (i.e. string) type is present before doing so.
  google_firestore_v1beta1_Value result{};
  switch (field_value.type()) {
    case FieldValue::Type::Null:
      result.which_value_type = google_firestore_v1beta1_Value_null_value_tag;
      result.null_value = google_protobuf_NullValue_NULL_VALUE;
      break;

    case FieldValue::Type::Boolean:
      result.which_value_type =
          google_firestore_v1beta1_Value_boolean_value_tag;
      result.boolean_value = field_value.boolean_value();
      break;

    case FieldValue::Type::Integer:
      result.which_value_type =
          google_firestore_v1beta1_Value_integer_value_tag;
      result.integer_value = field_value.integer_value();
      break;

    case FieldValue::Type::String:
      result.which_value_type = google_firestore_v1beta1_Value_string_value_tag;
      result.string_value = EncodeString(field_value.string_value());
      break;

    case FieldValue::Type::Timestamp:
      result.which_value_type =
          google_firestore_v1beta1_Value_timestamp_value_tag;
      result.timestamp_value = EncodeTimestamp(field_value.timestamp_value());
      break;

    case FieldValue::Type::Object:
      result.which_value_type = google_firestore_v1beta1_Value_map_value_tag;
      result.map_value =
          EncodeMapValue(field_value.object_value().internal_value);
      break;

    default:
      // TODO(rsgowman): implement the other types
      abort();
  }
  return result;
}

FieldValue Serializer::DecodeFieldValue(
    Reader* reader, const google_firestore_v1beta1_Value& msg) {
  switch (msg.which_value_type) {
    case google_firestore_v1beta1_Value_null_value_tag:
      if (msg.null_value != google_protobuf_NullValue_NULL_VALUE) {
        reader->Fail("Input proto bytes cannot be parsed (invalid null value)");
      }
      return FieldValue::Null();

    case google_firestore_v1beta1_Value_boolean_value_tag:
      // TODO(rsgowman): Due to the nanopb implementation, msg.boolean_value
      // could be an integer other than 0 or 1, (such as 2). This leads to
      // undefined behaviour when it's read as a boolean. eg. on at least gcc,
      // the value is treated as both true *and* false. We need to decide if we
      // care enough to do anything about this.
      return FieldValue::FromBoolean(msg.boolean_value);

    case google_firestore_v1beta1_Value_integer_value_tag:
      return FieldValue::FromInteger(msg.integer_value);

    case google_firestore_v1beta1_Value_string_value_tag:
      return FieldValue::FromString(DecodeString(msg.string_value));

    case google_firestore_v1beta1_Value_timestamp_value_tag: {
      return FieldValue::FromTimestamp(
          DecodeTimestamp(reader, msg.timestamp_value));
    }

    case google_firestore_v1beta1_Value_map_value_tag: {
      return FieldValue::FromMap(DecodeMapValue(reader, msg.map_value));
    }

    case google_firestore_v1beta1_Value_double_value_tag:
    case google_firestore_v1beta1_Value_bytes_value_tag:
    case google_firestore_v1beta1_Value_reference_value_tag:
    case google_firestore_v1beta1_Value_geo_point_value_tag:
    case google_firestore_v1beta1_Value_array_value_tag:
      // TODO(b/74243929): Implement remaining types.
      HARD_FAIL("Unhandled message field number (tag): %i.",
                msg.which_value_type);

    default:
      reader->Fail(StringFormat("Invalid type while decoding FieldValue: %s",
                                msg.which_value_type));
      return FieldValue::Null();
  }

  UNREACHABLE();
}

std::string Serializer::EncodeKey(const DocumentKey& key) const {
  return EncodeResourceName(database_id_, key.path());
}

DocumentKey Serializer::DecodeKey(Reader* reader,
                                  absl::string_view name) const {
  ResourcePath resource = DecodeResourceName(reader, name);
  if (resource.size() < 5) {
    reader->Fail(
        StringFormat("Attempted to decode invalid key: '%s'. Should have at "
                     "least 5 segments.",
                     name));
  } else if (resource[1] != database_id_.project_id()) {
    reader->Fail(
        StringFormat("Tried to deserialize key from different project. "
                     "Expected: '%s'. Found: '%s'. (Full key: '%s')",
                     database_id_.project_id(), resource[1], name));
  } else if (resource[3] != database_id_.database_id()) {
    reader->Fail(
        StringFormat("Tried to deserialize key from different database. "
                     "Expected: '%s'. Found: '%s'. (Full key: '%s')",
                     database_id_.database_id(), resource[3], name));
  }

  ResourcePath local_path = ExtractLocalPathFromResourceName(reader, resource);

  if (!DocumentKey::IsDocumentKey(local_path)) {
    reader->Fail(StringFormat("Invalid document key path: %s",
                              local_path.CanonicalString()));
  }

  if (!reader->status().ok()) return DocumentKey();
  return DocumentKey{local_path};
}

google_firestore_v1beta1_Document Serializer::EncodeDocument(
    const DocumentKey& key, const ObjectValue& object_value) const {
  google_firestore_v1beta1_Document result{};

  result.name = EncodeString(EncodeKey(key));

  // Encode Document.fields (unless it's empty)
  size_t count = object_value.internal_value.size();
  result.fields_count = count;
  result.fields =
      MakeArray<google_firestore_v1beta1_Document_FieldsEntry>(count);
  int i = 0;
  for (const auto& kv : object_value.internal_value) {
    result.fields[i].key = EncodeString(kv.first);
    result.fields[i].value = EncodeFieldValue(kv.second);
    i++;
  }

  // Skip Document.create_time and Document.update_time, since they're
  // output-only fields.

  return result;
}

std::unique_ptr<model::MaybeDocument> Serializer::DecodeMaybeDocument(
    Reader* reader,
    const google_firestore_v1beta1_BatchGetDocumentsResponse& response) const {
  switch (response.which_result) {
    case google_firestore_v1beta1_BatchGetDocumentsResponse_found_tag:
      return DecodeFoundDocument(reader, response);
    case google_firestore_v1beta1_BatchGetDocumentsResponse_missing_tag:
      return DecodeMissingDocument(reader, response);
    default:
      reader->Fail(
          StringFormat("Unknown result case: %s", response.which_result));
      return nullptr;
  }

  UNREACHABLE();
}

std::unique_ptr<model::Document> Serializer::DecodeFoundDocument(
    Reader* reader,
    const google_firestore_v1beta1_BatchGetDocumentsResponse& response) const {
  HARD_ASSERT(response.which_result ==
                  google_firestore_v1beta1_BatchGetDocumentsResponse_found_tag,
              "Tried to deserialize a found document from a missing document.");

  DocumentKey key = DecodeKey(reader, DecodeString(response.found.name));
  ObjectValue::Map value =
      DecodeFields(reader, response.found.fields_count, response.found.fields);
  SnapshotVersion version =
      DecodeSnapshotVersion(reader, response.found.update_time);

  if (version == SnapshotVersion::None()) {
    reader->Fail("Got a document response with no snapshot version");
  }

  return absl::make_unique<Document>(FieldValue::FromMap(std::move(value)),
                                     std::move(key), std::move(version),
                                     /*has_local_modifications=*/false);
}

std::unique_ptr<model::NoDocument> Serializer::DecodeMissingDocument(
    Reader* reader,
    const google_firestore_v1beta1_BatchGetDocumentsResponse& response) const {
  HARD_ASSERT(
      response.which_result ==
          google_firestore_v1beta1_BatchGetDocumentsResponse_missing_tag,
      "Tried to deserialize a missing document from a found document.");

  DocumentKey key = DecodeKey(reader, DecodeString(response.missing));
  SnapshotVersion version = DecodeSnapshotVersion(reader, response.read_time);

  if (version == SnapshotVersion::None()) {
    reader->Fail("Got a no document response with no snapshot version");
    return nullptr;
  }

  return absl::make_unique<NoDocument>(std::move(key), std::move(version));
}

std::unique_ptr<Document> Serializer::DecodeDocument(
    Reader* reader, const google_firestore_v1beta1_Document& proto) const {
  ObjectValue::Map fields_internal =
      DecodeFields(reader, proto.fields_count, proto.fields);
  SnapshotVersion version = DecodeSnapshotVersion(reader, proto.update_time);

  return absl::make_unique<Document>(
      FieldValue::FromMap(std::move(fields_internal)),
      DecodeKey(reader, DecodeString(proto.name)), std::move(version),
      /*has_local_modifications=*/false);
}

google_firestore_v1beta1_Target_QueryTarget Serializer::EncodeQueryTarget(
    const core::Query& query) const {
  google_firestore_v1beta1_Target_QueryTarget result{};

  // Dissect the path into parent, collection_id and optional key filter.
  std::string collection_id;
  if (query.path().empty()) {
    result.parent = EncodeString(EncodeQueryPath(ResourcePath::Empty()));
  } else {
    ResourcePath path = query.path();
    HARD_ASSERT(path.size() % 2 != 0,
                "Document queries with filters are not supported.");
    result.parent = EncodeString(EncodeQueryPath(path.PopLast()));
    collection_id = path.last_segment();
  }

  result.which_query_type =
      google_firestore_v1beta1_Target_QueryTarget_structured_query_tag;

  if (!collection_id.empty()) {
    size_t count = 1;
    result.structured_query.from_count = count;
    result.structured_query.from =
        MakeArray<google_firestore_v1beta1_StructuredQuery_CollectionSelector>(
            count);
    result.structured_query.from[0].collection_id = EncodeString(collection_id);
  } else {
    result.structured_query.from_count = 0;
  }

  // Encode the filters.
  if (!query.filters().empty()) {
    // TODO(rsgowman): Implement
    abort();
  }

  // TODO(rsgowman): Encode the orders.
  // TODO(rsgowman): Encode the limit.
  // TODO(rsgowman): Encode the startat.
  // TODO(rsgowman): Encode the endat.

  return result;
}

google_firestore_v1beta1_Write Serializer::EncodeMutation(
    const Mutation& mutation) const {
  google_firestore_v1beta1_Write result{};

  switch (mutation.type()) {
    case Mutation::Type::kSet:
      result.which_operation = google_firestore_v1beta1_Write_update_tag;
      result.update = EncodeDocument(
          mutation.key(),
          static_cast<const SetMutation&>(mutation).value().object_value());
      break;

    case Mutation::Type::kPatch: {
      result.which_operation = google_firestore_v1beta1_Write_update_tag;
      const PatchMutation& patch_mutation =
          static_cast<const PatchMutation&>(mutation);
      result.update =
          EncodeDocument(mutation.key(), patch_mutation.value().object_value());
      result.update_mask = EncodeDocumentMask(patch_mutation.mask());
      break;
    }

    case Mutation::Type::kTransform:
      // TODO(rsgowman): implement.
      abort();

    case Mutation::Type::kDelete:
      result.which_operation = google_firestore_v1beta1_Write_delete_tag;
      result.delete_ = EncodeString(EncodeKey(mutation.key()));
      break;
  }

  if (!mutation.precondition().IsNone()) {
    result.current_document = EncodePrecondition(mutation.precondition());
  }

  return result;
}

std::unique_ptr<model::Mutation> Serializer::DecodeMutation(
    nanopb::Reader* reader, const google_firestore_v1beta1_Write& proto) const {
  Precondition precondition =
      DecodePrecondition(reader, proto.current_document);

  switch (proto.which_operation) {
    case google_firestore_v1beta1_Write_update_tag:
      if (proto.update_mask.field_paths_count > 0) {
        return absl::make_unique<PatchMutation>(
            DecodeKey(reader, DecodeString(proto.update.name)),
            FieldValue::FromMap(DecodeFields(reader, proto.update.fields_count,
                                             proto.update.fields)),
            DecodeDocumentMask(proto.update_mask), std::move(precondition));
      } else {
        return absl::make_unique<SetMutation>(
            DecodeKey(reader, DecodeString(proto.update.name)),
            FieldValue::FromMap(DecodeFields(reader, proto.update.fields_count,
                                             proto.update.fields)),
            std::move(precondition));
      }

    case google_firestore_v1beta1_Write_delete_tag:
      return absl::make_unique<DeleteMutation>(
          DecodeKey(reader, DecodeString(proto.delete_)),
          std::move(precondition));

    case google_firestore_v1beta1_Write_transform_tag:
      // TODO(rsgowman): implement.
      abort();

    default:
      reader->Fail(StringFormat("Unknown mutation operation: %s",
                                proto.which_operation));
      return nullptr;
  }

  UNREACHABLE();
}

/* static */
google_firestore_v1beta1_Precondition Serializer::EncodePrecondition(
    const Precondition& precondition) {
  google_firestore_v1beta1_Precondition result{};
  switch (precondition.type()) {
    case Precondition::Type::None:
      HARD_FAIL("Can't serialize an empty precondition");

    case Precondition::Type::UpdateTime:
      result.which_condition_type =
          google_firestore_v1beta1_Precondition_update_time_tag;
      result.update_time = EncodeVersion(precondition.update_time());
      return result;

    case Precondition::Type::Exists:
      result.which_condition_type =
          google_firestore_v1beta1_Precondition_exists_tag;
      result.exists = precondition.exists();
      return result;
  }

  UNREACHABLE();
}

/* static */
Precondition Serializer::DecodePrecondition(
    nanopb::Reader* reader,
    const google_firestore_v1beta1_Precondition& precondition) {
  switch (precondition.which_condition_type) {
    case google_firestore_v1beta1_Precondition_update_time_tag:
      // TODO(rsgowman): Implement
      abort();

    case google_firestore_v1beta1_Precondition_exists_tag:
      return Precondition::Exists(precondition.exists);

    case 0:
      // Precondition not set. (Unlike libprotobuf, nanopb does not generate a
      // constant for this, so we use '0' in the case statement.)
      return Precondition::None();

    default:
      reader->Fail(StringFormat("Unknown precondition (%s)",
                                precondition.which_condition_type));
      return Precondition::None();
  }

  UNREACHABLE();
}

/* static */
google_firestore_v1beta1_DocumentMask Serializer::EncodeDocumentMask(
    const model::FieldMask& mask) {
  google_firestore_v1beta1_DocumentMask result{};
  result.field_paths_count = mask.size();
  result.field_paths = MakeArray<pb_bytes_array_t*>(mask.size());
  int i = 0;
  for (const FieldPath& path : mask) {
    result.field_paths[i++] = EncodeString(path.CanonicalString());
  }
  return result;
}

/* static */
model::FieldMask Serializer::DecodeDocumentMask(
    const google_firestore_v1beta1_DocumentMask& proto) {
  int count = proto.field_paths_count;
  std::vector<FieldPath> paths;
  paths.reserve(count);
  for (int i = 0; i < count; i++) {
    paths.push_back(
        FieldPath::FromServerFormat(DecodeString(proto.field_paths[i])));
  }
  return model::FieldMask(paths);
}

ResourcePath DecodeQueryPath(Reader* reader, absl::string_view name) {
  ResourcePath resource = DecodeResourceName(reader, name);
  if (resource.size() == 4) {
    // Path missing the trailing documents path segment, indicating an empty
    // path.
    return ResourcePath::Empty();
  } else {
    return ExtractLocalPathFromResourceName(reader, resource);
  }
}

Query Serializer::DecodeQueryTarget(
    nanopb::Reader* reader,
    const google_firestore_v1beta1_Target_QueryTarget& proto) {
  // The QueryTarget oneof only has a single valid value.
  if (proto.which_query_type !=
      google_firestore_v1beta1_Target_QueryTarget_structured_query_tag) {
    reader->Fail(
        StringFormat("Unknown query_type: %s", proto.which_query_type));
    return Query::Invalid();
  }

  ResourcePath path = DecodeQueryPath(reader, DecodeString(proto.parent));
  size_t from_count = proto.structured_query.from_count;
  if (from_count > 0) {
    if (from_count != 1) {
      reader->Fail(
          "StructuredQuery.from with more than one collection is not "
          "supported.");
    }

    path =
        path.Append(DecodeString(proto.structured_query.from[0].collection_id));
  }

  // TODO(rsgowman): Dencode the filters.
  // TODO(rsgowman): Dencode the orders.
  // TODO(rsgowman): Dencode the limit.
  // TODO(rsgowman): Dencode the startat.
  // TODO(rsgowman): Dencode the endat.

  return Query(path, {});
}

std::string Serializer::EncodeQueryPath(const ResourcePath& path) const {
  if (path.empty()) {
    // If the path is empty, the backend requires we leave off the /documents at
    // the end.
    return database_name_;
  }
  return EncodeResourceName(database_id_, path);
}

google_protobuf_Timestamp Serializer::EncodeVersion(
    const model::SnapshotVersion& version) {
  return EncodeTimestamp(version.timestamp());
}

google_protobuf_Timestamp Serializer::EncodeTimestamp(
    const Timestamp& timestamp_value) {
  google_protobuf_Timestamp result{};
  result.seconds = timestamp_value.seconds();
  result.nanos = timestamp_value.nanoseconds();
  return result;
}

SnapshotVersion Serializer::DecodeSnapshotVersion(
    nanopb::Reader* reader, const google_protobuf_Timestamp& proto) {
  return SnapshotVersion{DecodeTimestamp(reader, proto)};
}

Timestamp Serializer::DecodeTimestamp(
    nanopb::Reader* reader, const google_protobuf_Timestamp& timestamp_proto) {
  // The Timestamp ctor will assert if we provide values outside the valid
  // range. However, since we're decoding, a single corrupt byte could cause
  // this to occur, so we'll verify the ranges before passing them in since we'd
  // rather not abort in these situations.
  if (timestamp_proto.seconds < TimestampInternal::Min().seconds()) {
    reader->Fail(
        "Invalid message: timestamp beyond the earliest supported date");
  } else if (TimestampInternal::Max().seconds() < timestamp_proto.seconds) {
    reader->Fail("Invalid message: timestamp behond the latest supported date");
  } else if (timestamp_proto.nanos < 0 || timestamp_proto.nanos > 999999999) {
    reader->Fail(
        "Invalid message: timestamp nanos must be between 0 and 999999999");
  }

  if (!reader->status().ok()) return Timestamp();
  return Timestamp{timestamp_proto.seconds, timestamp_proto.nanos};
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
