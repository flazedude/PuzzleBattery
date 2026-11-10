#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift_bin="$(dirname "$(xcrun --find swiftc)")"
plugin="$swift_bin/../lib/swift/host/plugins/testing/libTestingMacros.dylib"
if [[ "$(xcode-select -p)" == */CommandLineTools && -f "$plugin" ]]; then
    swift test -Xswiftc -load-plugin-library -Xswiftc "$plugin" "$@"
else
    swift test "$@"
fi
