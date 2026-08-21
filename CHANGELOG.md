# Changelog

All notable changes to the public Pet package are recorded here. Versions follow [Semantic Versioning](https://semver.org/).

## [2.1.0] - 2026-08-21

### Changed

- Replaced the hover jump with a seated yawn that starts and ends on the exact idle frame.
- Replaced left/right drag movement with a compact, hand-free scruff-pickup pose.
- Kept the Pet ID, sprite contract, and all unaffected state and look-direction pixels unchanged from `v2.0.0`.

### Fixed

- Matched left and right drag animations to the same neutral pickup frame.
- Stabilized body proportions and placement across the new drag and hover sequences.

## [2.0.0] - 2026-08-21

### Changed

- Renamed the Pet ID from `dupal` to `doopal` and the display name from `두팔` to `Doopal`.
- Rebuilt the final atlas around Doopal's approved appearance and proportions.
- Reworked processing into a calmer left/right-looking sequence.

### Fixed

- Stabilized body placement across cursor-facing frames to prevent jitter.
- Removed the visible magenta edge residue from transparent frames.
- Refined the jump transition frames and matched the jump's apparent body scale to idle.
- Updated the installer so v1 and v2 can replace each other with recoverable backups.

## [1.0.0] - 2026-08-21

### Added

- Initial public release of the `두팔` custom Pet.
- Nine standard state animations and sixteen look-direction frames.
- Version-selectable local installer with automatic backup of the active package.
