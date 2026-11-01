# Contributing

## Setup

```bash
brew install xcodegen
cp Config/Local.xcconfig.example Config/Local.xcconfig   # your Apple team ID, for device builds
xcodegen generate
open MoiFinansy.xcodeproj
```

Requires Xcode 27. The `.xcodeproj` is generated from `project.yml` and is not committed.

## Rules

- `main` is protected: all changes go through a Pull Request, and CI must pass.
- Work on a branch, one topic per PR.
- Before opening a PR run `./build.sh` and `./test.sh`: no errors, no warnings, tests pass.
- Add tests for any logic change, especially money and SMS parsing.
- Money is `Decimal` only. `Double` is allowed only for drawing charts.
- Never commit real SMS, card numbers, balances, team IDs or keys. Use made-up data.
- Do not change Quran text files by hand. Regenerate them with `tools/build_quran_data.py`.

Issues and PRs in Russian or English are welcome.
