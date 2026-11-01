#!/bin/zsh
# Unit-тесты на симуляторе. Выводит только упавшие проверки и итог.
set -o pipefail
cd "${0:A:h}"
xcodegen generate --quiet >/dev/null || { echo "XcodeGen failed"; exit 1; }
xcodebuild -project MoiFinansy.xcodeproj -scheme MoiFinansy \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO test "$@" 2>&1 | tee build/last-test.log \
  | grep -E "✘|error:|warning:|recorded an issue|Expectation failed|Test run with|TEST (SUCCEEDED|FAILED)|license" | grep -v "appintentsmetadataprocessor" | head -60
