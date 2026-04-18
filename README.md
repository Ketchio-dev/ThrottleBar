# ThrottleBar

ThrottleBar is a lightweight macOS menu bar app for capping CPU usage on a per-app basis.
It wraps the open source `cpulimit` tool with a native SwiftUI interface, persistent rules,
automatic re-application when apps relaunch, and optional launch-at-login support.

## What it does

- Lists running regular macOS apps from the menu bar
- Lets you add a CPU cap for each app
- Re-applies limits when the app restarts
- Tracks active `cpulimit` workers by PID
- Stores rules locally with no external services
- Optionally starts at login with `SMAppService`

## What it does not do

- It does not directly control wattage or package power
- It does not ship `cpulimit` inside the app bundle
- It is not Mac App Store ready; it is intended for direct distribution or source builds

## Requirements

- macOS 14 or later
- Xcode 26.4 or later
- Homebrew-installed `cpulimit`

Install `cpulimit`:

```bash
brew install cpulimit
```

## Build locally

Generate the Xcode project:

```bash
xcodegen generate
```

Build:

```bash
xcodebuild -scheme ThrottleBar -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Run tests:

```bash
xcodebuild -scheme ThrottleBar -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

Create a release zip:

```bash
./scripts/archive.sh
```

## CPU cap semantics

`cpulimit` uses percentage values that can exceed `100` on multi-core Macs.
In practice, `100` is roughly one full CPU core.
ThrottleBar keeps the UI close to that mental model instead of pretending it is a watt limit.

## Distribution notes

- `cpulimit` is GPL-licensed and is treated here as an external runtime dependency
- The generated app is unsigned by default
- For outside distribution, add your own Developer ID signing and notarization pipeline

## GitHub Actions

The repository includes:

- `.github/workflows/ci.yml` for build and test on pushes and pull requests
- `.github/workflows/release.yml` for manual or tag-driven release artifact generation

