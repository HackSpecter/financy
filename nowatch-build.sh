#!/bin/zsh
# Временная сборка без Apple Watch (пока не установлена платформа watchOS).
set -o pipefail
cd "${0:A:h}"
python3 - <<'PY'
s = open('project.yml').read()
s = s.replace('''      - target: HisobWatch
        copy:
          destination: productsDirectory
          subpath: "$(CONTENTS_FOLDER_PATH)/Watch"
''', '')
s = s.replace('name: MoiFinansy\n', 'name: MoiFinansyNoWatch\n', 1)
open('.project-nowatch.yml', 'w').write(s)
PY
xcodegen generate --spec .project-nowatch.yml --quiet >/dev/null || { echo "XcodeGen failed"; exit 1; }
rm .project-nowatch.yml
xcodebuild -project MoiFinansyNoWatch.xcodeproj -scheme MoiFinansy -destination "${DEST:-generic/platform=iOS Simulator}" \
  -derivedDataPath build/DerivedDataNoWatch CODE_SIGNING_ALLOWED=NO ${ACTION:-build} 2>&1 | tee build/last-nowatch.log \
  | grep -E "✘|error:|warning:|Test run with|TEST (SUCCEEDED|FAILED)|BUILD (SUCCEEDED|FAILED)" | grep -v appintentsmetadataprocessor | sort -u | head -40
