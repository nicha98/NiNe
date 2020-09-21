#!/usr/bin/env bash

# Copyright 2018 Google
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# USAGE: build.sh product [platform] [method]
#
# Builds the given product for the given platform using the given build method

set -euo pipefail

if [[ $# -lt 1 ]]; then
  cat 1>&2 <<EOF
USAGE: $0 product [platform] [method]

product can be one of:
  Firebase
  Firestore
  InAppMessagingDisplay

platform can be one of:
  iOS (default)
  macOS
  tvOS

method can be one of:
  xcodebuild (default)
  cmake

Optionally, reads the environment variable SANITIZERS. If set, it is expected to
be a string containing a space-separated list with some of the following
elements:
  asan
  tsan
  ubsan
EOF
  exit 1
fi

product="$1"

platform="iOS"
if [[ $# -gt 1 ]]; then
  platform="$2"
fi

method="xcodebuild"
if [[ $# -gt 2 ]]; then
  method="$3"
fi

echo "Building $product for $platform using $method"
if [[ -n "${SANITIZERS:-}" ]]; then
  echo "Using sanitizers: $SANITIZERS"
fi

# Runs xcodebuild with the given flags, piping output to xcpretty
# If xcodebuild fails with known error codes, retries once.
function RunXcodebuild() {
  xcodebuild "$@" | xcpretty; result=$?
  if [[ $result == 65 ]]; then
    echo "xcodebuild exited with 65, retrying" 1>&2
    sleep 5

    xcodebuild "$@" | xcpretty; result=$?
  fi
  if [[ $result != 0 ]]; then
    exit $result
  fi
}

# Compute standard flags for all platforms
case "$platform" in
  iOS)
    xcb_flags=(
      -sdk 'iphonesimulator'
      -destination 'platform=iOS Simulator,name=iPhone 7'
    )
    ;;

  macOS)
    xcb_flags=(
      -sdk 'macosx'
      -destination 'platform=OS X,arch=x86_64'
    )
    ;;

  tvOS)
    xcb_flags=(
      -sdk "appletvsimulator"
      -destination 'platform=tvOS Simulator,name=Apple TV'
    )
    ;;

  *)
    echo "Unknown platform '$platform'" 1>&2
    exit 1
    ;;
esac

xcb_flags+=(
  ONLY_ACTIVE_ARCH=YES
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGNING_ALLOWED=YES
)

# TODO(varconst): --warn-unused-vars - right now, it makes the log overflow on
# Travis.
cmake_options=(
  -Wdeprecated
  --warn-uninitialized
)

xcode_version=$(xcodebuild -version | head -n 1)
xcode_version="${xcode_version/Xcode /}"
xcode_major="${xcode_version/.*/}"

if [[ -n "${SANITIZERS:-}" ]]; then
  for sanitizer in $SANITIZERS; do
    case "$sanitizer" in
      asan)
        xcb_flags+=(
          -enableAddressSanitizer YES
        )
        cmake_options+=(
          -DWITH_ASAN=ON
        )
        ;;

      tsan)
        xcb_flags+=(
          -enableThreadSanitizer YES
        )
        cmake_options+=(
          -DWITH_TSAN=ON
        )
        ;;

      ubsan)
        xcb_flags+=(
          -enableUndefinedBehaviorSanitizer YES
        )
        cmake_options+=(
          -DWITH_UBSAN=ON
        )
        ;;

      *)
        echo "Unknown sanitizer '$sanitizer'" 1>&2
        exit 1
        ;;
    esac
  done
fi

