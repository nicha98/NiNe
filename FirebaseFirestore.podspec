Pod::Spec.new do |s|
  s.name             = 'FirebaseFirestore'
  s.version          = '1.8.3'
  s.summary          = 'Google Cloud Firestore for iOS'

  s.description      = <<-DESC
Google Cloud Firestore is a NoSQL document database built for automatic scaling, high performance, and ease of application development.
                       DESC

  s.homepage         = 'https://developers.google.com/'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'Firestore-' + s.version.to_s
  }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '10.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = [
    'Firestore/Source/Public/*.h',
    'Firestore/Source/**/*.{m,mm}',
    'Firestore/Protos/nanopb/**/*.cc',
    'Firestore/Protos/objc/**/*.m',
    'Firestore/core/include/**/*.{cc,mm}',
    'Firestore/core/src/**/*.{cc,mm}',
  ]
  s.preserve_paths = [
    'Firestore/Source/API/*.h',
    'Firestore/Source/Core/*.h',
    'Firestore/Source/Local/*.h',
    'Firestore/Source/Remote/*.h',
    'Firestore/Source/Util/*.h',
    'Firestore/Protos/nanopb/**/*.h',
    'Firestore/Protos/objc/**/*.h',
    'Firestore/core/include/**/*.h',
    'Firestore/core/src/**/*.h',
  ]
  s.requires_arc = [
    'Firestore/Source/**/*',
    'Firestore/core/src/**/*.mm',
  ]
  s.exclude_files = [
    # Exclude alternate implementations for other platforms
    'Firestore/core/src/firebase/firestore/api/input_validation_std.cc',
    'Firestore/core/src/firebase/firestore/remote/connectivity_monitor_noop.cc',
    'Firestore/core/src/firebase/firestore/util/filesystem_win.cc',
    'Firestore/core/src/firebase/firestore/util/hard_assert_stdio.cc',
    'Firestore/core/src/firebase/firestore/util/log_stdio.cc',
    'Firestore/core/src/firebase/firestore/util/secure_random_openssl.cc'
  ]
  s.public_header_files = 'Firestore/Source/Public/*.h'

  s.dependency 'FirebaseAuthInterop', '~> 1.0'
  s.dependency 'FirebaseCore', '~> 6.2'

  abseil_version = '0.20190808'
  s.dependency 'abseil/algorithm', abseil_version
  s.dependency 'abseil/base', abseil_version
  s.dependency 'abseil/memory', abseil_version
  s.dependency 'abseil/meta', abseil_version
  s.dependency 'abseil/strings/strings', abseil_version
  s.dependency 'abseil/time', abseil_version
  s.dependency 'abseil/types', abseil_version

  s.dependency 'gRPC-C++', '0.0.9'
  s.dependency 'leveldb-library', '~> 1.22'
  s.dependency 'nanopb', '~> 0.3.901'

  s.ios.frameworks = 'MobileCoreServices', 'SystemConfiguration'
  s.osx.frameworks = 'SystemConfiguration'
  s.tvos.frameworks = 'SystemConfiguration'

  s.library = 'c++'
  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++0x',
    'GCC_C_LANGUAGE_STANDARD' => 'c99',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      "FIRFirestore_VERSION=#{s.version} " +
      # The nanopb pod sets these defs, so we must too. (We *do* require 16bit
      # (or larger) fields, so we'd have to set at least PB_FIELD_16BIT
      # anyways.)
      'PB_FIELD_32BIT=1 PB_NO_PACKED_STRUCTS=1 PB_ENABLE_MALLOC=1',
    'HEADER_SEARCH_PATHS' =>
      '"${PODS_TARGET_SRCROOT}" ' +
      '"${PODS_TARGET_SRCROOT}/Firestore/Source/Public" ' +
      '"${PODS_ROOT}/nanopb" ' +
      '"${PODS_TARGET_SRCROOT}/Firestore/Protos/nanopb" ' +
      '"${PODS_TARGET_SRCROOT}/Firestore/Protos/objc/google/api" ' +
      '"${PODS_TARGET_SRCROOT}/Firestore/Protos/objc/google/firestore/v1" ' +
      '"${PODS_TARGET_SRCROOT}/Firestore/Protos/objc/google/rpc" ' +
      '"${PODS_TARGET_SRCROOT}/Firestore/Protos/objc/google/type"',
  }

  # Generate a version of the config.h header suitable for building with
  # CocoaPods.
  s.prepare_command = <<-CMD
    sed '/^#cmakedefine/ d' \
        Firestore/core/src/firebase/firestore/util/config.h.in > \
        Firestore/core/src/firebase/firestore/util/config.h
  CMD

  s.compiler_flags = '$(inherited) -Wreorder -Werror=reorder -Wno-comma'
end
