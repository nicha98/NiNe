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

// Generated by the protocol buffer compiler.  DO NOT EDIT!
// source: google/type/latlng.proto

#include "google/type/latlng.pb.h"

#include <algorithm>

#include <google/protobuf/stubs/common.h>
#include <google/protobuf/io/coded_stream.h>
#include <google/protobuf/extension_set.h>
#include <google/protobuf/wire_format_lite.h>
#include <google/protobuf/descriptor.h>
#include <google/protobuf/generated_message_reflection.h>
#include <google/protobuf/reflection_ops.h>
#include <google/protobuf/wire_format.h>
// @@protoc_insertion_point(includes)
#include <google/protobuf/port_def.inc>
namespace google {
namespace type {
class LatLngDefaultTypeInternal {
 public:
  ::PROTOBUF_NAMESPACE_ID::internal::ExplicitlyConstructed<LatLng> _instance;
} _LatLng_default_instance_;
}  // namespace type
}  // namespace google
static void InitDefaultsscc_info_LatLng_google_2ftype_2flatlng_2eproto() {
  GOOGLE_PROTOBUF_VERIFY_VERSION;

  {
    void* ptr = &::google::type::_LatLng_default_instance_;
    new (ptr) ::google::type::LatLng();
    ::PROTOBUF_NAMESPACE_ID::internal::OnShutdownDestroyMessage(ptr);
  }
  ::google::type::LatLng::InitAsDefaultInstance();
}

::PROTOBUF_NAMESPACE_ID::internal::SCCInfo<0> scc_info_LatLng_google_2ftype_2flatlng_2eproto =
    {{ATOMIC_VAR_INIT(::PROTOBUF_NAMESPACE_ID::internal::SCCInfoBase::kUninitialized), 0, InitDefaultsscc_info_LatLng_google_2ftype_2flatlng_2eproto}, {}};

static ::PROTOBUF_NAMESPACE_ID::Metadata file_level_metadata_google_2ftype_2flatlng_2eproto[1];
static constexpr ::PROTOBUF_NAMESPACE_ID::EnumDescriptor const** file_level_enum_descriptors_google_2ftype_2flatlng_2eproto = nullptr;
static constexpr ::PROTOBUF_NAMESPACE_ID::ServiceDescriptor const** file_level_service_descriptors_google_2ftype_2flatlng_2eproto = nullptr;

const ::PROTOBUF_NAMESPACE_ID::uint32 TableStruct_google_2ftype_2flatlng_2eproto::offsets[] PROTOBUF_SECTION_VARIABLE(protodesc_cold) = {
  ~0u,  // no _has_bits_
  PROTOBUF_FIELD_OFFSET(::google::type::LatLng, _internal_metadata_),
  ~0u,  // no _extensions_
  ~0u,  // no _oneof_case_
  ~0u,  // no _weak_field_map_
  PROTOBUF_FIELD_OFFSET(::google::type::LatLng, latitude_),
  PROTOBUF_FIELD_OFFSET(::google::type::LatLng, longitude_),
};
static const ::PROTOBUF_NAMESPACE_ID::internal::MigrationSchema schemas[] PROTOBUF_SECTION_VARIABLE(protodesc_cold) = {
  { 0, -1, sizeof(::google::type::LatLng)},
};

static ::PROTOBUF_NAMESPACE_ID::Message const * const file_default_instances[] = {
  reinterpret_cast<const ::PROTOBUF_NAMESPACE_ID::Message*>(&::google::type::_LatLng_default_instance_),
};

const char descriptor_table_protodef_google_2ftype_2flatlng_2eproto[] PROTOBUF_SECTION_VARIABLE(protodesc_cold) =
  "\n\030google/type/latlng.proto\022\013google.type\""
  "-\n\006LatLng\022\020\n\010latitude\030\001 \001(\001\022\021\n\tlongitude"
  "\030\002 \001(\001B`\n\017com.google.typeB\013LatLngProtoP\001"
  "Z8google.golang.org/genproto/googleapis/"
  "type/latlng;latlng\242\002\003GTPb\006proto3"
  ;
