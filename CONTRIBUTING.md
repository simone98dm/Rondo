# Contributing to Rondo

Thanks for helping! Bug reports, ideas, docs fixes and code are all welcome.

- **Found a bug or have an idea?** [Open an issue](https://github.com/simone98dm/Rondo/issues/new/choose) with the matching form.
- **Security problem?** Don't open an issue. See [SECURITY.md](SECURITY.md).
- **Want to write code?** Issues labelled [`good first issue`](https://github.com/simone98dm/Rondo/labels/good%20first%20issue) are a good start. For anything bigger than a small fix, open or comment on an issue first so we agree on the approach before you spend time on it.

Everyone taking part follows the [Code of Conduct](CODE_OF_CONDUCT.md).

## What Rondo is (and isn't)

Rondo is a small, native, private menu bar utility. A few rules keep it that way, and changes that break them won't be merged:

- **No analytics and no new network calls.** The only request Rondo makes is the daily update check against GitHub releases, which can be turned off.
- **No third-party Swift dependencies** in the app. Command-line tools the user installs (Mole, ffmpeg, cwebp) are run as separate programs and are always optional; their source is never copied into Rondo.
- **Nothing destructive without a preview and a confirmation.** Disk Clean always shows Mole's dry run before cleaning, and deletes nothing itself.
- **Every feature works with the keyboard and VoiceOver.** Each control has an accessibility label.
- **Ask for permissions only when a feature needs them**, and keep the rest of the app working without them.

## Set up

You need:

- A Mac on **macOS 26.5** or later and the latest **Xcode** (from the App Store or developer.apple.com).
- Optional, for the features that use them: `brew install mole ffmpeg webp`.

```bash
git clone https://github.com/simone98dm/Rondo.git
cd Rondo
open Rondo.xcodeproj        # then ⌘R
```

### Code signing

No Apple developer account is needed. Builds are signed **ad hoc** ("Sign to Run Locally") through `Config/Signing.xcconfig`.

macOS ties privacy permissions to an app's signature, and an ad-hoc signature changes on every build. So after rebuilding, you may have to grant **Accessibility** or **Screen Recording** again (System Settings → Privacy & Security: remove Rondo with −, then add it again).

To avoid that, sign with your own team:

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig   # gitignored
# then set DEVELOPMENT_TEAM to your team ID in Config/Local.xcconfig
```

Don't change `DEVELOPMENT_TEAM` in the Xcode project itself; that would end up in your pull request.

## Project layout

Each feature lives in `Rondo/Modules/<Feature>/` (logic, services and views together); shared code is in `Rondo/Shared/`. The file conversion engine is a separate local package, `Packages/RondoCore`. The README has the [full layout](README.md#project-layout).

A few project settings to know:

- The app target uses **MainActor by default** (`SWIFT_DEFAULT_ACTOR_ISOLATION`). Pure value types and parsers that tests call off the main actor need `nonisolated`.
- Folders are **synchronized groups**: a new `.swift` file in `Rondo/` or a test folder is part of the target automatically, with no project file edit.
- The project has its own `ProcessInfo` model; write `Foundation.ProcessInfo` for the system one.
- Launch flags such as `--demo-data`, `--isolated-defaults` or `--open-settings=<pane>` open a specific state quickly (the README lists them all). `--isolated-defaults` keeps your real settings untouched.

## Making a change

1. Fork the repo and create a branch from `main`: `feature/<short-name>`, `fix/<short-name>` or `chore/<short-name>`.
2. Make the change, with tests (see below).
3. Format the Swift files you touched: `./scripts/format.sh`.
4. Update the README (and `docs/` for the website) if behaviour, settings or permissions change. Run `./scripts/screenshots.sh` when a screenshot is out of date. It quits any running Rondo first.
5. Add a line under **Unreleased** in [CHANGELOG.md](CHANGELOG.md) for anything a user would notice.
6. Open a pull request and fill in the template.

### Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org): `type: description`, where type is one of `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`.

```
feat: add treemap view to Disk Clean overview
fix: keep the active tab fill inside the button
```

## Tests

```bash
./scripts/test.sh unit       # app unit tests (Swift Testing)
./scripts/test.sh packages   # RondoCore conversion tests
./scripts/test.sh ui         # UI tests
./scripts/test.sh            # all of the above, with coverage
```

- New logic needs unit tests in `RondoTests/` (Swift Testing: `@Test`, `#expect`). Keep logic out of views so it can be tested: parsers, state machines and geometry are plain types.
- Code that runs external tools takes an injectable runner, so tests never call the real tool (see `MoleService` and `FakeMole` in `RondoTests/MoleTests.swift`).
- **UI tests** move the mouse and need **Accessibility** and **Screen Recording** for Xcode or your terminal. CI can't grant those, so it runs only the unit and package tests. Run `./scripts/test.sh ui` yourself when you change UI.
- Never run real destructive commands in tests (`mo clean`, `mo optimize`, file deletion outside a temporary directory).

## Style

- Formatting follows `.swift-format` (4 spaces, 160 columns). `./scripts/format.sh` formats the files changed on your branch; `./scripts/format.sh --check` only reports. CI shows the report on every PR but doesn't fail on it yet.
- Prefer small files grouped by feature, small functions, early returns and immutable values.
- Name things for what they do. Booleans read as questions (`isInstalled`, `hasOnboarded`).
- UI text is short, plain and sentence case. Use "…" on buttons that open a window or ask for confirmation.

## Releases

Releases are made by the maintainer with `./scripts/release.sh` (see [Releasing](README.md#releasing)). Each release moves the **Unreleased** changelog entries under the new version.
