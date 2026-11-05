# Changelog

All notable changes to Rondo are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Disk analysis and cleaning powered by [Mole](https://github.com/tw93/mole) (`brew install mole`). On first launch without Mole, Rondo opens Disk Clean with the install command to copy.
- Disk Clean **Overview**: free space, a donut of the home folder, heavy locations, and an explorer with a treemap or tree list view.
- Disk Clean **Clean** and **Optimize** modes, each showing Mole's dry run before you confirm.
- Disk tab donut chart of the home folder.

### Changed

- The Disk tab and Disk Clean window use Mole for every scan and cleanup.

### Removed

- The built-in disk scanner and cleaner, with its custom targets. Their saved settings are removed on launch.

### Fixed

- ⌘, opened an empty Settings window.
- The highlight of the selected tab or quick toggle didn't fill the whole button.

## [1.0.0] - 2026-10-25

First public release.

[Unreleased]: https://github.com/simone98dm/Rondo/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/simone98dm/Rondo/releases/tag/v1.0.0
