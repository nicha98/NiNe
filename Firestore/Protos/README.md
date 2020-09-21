## Usage

First, make sure you have necessary prereqs for building:
```
brew install automake libtool protobuf golang
```

Take a nap while that completes. Then, build the protos:
```
cd firebase-ios-sdk
mkdir -p build
cd build
cmake ..
make -j generate_protos
```

Verify diffs, make sure tests still pass, and create a PR.

### Script Details

Get the protoc and the gRPC plugin. See
[here](https://github.com/grpc/grpc/tree/master/src/objective-c). The
easiest way I found was to add
`pod '!ProtoCompiler-gRPCPlugin'` to a Podfile and do `pod update`.

After running the protoc, shell commands run to fix up the generated code:
  * Flatten import paths for CocoaPods library build.
  * Remove unneeded extensionRegistry functions.
  * Remove non-buildable code from Annotations.pbobjc.*.
