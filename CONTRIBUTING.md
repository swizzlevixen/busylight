# Contributing to Busy Light

Thanks for your interest in contributing! This is a small, single-maintainer project, so the process is lightweight.

## Development Setup

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
2. Generate the Xcode project: `xcodegen generate`
3. Open `BusyLight.xcodeproj` in Xcode, or build from the command line:

```bash
xcodebuild -project BusyLight.xcodeproj -scheme BusyLight build
```

Run tests:

```bash
xcodebuild test -project BusyLight.xcodeproj -scheme BusyLight -destination 'platform=macOS'
```

## Requirements

- **Swift 6** with strict concurrency enabled
- **macOS 14.0** minimum deployment target
- No third-party dependencies without prior discussion

## Submitting Changes

1. Open an issue first to discuss what you'd like to change.
2. Fork the repo and create a branch from `main`.
3. Make your changes, keeping commits focused and well-described.
4. Ensure all tests pass before opening a PR.
5. Reference the related issue in your PR description.

## Code Style

The existing codebase is the style guide. Key patterns:

- `@MainActor` on all UI and `@Observable` classes
- `async`/`await` over closure-based APIs
- SwiftUI for the Settings window, AppKit for the menu bar
- No force unwraps or force `try` unless truly unrecoverable

## Questions?

Open an issue if anything is unclear. Contributions of all sizes are welcome.
