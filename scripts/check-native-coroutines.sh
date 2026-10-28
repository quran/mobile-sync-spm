#!/usr/bin/env bash
# Checks that the KMP-NativeCoroutines Swift package pinned in Package.swift matches the KMP-NativeCoroutines
# Kotlin plugin (`native-coroutines` in gradle/libs.versions.toml) of the mobile-sync release named by
# remoteVersion. The two halves of the library must be the same version; a mismatch leaks collectors.
# With --update, it sets the pin to the Kotlin plugin's version instead of failing, as the Release Wrapper does.
set -euo pipefail

cd "$(dirname "$0")/.."

update=false
case "${1-}" in
  "") ;;
  --update) update=true ;;
  *)
    echo "usage: $0 [--update]" >&2
    exit 2
    ;;
esac

fail() {
  echo "::error::$*"
  exit 1
}

# Exactly one match of a sed -nE expression in a file, ignoring CRs, or nothing.
single_match() {
  local matches
  matches="$(tr -d '\r' < "$2" | sed -nE "$1")"
  if [[ -n "$matches" && "$(wc -l <<< "$matches")" -eq 1 ]]; then
    echo "$matches"
  fi
}

remote_version="$(single_match 's|^let remoteVersion = "([^"]*)"[[:space:]]*(//.*)?$|\1|p' Package.swift)"
if [[ ! "$remote_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  fail "Couldn't read remoteVersion from Package.swift: expected one 'let remoteVersion = \"x.y.z\"' line, got '${remote_version}'."
fi

# The dependency spans lines, so flatten Package.swift before matching it.
swift_matches="$(
  tr '\n' ' ' < Package.swift |
    grep -oE '"https://github\.com/rickclephas/KMP-NativeCoroutines\.git"[[:space:]]*,[[:space:]]*exact:[[:space:]]*"[^"]+"' ||
    true
)"
if [[ -z "$swift_matches" || "$(wc -l <<< "$swift_matches")" -ne 1 ]]; then
  fail "Couldn't read the KMP-NativeCoroutines version from Package.swift: expected one .package(url: \"https://github.com/rickclephas/KMP-NativeCoroutines.git\", exact: \"…\") dependency."
fi
swift_version="$(sed -E 's/.*"([^"]+)"$/\1/' <<< "$swift_matches")"

toml_url="https://raw.githubusercontent.com/quran/mobile-sync/v${remote_version}/gradle/libs.versions.toml"
toml_file="$(mktemp)"
trap 'rm -f "$toml_file"' EXIT
if ! curl --fail --silent --show-error --location --connect-timeout 10 --max-time 30 \
  --retry 5 --retry-delay 2 --retry-connrefused --output "$toml_file" "$toml_url"; then
  fail "Couldn't fetch ${toml_url}. Is v${remote_version} (remoteVersion in Package.swift) a quran/mobile-sync tag?"
fi

kotlin_version="$(single_match 's/^[[:space:]]*native-coroutines[[:space:]]*=[[:space:]]*"([^"]+)"[[:space:]]*(#.*)?$/\1/p' "$toml_file")"
if [[ -z "$kotlin_version" ]]; then
  fail "Couldn't read the native-coroutines version from ${toml_url}: expected one 'native-coroutines = \"…\"' line."
fi

if [[ "$swift_version" != "$kotlin_version" && "$update" == true ]]; then
  KOTLIN_VERSION="$kotlin_version" perl -0pi -e \
    's{("https://github\.com/rickclephas/KMP-NativeCoroutines\.git"\s*,\s*exact:\s*")[^"]+"}{$1$ENV{KOTLIN_VERSION}"}' \
    Package.swift
  echo "Set KMP-NativeCoroutines from ${swift_version} to ${kotlin_version}, native-coroutines in mobile-sync v${remote_version}."
  exit 0
fi

if [[ "$swift_version" != "$kotlin_version" ]]; then
  fail "KMP-NativeCoroutines mismatch: Package.swift pins the Swift package at ${swift_version}, but mobile-sync v${remote_version} (remoteVersion) builds Shared with the Kotlin plugin at ${kotlin_version}. Change the KMP-NativeCoroutines 'exact:' version in Package.swift to \"${kotlin_version}\", or run $0 --update."
fi

echo "KMP-NativeCoroutines ${swift_version} matches native-coroutines in mobile-sync v${remote_version}."
