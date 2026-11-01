#!/bin/zsh
# Сборка для симулятора без подписи. Выводит ошибки и предупреждения.
set -o pipefail
cd "${0:A:h}"
xcodegen generate --quiet >/dev/null || { echo "XcodeGen failed"; exit 1; }
xcodebuild -project MoiFinansy.xcodeproj -scheme MoiFinansy \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO build "$@" 2>&1 | tee build/last-build.log | grep -E "(error|warning):|BUILD (SUCCEEDED|FAILED)|license" | grep -v "appintentsmetadataprocessor" | sort -u
