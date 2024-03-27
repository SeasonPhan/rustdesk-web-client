#!/usr/bin/env bash

## Make the script exit on any failed command
# -e : exits on error
# -u : errors on undefined variables
# -x : prints commands before execution
# -o : pipefail exits on command pipe failures.
set -euxo pipefail

# source rust (or next command will fail)
. "$HOME/.cargo/env"

# update cargo (or next command will fail)
rustup update

cargo install flutter_rust_bridge_codegen --version 1.80.1 --features uuid
flutter pub get
flutter_rust_bridge_codegen --rust-input ../src/flutter_ffi.rs --dart-output ./lib/generated_bridge.dart --c-output ./macos/Runner/bridge_generated.h
# call `flutter clean` if cargo build fails
# export LLVM_HOME=/Library/Developer/CommandLineTools/usr/
cargo build --features "flutter,flutter_texture_render"
flutter $@