static const ::PROTOBUF_NAMESPACE_ID::internal::DescriptorTable*const descriptor_table_google_2ftype_2flatlng_2eproto_deps[1] = {
};
static ::PROTOBUF_NAMESPACE_ID::internal::SCCInfoBase*const descriptor_table_google_2ftype_2flatlng_2eproto_sccs[1] = {
  &scc_info_LatLng_google_2ftype_2flatlng_2eproto.base,
};
static ::PROTOBUF_NAMESPACE_ID::internal::once_flag descriptor_table_google_2ftype_2flatlng_2eproto_once;
static bool descriptor_table_google_2ftype_2flatlng_2eproto_initialized = false;
const ::PROTOBUF_NAMESPACE_ID::internal::DescriptorTable descriptor_table_google_2ftype_2flatlng_2eproto = {
  &descriptor_table_google_2ftype_2flatlng_2eproto_initialized, descriptor_table_protodef_google_2ftype_2flatlng_2eproto, "google/type/latlng.proto", 192,
  &descriptor_table_google_2ftype_2flatlng_2eproto_once, descriptor_table_google_2ftype_2flatlng_2eproto_sccs, descriptor_table_google_2ftype_2flatlng_2eproto_deps, 1, 0,
  schemas, file_default_instances, TableStruct_google_2ftype_2flatlng_2eproto::offsets,
  file_level_metadata_google_2ftype_2flatlng_2eproto, 1, file_level_enum_descriptors_google_2ftype_2flatlng_2eproto, file_level_service_descriptors_google_2ftype_2flatlng_2eproto,
};

