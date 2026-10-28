#!/usr/bin/env bash
# Builds and tests every target on an iPhone simulator, as CI and the Release Wrapper do.
# Extra arguments go to xcodebuild, e.g. -clonedSourcePackagesDirPath <dir>.
set -euo pipefail

cd "$(dirname "$0")/.."

simulator_id="$(
  xcrun simctl list devices available --json |
    python3 -c 'import json, sys; print(next(device["udid"] for devices in json.load(sys.stdin)["devices"].values() for device in devices if device.get("isAvailable") and device["name"].startswith("iPhone")))'
)"

# Start booting now so the simulator comes up while packages resolve and build; xcodebuild waits for it.
# A simulator that is already booted makes this fail, which is fine.
xcrun simctl boot "$simulator_id" 2> /dev/null || true

# The product schemes have no test action; MobileSync-Package builds and tests every target.
xcrun xcodebuild \
  -scheme MobileSync-Package \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,id=${simulator_id}" \
  COMPILER_INDEX_STORE_ENABLE=NO \
  "$@" \
  build test
