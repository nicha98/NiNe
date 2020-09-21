# Firebase Carthage

## Context

This page introduces and provides instructions for an **experimental** Firebase
[Carthage](https://github.com/Carthage/Carthage) implementation. Based on
feedback and usage, the Firebase team may decide to make the Carthage
distribution official.

Please [let us know](https://github.com/firebase/firebase-ios-sdk/issues) if you
have suggestions about how best to distribute Carthage binaries that include
resource bundles.

## Carthage Installation

[Homebrew](http://brew.sh/) is one way to install Carthage.

```bash
$ brew update
$ brew install carthage
```

See the
[Carthage page](https://github.com/Carthage/Carthage#installing-carthage) for
more details and additional installation methods.

## Carthage Usage

- Create a Cartfile with a **subset** of the following components - choosing the
Firebase components that you want to include in your app. Note that
**FirebaseAnalytics** must always be included.
```
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseABTestingBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseAdMobBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseAnalyticsBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseAuthBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseCrashBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseDatabaseBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseDynamicLinksBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseFirestoreBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseFunctionsBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseInvitesBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseMessagingBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebasePerformanceBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseRemoteConfigBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseStorageBinary.json"
```
- Run `carthage update`
- Use Finder to open `Carthage/Build/iOS`.
- Copy the contents into the top level of your Xcode project and make sure
    they're added to the right build target(s).
- Add the -ObjC flag to "Other Linker Flags".
- Make sure that the build target(s) includes your project's `GoogleService-Info.plist`.
- [Delete Firebase.framework from the Link Binary With Libraries Build Phase](https://github.com/firebase/firebase-ios-sdk/issues/911#issuecomment-372455235).
- If you're including a Firebase component that has resources, copy its bundles
    into the Xcode project and make sure they're added to the
    `Copy Bundle Resources` Build Phase :
    - For Firestore:
        - ./Carthage/Build/iOS/gRPC.framework/gRPCCertificates.bundle
    - For Invites:
        - ./Carthage/Build/iOS/FirebaseInvites.framework/GoogleSignIn.bundle
        - ./Carthage/Build/iOS/FirebaseInvites.framework/GPPACLPickerResources.bundle
        - ./Carthage/Build/iOS/FirebaseInvites.framework/GINInviteResources.bundle

## Versioning

Unlike the CocoaPods distribution, the Carthage distribution is like the
Firebase zip release in that all the Firebase components share the same version.
Mixing and matching components with different versions may cause linker errors.

## Static Frameworks

Note that the Firebase frameworks in the distribution include static libraries.
While it is fine to link these into apps, it will generally not work to depend
on them from wrapper dynamic frameworks.

## Acknowledgements

Thanks to the Firebase community for encouraging this implementation including
those who have made this the most updated
[firebase-ios-sdk](https://github.com/firebase/firebase-ios-sdk)
[issue](https://github.com/firebase/firebase-ios-sdk/issues/9).

Thanks also to those who have already done Firebase Carthage implementations,
such as https://github.com/soheilbm/Firebase.