// Force running AddDescriptors() at dynamic initialization time.
static bool dynamic_init_dummy_google_2ftype_2flatlng_2eproto = (  ::PROTOBUF_NAMESPACE_ID::internal::AddDescriptors(&descriptor_table_google_2ftype_2flatlng_2eproto), true);
namespace google {
namespace type {

// ===================================================================

void LatLng::InitAsDefaultInstance() {
}
class LatLng::_Internal {
 public:
};

LatLng::LatLng()
  : ::PROTOBUF_NAMESPACE_ID::Message(), _internal_metadata_(nullptr) {
  SharedCtor();
  // @@protoc_insertion_point(constructor:google.type.LatLng)
}
LatLng::LatLng(const LatLng& from)
  : ::PROTOBUF_NAMESPACE_ID::Message(),
      _internal_metadata_(nullptr) {
  _internal_metadata_.MergeFrom(from._internal_metadata_);
  ::memcpy(&latitude_, &from.latitude_,
    static_cast<size_t>(reinterpret_cast<char*>(&longitude_) -
    reinterpret_cast<char*>(&latitude_)) + sizeof(longitude_));
  // @@protoc_insertion_point(copy_constructor:google.type.LatLng)
}

void LatLng::SharedCtor() {
  ::memset(&latitude_, 0, static_cast<size_t>(
      reinterpret_cast<char*>(&longitude_) -
      reinterpret_cast<char*>(&latitude_)) + sizeof(longitude_));
}

LatLng::~LatLng() {
  // @@protoc_insertion_point(destructor:google.type.LatLng)
  SharedDtor();
}

void LatLng::SharedDtor() {
}

void LatLng::SetCachedSize(int size) const {
  _cached_size_.Set(size);
}
const LatLng& LatLng::default_instance() {
  ::PROTOBUF_NAMESPACE_ID::internal::InitSCC(&::scc_info_LatLng_google_2ftype_2flatlng_2eproto.base);
  return *internal_default_instance();
}


void LatLng::Clear() {
// @@protoc_insertion_point(message_clear_start:google.type.LatLng)
  ::PROTOBUF_NAMESPACE_ID::uint32 cached_has_bits = 0;
  // Prevent compiler warnings about cached_has_bits being unused
  (void) cached_has_bits;

  ::memset(&latitude_, 0, static_cast<size_t>(
      reinterpret_cast<char*>(&longitude_) -
      reinterpret_cast<char*>(&latitude_)) + sizeof(longitude_));
  _internal_metadata_.Clear();
}

#if GOOGLE_PROTOBUF_ENABLE_EXPERIMENTAL_PARSER
const char* LatLng::_InternalParse(const char* ptr, ::PROTOBUF_NAMESPACE_ID::internal::ParseContext* ctx) {
#define CHK_(x) if (PROTOBUF_PREDICT_FALSE(!(x))) goto failure
  while (!ctx->Done(&ptr)) {
    ::PROTOBUF_NAMESPACE_ID::uint32 tag;
    ptr = ::PROTOBUF_NAMESPACE_ID::internal::ReadTag(ptr, &tag);
    CHK_(ptr);
    switch (tag >> 3) {
      // double latitude = 1;
      case 1:
        if (PROTOBUF_PREDICT_TRUE(static_cast<::PROTOBUF_NAMESPACE_ID::uint8>(tag) == 9)) {
          latitude_ = ::PROTOBUF_NAMESPACE_ID::internal::UnalignedLoad<double>(ptr);
          ptr += sizeof(double);
        } else goto handle_unusual;
        continue;
      // double longitude = 2;
      case 2:
        if (PROTOBUF_PREDICT_TRUE(static_cast<::PROTOBUF_NAMESPACE_ID::uint8>(tag) == 17)) {
          longitude_ = ::PROTOBUF_NAMESPACE_ID::internal::UnalignedLoad<double>(ptr);
          ptr += sizeof(double);
        } else goto handle_unusual;
        continue;
      default: {
      handle_unusual:
        if ((tag & 7) == 4 || tag == 0) {
          ctx->SetLastTag(tag);
          goto success;
        }
        ptr = UnknownFieldParse(tag, &_internal_metadata_, ptr, ctx);
        CHK_(ptr != nullptr);
        continue;
      }
    }  // switch
  }  // while
success:
  return ptr;
failure:
  ptr = nullptr;
  goto success;
#undef CHK_
}
#else  // GOOGLE_PROTOBUF_ENABLE_EXPERIMENTAL_PARSER
bool LatLng::MergePartialFromCodedStream(
    ::PROTOBUF_NAMESPACE_ID::io::CodedInputStream* input) {
#define DO_(EXPRESSION) if (!PROTOBUF_PREDICT_TRUE(EXPRESSION)) goto failure
  ::PROTOBUF_NAMESPACE_ID::uint32 tag;
  // @@protoc_insertion_point(parse_start:google.type.LatLng)
  for (;;) {
    ::std::pair<::PROTOBUF_NAMESPACE_ID::uint32, bool> p = input->ReadTagWithCutoffNoLastTag(127u);
    tag = p.first;
    if (!p.second) goto handle_unusual;
    switch (::PROTOBUF_NAMESPACE_ID::internal::WireFormatLite::GetTagFieldNumber(tag)) {
      // double latitude = 1;
      case 1: {
        if (static_cast< ::PROTOBUF_NAMESPACE_ID::uint8>(tag) == (9 & 0xFF)) {

          DO_((::PROTOBUF_NAMESPACE_ID::internal::WireFormatLite::ReadPrimitive<
                   double, ::PROTOBUF_NAMESPACE_ID::internal::WireFormatLite::TYPE_DOUBLE>(
                 input, &latitude_)));
        } else {
          goto handle_unusual;
        }
        break;
      }

      // double longitude = 2;
      case 2: {
        if (static_cast< ::PROTOBUF_NAMESPACE_ID::uint8>(tag) == (17 & 0xFF)) {

          DO_((::PROTOBUF_NAMESPACE_ID::internal::WireFormatLite::ReadPrimitive<
                   double, ::PROTOBUF_NAMESPACE_ID::internal::WireFormatLite::TYPE_DOUBLE>(
                 input, &longitude_)));
        } else {
          goto handle_unusual;
        }
        break;
      }

      default: {
      handle_unusual:
        if (tag == 0) {
          goto success;
        }
        DO_(::PROTOBUF_NAMESPACE_ID::internal::WireFormat::SkipField(
              input, tag, _internal_metadata_.mutable_unknown_fields()));
        break;
      }
    }
  }
success:
  // @@protoc_insertion_point(parse_success:google.type.LatLng)
  return true;
failure:
  // @@protoc_insertion_point(parse_failure:google.type.LatLng)
  return false;
#undef DO_
}
#endif  // GOOGLE_PROTOBUF_ENABLE_EXPERIMENTAL_PARSER

void LatLng::SerializeWithCachedSizes(
    ::PROTOBUF_NAMESPACE_ID::io::CodedOutputStream* output) const {
  // @@protoc_insertion_point(serialize_start:google.type.LatLng)
  ::PROTOBUF_NAMESPACE_ID::uint32 cached_has_bits = 0;
  (void) cached_has_bits;

  // double latitude = 1;
  if (!(this->latitude() <= 0 && this->latitude() >= 0)) {
    ::PROTOBUF_NAMESPACE_ID::internal::WireFormatLite::WriteDouble(1, this->latitude(), output);
  }

  // double longitude = 2;
  if (!(this->longitude() <= 0 && this->longitude() >= 0)) {
    ::PROTOBUF_NAMESPACE_ID::internal::WireFormatLite::WriteDouble(2, this->longitude(), output);
  }

  if (_internal_metadata_.have_unknown_fields()) {
    ::PROTOBUF_NAMESPACE_ID::internal::WireFormat::SerializeUnknownFields(
        _internal_metadata_.unknown_fields(), output);
  }
  // @@protoc_insertion_point(serialize_end:google.type.LatLng)
}

::PROTOBUF_NAMESPACE_ID::uint8* LatLng::InternalSerializeWithCachedSizesToArray(
    ::PROTOBUF_NAMESPACE_ID::uint8* target) const {
  // @@protoc_insertion_point(serialize_to_array_start:google.type.LatLng)
  ::PROTOBUF_NAMESPACE_ID::uint32 cached_has_bits = 0;
  (void) cached_has_bits;

  // double latitude = 1;
  if (!(this->latitude() <= 0 && this->latitude() >= 0)) {
    target = ::PROTOBUF_NAMESPACE_ID::internal::WireFormatLite::WriteDoubleToArray(1, this->latitude(), target);
  }

  // double longitude = 2;
  if (!(this->longitude() <= 0 && this->longitude() >= 0)) {
    target = ::PROTOBUF_NAMESPACE_ID::internal::WireFormatLite::WriteDoubleToArray(2, this->longitude(), target);
  }

  if (_internal_metadata_.have_unknown_fields()) {
    target = ::PROTOBUF_NAMESPACE_ID::internal::WireFormat::SerializeUnknownFieldsToArray(
        _internal_metadata_.unknown_fields(), target);
  }
  // @@protoc_insertion_point(serialize_to_array_end:google.type.LatLng)
  return target;
}

size_t LatLng::ByteSizeLong() const {
// @@protoc_insertion_point(message_byte_size_start:google.type.LatLng)
  size_t total_size = 0;

  if (_internal_metadata_.have_unknown_fields()) {
    total_size +=
      ::PROTOBUF_NAMESPACE_ID::internal::WireFormat::ComputeUnknownFieldsSize(
        _internal_metadata_.unknown_fields());
  }
  ::PROTOBUF_NAMESPACE_ID::uint32 cached_has_bits = 0;
  // Prevent compiler warnings about cached_has_bits being unused
  (void) cached_has_bits;

  // double latitude = 1;
  if (!(this->latitude() <= 0 && this->latitude() >= 0)) {
    total_size += 1 + 8;
  }

  // double longitude = 2;
  if (!(this->longitude() <= 0 && this->longitude() >= 0)) {
    total_size += 1 + 8;
  }

  int cached_size = ::PROTOBUF_NAMESPACE_ID::internal::ToCachedSize(total_size);
  SetCachedSize(cached_size);
  return total_size;
}

void LatLng::MergeFrom(const ::PROTOBUF_NAMESPACE_ID::Message& from) {
// @@protoc_insertion_point(generalized_merge_from_start:google.type.LatLng)
  GOOGLE_DCHECK_NE(&from, this);
  const LatLng* source =
      ::PROTOBUF_NAMESPACE_ID::DynamicCastToGenerated<LatLng>(
          &from);
  if (source == nullptr) {
  // @@protoc_insertion_point(generalized_merge_from_cast_fail:google.type.LatLng)
    ::PROTOBUF_NAMESPACE_ID::internal::ReflectionOps::Merge(from, this);
  } else {
  // @@protoc_insertion_point(generalized_merge_from_cast_success:google.type.LatLng)
    MergeFrom(*source);
  }
}

void LatLng::MergeFrom(const LatLng& from) {
// @@protoc_insertion_point(class_specific_merge_from_start:google.type.LatLng)
  GOOGLE_DCHECK_NE(&from, this);
  _internal_metadata_.MergeFrom(from._internal_metadata_);
  ::PROTOBUF_NAMESPACE_ID::uint32 cached_has_bits = 0;
  (void) cached_has_bits;

  if (!(from.latitude() <= 0 && from.latitude() >= 0)) {
    set_latitude(from.latitude());
  }
  if (!(from.longitude() <= 0 && from.longitude() >= 0)) {
    set_longitude(from.longitude());
  }
}

void LatLng::CopyFrom(const ::PROTOBUF_NAMESPACE_ID::Message& from) {
// @@protoc_insertion_point(generalized_copy_from_start:google.type.LatLng)
  if (&from == this) return;
  Clear();
  MergeFrom(from);
}

void LatLng::CopyFrom(const LatLng& from) {
// @@protoc_insertion_point(class_specific_copy_from_start:google.type.LatLng)
  if (&from == this) return;
  Clear();
  MergeFrom(from);
}

bool LatLng::IsInitialized() const {
  return true;
}

void LatLng::InternalSwap(LatLng* other) {
  using std::swap;
  _internal_metadata_.Swap(&other->_internal_metadata_);
  swap(latitude_, other->latitude_);
  swap(longitude_, other->longitude_);
}

::PROTOBUF_NAMESPACE_ID::Metadata LatLng::GetMetadata() const {
  return GetMetadataStatic();
}


// @@protoc_insertion_point(namespace_scope)
}  // namespace type
}  // namespace google
PROTOBUF_NAMESPACE_OPEN
template<> PROTOBUF_NOINLINE ::google::type::LatLng* Arena::CreateMaybeMessage< ::google::type::LatLng >(Arena* arena) {
  return Arena::CreateInternal< ::google::type::LatLng >(arena);
}
PROTOBUF_NAMESPACE_CLOSE

// @@protoc_insertion_point(global_scope)
#include <google/protobuf/port_undef.inc>
