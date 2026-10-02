#!/bin/sh
# The licensed car pack and key are local inputs, never public Git assets.
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
if [ ! -f "$root/Sources/GeneratedArtKeys.swift" ]; then
  printf 'import Foundation\nenum GeneratedArtKeys { static let keys: [String:Data] = [:] }\n' > "$root/Sources/GeneratedArtKeys.swift"
fi
xcodegen generate --spec "$root/project.yml"
