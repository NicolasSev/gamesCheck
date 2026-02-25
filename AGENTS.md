# AGENTS.md

## Cursor Cloud specific instructions

### Project Overview

**Fish & Chips** (formerly PokerCardRecognizer / gamesCheck) is a native iOS app (Swift / SwiftUI) for poker game management, player statistics, and card recognition. It uses Core Data for local persistence, CloudKit for cloud sync, and XCTest for unit tests.

**There is no package manager** (no CocoaPods, SPM, npm, pip). All dependencies are Apple-native frameworks. Building, running, and full testing require **macOS with Xcode 14+**.

### Linux Cloud VM limitations

This codebase cannot be compiled or run on Linux. The iOS Simulator, `xcodebuild`, and XCTest all require macOS. However, two tools are available:

| Tool | Command | What it does |
|------|---------|--------------|
| **SwiftLint** | `swiftlint lint --quiet` | Style/convention linting of all `.swift` files |
| **Swift syntax check** | `swiftc -parse <file.swift>` | Syntax verification for files that don't import iOS-only frameworks |

Both require the Swift toolchain. The update script installs Swift 6.0.3 and SwiftLint 0.57.1 automatically. After the update script runs, environment variables (`PATH`, `LD_LIBRARY_PATH`) are set in `~/.bashrc`; open a new shell or `source ~/.bashrc` to pick them up.

### Running lint

```bash
source ~/.bashrc
swiftlint lint --quiet          # all files, warnings + errors
swiftlint lint --quiet --strict # treat warnings as errors
```

The project has no `.swiftlint.yml` config, so default rules apply. As of the initial setup, there are ~57 pre-existing errors (mostly `type_body_length` and short `identifier_name`) and ~2800 warnings (trailing whitespace, line length, etc.). These are style issues, not compilation errors.

### Swift syntax checking (standalone files)

Files that use only Foundation (no SwiftUI/CoreData/CloudKit imports) can be syntax-checked:

```bash
source ~/.bashrc
swiftc -parse FishAndChips/Services/PokerOdds/PokerOddsModels.swift
```

Files importing iOS frameworks will fail with "no such module" — this is expected on Linux.

### Key project documentation

- `docs/MASTER_PLAN.md` — single source of truth; read before any task (per workspace rules)
- `docs/DATA_DIAGRAM.md` — Core Data / CloudKit schema
- `docs/CLOUDKIT_MANUAL_SETUP_REQUIRED.md` — CloudKit dashboard setup
- `README_PRODUCTION.md` — production overview and deployment steps

### Project structure

```
FishAndChips/           # App source (113 .swift files)
  Services/             # CloudKit, GameService, Notifications, etc.
  Views/                # SwiftUI views
  ViewModels/           # MVVM view models
  Models/               # Core Data + CloudKit model extensions
  Camera/               # ML card recognition (YOLOv8)
  Repository/           # Repository pattern abstraction
FishAndChipsTests/      # 11 XCTest files (43 unit tests)
FishAndChipsUITests/    # 2 UI test files
FishAndChips.xcodeproj/ # Xcode project (FishAndChips scheme)
docs/                   # Project documentation
```

### Workspace rules reminder

The `.cursor/rules/master-plan.mdc` file requires:
1. Always read `docs/MASTER_PLAN.md` before starting work
2. Respond in Russian
3. Do not create `.md` files without explicit user permission
4. Update `docs/DATA_DIAGRAM.md` when changing data structures