case "$product-$method-$platform" in
  Firebase-xcodebuild-*)
    RunXcodebuild \
        -workspace 'Example/Firebase.xcworkspace' \
        -scheme "AllUnitTests_$platform" \
        "${xcb_flags[@]}" \
        build \
        test

    RunXcodebuild \
        -workspace 'GoogleUtilities/Example/GoogleUtilities.xcworkspace' \
        -scheme "Example_$platform" \
        "${xcb_flags[@]}" \
        build \
        test

    if [[ $platform == 'iOS' ]]; then
      RunXcodebuild \
          -workspace 'Functions/Example/FirebaseFunctions.xcworkspace' \
          -scheme "FirebaseFunctions_Tests" \
          "${xcb_flags[@]}" \
          build \
          test

      # Run integration tests (not allowed on PRs)
      if [ "$TRAVIS_PULL_REQUEST" == "false" ]; then
        RunXcodebuild \
          -workspace 'Example/Firebase.xcworkspace' \
          -scheme "Storage_IntegrationTests_iOS" \
          "${xcb_flags[@]}" \
          build \
          test

        RunXcodebuild \
          -workspace 'Example/Firebase.xcworkspace' \
          -scheme "Database_IntegrationTests_iOS" \
          "${xcb_flags[@]}" \
          build \
          test
      fi

      # Test iOS Objective-C static library build
      cd Example
      sed -i -e 's/use_frameworks/\#use_frameworks/' Podfile
      pod update --no-repo-update
      cd ..
      RunXcodebuild \
          -workspace 'Example/Firebase.xcworkspace' \
          -scheme "AllUnitTests_$platform" \
          "${xcb_flags[@]}" \
          build \
          test

      cd Functions/Example
      sed -i -e 's/use_frameworks/\#use_frameworks/' Podfile
      pod update --no-repo-update
      cd ../..
      RunXcodebuild \
          -workspace 'Functions/Example/FirebaseFunctions.xcworkspace' \
          -scheme "FirebaseFunctions_Tests" \
          "${xcb_flags[@]}" \
          build \
          test
    fi
    ;;

  InAppMessagingDisplay-xcodebuild-iOS)
    # Run UI tests on both iPad and iphone simultors
    RunXcodebuild \
        -workspace 'InAppMessagingDisplay/Example/InAppMessagingDisplay-Sample.xcworkspace'  \
        -scheme 'FiamDisplaySwiftExample' \
        "${xcb_flags[@]}" \
        -destination 'platform=iOS Simulator,name=iPad Air' \
        build \
        test

    cd InAppMessagingDisplay/Example
    sed -i -e 's/use_frameworks/\#use_frameworks/' Podfile
    pod update --no-repo-update
    cd ../..
    # Run UI tests on both iPad and iphone simultors
    RunXcodebuild \
        -workspace 'InAppMessagingDisplay/Example/InAppMessagingDisplay-Sample.xcworkspace'  \
        -scheme 'FiamDisplaySwiftExample' \
        "${xcb_flags[@]}" \
        -destination 'platform=iOS Simulator,name=iPad Air' \
        build \
        test
    ;;

  Firestore-xcodebuild-iOS)
    RunXcodebuild \
        -workspace 'Firestore/Example/Firestore.xcworkspace' \
        -scheme "Firestore_Tests_$platform" \
        "${xcb_flags[@]}" \
        build \
        test

    # Firestore_SwiftTests_iOS require Swift 4, which needs Xcode 9
    if [[ "$xcode_major" -ge 9 ]]; then
      RunXcodebuild \
          -workspace 'Firestore/Example/Firestore.xcworkspace' \
          -scheme "Firestore_SwiftTests_$platform" \
          "${xcb_flags[@]}" \
          build \
          test
    fi

    RunXcodebuild \
        -workspace 'Firestore/Example/Firestore.xcworkspace' \
        -scheme "Firestore_IntegrationTests_$platform" \
        "${xcb_flags[@]}" \
        build

    # Firestore_FuzzTests_iOS require a Clang that supports -fsanitize-coverage=trace-pc-guard
    # and cannot run with thread sanitizer.
    if [[ "$xcode_major" -ge 9 ]] && ! [[ -n "${SANITIZERS:-}" && "$SANITIZERS" = *"tsan"* ]]; then
      RunXcodebuild \
          -workspace 'Firestore/Example/Firestore.xcworkspace' \
          -scheme "Firestore_FuzzTests_iOS" \
          "${xcb_flags[@]}" \
          FUZZING_TARGET="NONE" \
          test
    fi
    ;;

  Firestore-cmake-macOS)
    test -d build || mkdir build
    echo "Preparing cmake build ..."
    (cd build; cmake "${cmake_options[@]}" ..)

    echo "Building cmake build ..."
    cpus=$(sysctl -n hw.ncpu)
    (cd build; env make -j $cpus all generate_protos)
    (cd build; env CTEST_OUTPUT_ON_FAILURE=1 make -j $cpus test)
    ;;

  *)
    echo "Don't know how to build this product-platform-method combination" 1>&2
    echo "  product=$product" 1>&2
    echo "  platform=$platform" 1>&2
    echo "  method=$method" 1>&2
    exit 1
    ;;
esac
