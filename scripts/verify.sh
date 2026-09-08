#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: ./scripts/verify.sh SIMULATOR_UUID" >&2
  exit 2
fi

cd "$(dirname "$0")/.."
swift test
xcodegen generate
xcodebuild -project Taskomatic.xcodeproj -scheme Taskomatic \
  -destination "platform=iOS Simulator,id=$1" \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test
