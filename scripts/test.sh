#!/usr/bin/env bash
# Builds and tests every target on an iPhone simulator, as CI and the Release Wrapper do.
# Extra arguments go to xcodebuild.
set -euo pipefail

cd "$(dirname "$0")/.."

# Prefer an iPhone on the simulator runtime that matches the SDK (iOS-26-2 for Xcode 26.2), then any iPhone.
sdk_runtime="iOS-$(xcrun --sdk iphonesimulator --show-sdk-version | tr . -)"
simulator_id="$(
  xcrun simctl list devices available --json |
    python3 -c 'import json, sys
runtime = sys.argv[1]
devices = [(key, device) for key, group in json.load(sys.stdin)["devices"].items() for device in group if device.get("isAvailable") and device["name"].startswith("iPhone")]
matching = [device for key, device in devices if key.endswith("." + runtime)]
print((matching or [device for _, device in devices])[0]["udid"])' "$sdk_runtime"
)"
echo "SDK runtime ${sdk_runtime}; simulator ${simulator_id}:"
xcrun simctl list devices available | grep "${simulator_id}" || true

# The product schemes have no test action; MobileSync-Package builds and tests every target.
xcrun xcodebuild \
  -scheme MobileSync-Package \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,id=${simulator_id}" \
  COMPILER_INDEX_STORE_ENABLE=NO \
  "$@" \
  build test
