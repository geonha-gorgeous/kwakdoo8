# Standalone app

`Doopal.app` shows the Pet without the desktop app. The desktop app picks the row from task state, so a machine that rarely runs Codex only ever sees `idle`. The standalone app reads the same installed spritesheet and plays one random motion every few minutes.

It is a tool, not part of the published package. Sources live in `tools/doopal-solo/`.

## Requirements

- macOS 13 or later
- Xcode command line tools, for `swiftc`
- An installed Pet package, or this repository

## Install

```bash
./tools/doopal-solo/install-app.sh
```

The script builds `Doopal.app` and copies it to `~/Applications`. Start it from Spotlight or with `open -a ~/Applications/Doopal.app`. Stop it by right-clicking the Pet and choosing `Quit Doopal`. There is no Dock icon.

To start it at login, add `Doopal.app` under System Settings → General → Login Items. To uninstall, delete `~/Applications/Doopal.app`.

## Sprite source

The app uses the first match:

1. `${CODEX_HOME:-$HOME/.codex}/pets/doopal/`
2. `${CODEX_HOME:-$HOME/.codex}/avatars/doopal/`
3. `versions/<LATEST>/doopal/` in this repository

Installing another Pet version therefore also changes this app. Restart it to load the new spritesheet.

## Behavior

- `idle` is the default loop, at the same one-sixth speed the desktop app uses.
- Every 3 to 10 minutes one random motion plays three times, then the Pet returns to `idle`.
- Every non-idle row is equally likely, including the look directions. Rows are never weighted or filtered, so a release that redraws a row changes the Pet without changing this app.
- Hover plays `jumping` and dragging plays the matching drag row, as in the desktop app. A scheduled motion is skipped during hover or a drag.
- A motion started from the menu runs to the end. Hover cannot cut it short, since the pointer is necessarily over the Pet while the menu is open.
- The look directions appear here at random. The desktop app reserves rows 9 and 10 for the reply composer caret and the computer-use cursor, so it almost never shows them.

## Controls

Right-click the Pet.

| Item | Effect |
| --- | --- |
| Do a Random Action | Plays one motion now |
| Play All Motions | Every state, then all sixteen look directions |
| Pause Random Actions | Holds `idle` until resumed |
| Look Around Sometimes | Includes or excludes rows 9 and 10 |
| Show on All Desktops | Follows Mission Control Spaces and fullscreen apps |
| Size | 1×, 1.5× or 2× the desktop app's Pet width |
| Quit Doopal | Exits |

The Pet is one window on one display. Drag it anywhere, including to another display. Position and size persist in `~/Library/Application Support/doopal-solo/state.json`.

## Options

```text
--min-interval SEC   shortest wait between motions, default 180
--max-interval SEC   longest wait between motions, default 600
--scale N            size multiplier, 0.5 to 4
--no-look            never use rows 9 and 10
--single-space       stay on the Space the Pet was placed on
--verbose            log motions, hover and drags to stderr
--sprite PATH        use a specific spritesheet
--dump-frames DIR    write one PNG strip per state, then exit
--dump-icon DIR      write an app iconset, then exit
--selftest [N]       simulate N scheduling decisions, then exit
```

Flags override `~/.config/doopal-solo.json`:

```json
{ "minIntervalSeconds": 180, "maxIntervalSeconds": 600, "lookAround": true, "allSpaces": true, "scale": 1 }
```

## Development

```bash
./tools/doopal-solo/run.sh --min-interval 5 --max-interval 10
./tools/doopal-solo/run.sh --dump-frames /tmp/doopal-frames
./tools/doopal-solo/run.sh --selftest 500
```

`run.sh` rebuilds when the source is newer, then runs the binary. `--dump-frames` writes one strip per state, so a new atlas can be reviewed cell by cell. `--selftest` checks the interval range, the even spread across rows, and that no motion repeats back to back. Neither check needs a visible window or screen recording permission. Build output goes to `tools/doopal-solo/build/` and is not tracked.

The frame table in `DoopalSolo.swift` follows the row and frame counts in [the asset specification](ASSET-SPEC.md). A new sprite contract is the one change that also needs a change here.

## Why the desktop app cannot do this

Verified against ChatGPT 26.818.31338 on 2026-08-21.

- `pet.json` carries no behavior fields.
- The app picks the row from task and notification state. See [the state map](STATE-MAP.md).
- The renderer ships inside `app.asar`, whose SHA-256 is pinned by `ElectronAsarIntegrity` in the app's `Info.plist`, so a patched bundle does not launch.
- A custom Pet spritesheet is read once into a data URL, so replacing the file cannot change a running app.
