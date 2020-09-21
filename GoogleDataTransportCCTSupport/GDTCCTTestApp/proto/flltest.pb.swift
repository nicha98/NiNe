// DO NOT EDIT.
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: GoogleDataTransportCCTSupport/GDTCCTTestApp/proto/flltest.proto
//
// For information on using the generated types, please see the documenation:
//   https://github.com/apple/swift-protobuf/

//
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

// This proto should rarely, if ever, need to be updated. If the need for a
// regenerate is needed, do the following:
// brew install protobuf swift-protobuf
// cd <root of this repo>
// protoc --swift_out=. GoogleDataTransportCCTSupport/GDTCCTTestApp/proto/flltest.proto

import Foundation
import SwiftProtobuf

// If the compiler emits an error on this type, it is because this file
// was generated by a version of the `protoc` Swift plug-in that is
// incompatible with the version of SwiftProtobuf to which you are linking.
// Please ensure that your are building against the same version of the API
// that was used to generate this file.
fileprivate struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
  struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
  typealias Version = _2
}

struct FirelogTestMessage {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  var identifier: String {
    get {return _storage._identifier}
    set {_uniqueStorage()._identifier = newValue}
  }

  var subMessage: SubMessageOne {
    get {return _storage._subMessage ?? SubMessageOne()}
    set {_uniqueStorage()._subMessage = newValue}
  }
  /// Returns true if `subMessage` has been explicitly set.
  var hasSubMessage: Bool {return _storage._subMessage != nil}
  /// Clears the value of `subMessage`. Subsequent reads from it will return its default value.
  mutating func clearSubMessage() {_uniqueStorage()._subMessage = nil}

  var repeatedID: [String] {
    get {return _storage._repeatedID}
    set {_uniqueStorage()._repeatedID = newValue}
  }

  var warriorChampionships: Int32 {
    get {return _storage._warriorChampionships}
    set {_uniqueStorage()._warriorChampionships = newValue}
  }

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}

  fileprivate var _storage = _StorageClass.defaultInstance
}

struct SubMessageOne {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  var repeatedSubMessage: [SubMessageTwo] = []

  var ignoreThisMessage: Bool = false

  var starTrekData: Data = SwiftProtobuf.Internal.emptyData

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}
}

struct SubMessageTwo {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  var samplingPercentage: Double = 0

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}
}

// MARK: - Code below here is support for the SwiftProtobuf runtime.

extension FirelogTestMessage: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = "FirelogTestMessage"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "identifier"),
    14: .standard(proto: "sub_message"),
    15: .standard(proto: "repeated_id"),
    16: .standard(proto: "warrior_championships"),
  ]

  fileprivate class _StorageClass {
    var _identifier: String = String()
    var _subMessage: SubMessageOne? = nil
    var _repeatedID: [String] = []
    var _warriorChampionships: Int32 = 0

    static let defaultInstance = _StorageClass()

    private init() {}

    init(copying source: _StorageClass) {
      _identifier = source._identifier
      _subMessage = source._subMessage
      _repeatedID = source._repeatedID
      _warriorChampionships = source._warriorChampionships
    }
  }

  fileprivate mutating func _uniqueStorage() -> _StorageClass {
    if !isKnownUniquelyReferenced(&_storage) {
      _storage = _StorageClass(copying: _storage)
    }
    return _storage
  }

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    _ = _uniqueStorage()
    try withExtendedLifetime(_storage) { (_storage: _StorageClass) in
      while let fieldNumber = try decoder.nextFieldNumber() {
        switch fieldNumber {
        case 1: try decoder.decodeSingularStringField(value: &_storage._identifier)
        case 14: try decoder.decodeSingularMessageField(value: &_storage._subMessage)
        case 15: try decoder.decodeRepeatedStringField(value: &_storage._repeatedID)
        case 16: try decoder.decodeSingularInt32Field(value: &_storage._warriorChampionships)
        default: break
        }
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    try withExtendedLifetime(_storage) { (_storage: _StorageClass) in
      if !_storage._identifier.isEmpty {
        try visitor.visitSingularStringField(value: _storage._identifier, fieldNumber: 1)
      }
      if let v = _storage._subMessage {
        try visitor.visitSingularMessageField(value: v, fieldNumber: 14)
      }
      if !_storage._repeatedID.isEmpty {
        try visitor.visitRepeatedStringField(value: _storage._repeatedID, fieldNumber: 15)
      }
      if _storage._warriorChampionships != 0 {
        try visitor.visitSingularInt32Field(value: _storage._warriorChampionships, fieldNumber: 16)
      }
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: FirelogTestMessage, rhs: FirelogTestMessage) -> Bool {
    if lhs._storage !== rhs._storage {
      let storagesAreEqual: Bool = withExtendedLifetime((lhs._storage, rhs._storage)) { (_args: (_StorageClass, _StorageClass)) in
        let _storage = _args.0
        let rhs_storage = _args.1
        if _storage._identifier != rhs_storage._identifier {return false}
        if _storage._subMessage != rhs_storage._subMessage {return false}
        if _storage._repeatedID != rhs_storage._repeatedID {return false}
        if _storage._warriorChampionships != rhs_storage._warriorChampionships {return false}
        return true
      }
      if !storagesAreEqual {return false}
    }
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension SubMessageOne: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = "SubMessageOne"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    5: .standard(proto: "repeated_sub_message"),
    6: .standard(proto: "ignore_this_message"),
    7: .standard(proto: "star_trek_data"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      switch fieldNumber {
      case 5: try decoder.decodeRepeatedMessageField(value: &self.repeatedSubMessage)
      case 6: try decoder.decodeSingularBoolField(value: &self.ignoreThisMessage)
      case 7: try decoder.decodeSingularBytesField(value: &self.starTrekData)
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.repeatedSubMessage.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.repeatedSubMessage, fieldNumber: 5)
    }
    if self.ignoreThisMessage != false {
      try visitor.visitSingularBoolField(value: self.ignoreThisMessage, fieldNumber: 6)
    }
    if !self.starTrekData.isEmpty {
      try visitor.visitSingularBytesField(value: self.starTrekData, fieldNumber: 7)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: SubMessageOne, rhs: SubMessageOne) -> Bool {
    if lhs.repeatedSubMessage != rhs.repeatedSubMessage {return false}
    if lhs.ignoreThisMessage != rhs.ignoreThisMessage {return false}
    if lhs.starTrekData != rhs.starTrekData {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension SubMessageTwo: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = "SubMessageTwo"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    5: .standard(proto: "sampling_percentage"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      switch fieldNumber {
      case 5: try decoder.decodeSingularDoubleField(value: &self.samplingPercentage)
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if self.samplingPercentage != 0 {
      try visitor.visitSingularDoubleField(value: self.samplingPercentage, fieldNumber: 5)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: SubMessageTwo, rhs: SubMessageTwo) -> Bool {
    if lhs.samplingPercentage != rhs.samplingPercentage {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}
