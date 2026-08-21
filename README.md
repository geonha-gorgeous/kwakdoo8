# kwakdoo8

`kwakdoo8` is a custom black-and-white cat Pet for the ChatGPT/Codex desktop app, modeled after 곽두팔 (두팔, [@kwakdoo8](https://www.instagram.com/kwakdoo8/)).

The public repository contains only the distributable Pet package, versioning metadata, and installation documentation. Private source photos, personal workspace notes, and rejected generation artifacts are intentionally excluded.

![두팔 Pet contact sheet](docs/contact-sheet.png)

## Install

Requirements:

- macOS
- ChatGPT/Codex desktop app with custom Pet support
- Bash

Clone the repository and install the latest published version:

```bash
git clone https://github.com/geonha-gorgeous/kwakdoo8.git
cd kwakdoo8
./scripts/install.sh
```

Restart or refresh the desktop app, then select `Doopal` from the Pet list.

## Install or roll back to a specific version

Every released package is immutable under `versions/`. Reinstalling an older version provides a deterministic rollback:

```bash
./scripts/list-versions.sh
./scripts/install.sh v2.1.0
./scripts/install.sh v2.0.0 # roll back to the previous motion set
./scripts/install.sh v1.0.0 # roll back to the previous identity
```

Before overwriting the active package, the installer saves it under:

```text
~/.codex/pets/.<pet-id>-backups/<timestamp>/
```

When switching between v1 and v2, it also moves the replaced `dupal` or `doopal` directory into the matching backup directory. Git tags and GitHub Releases use the same semantic version, such as `v2.0.0`.

## Current release

- Version: `v2.1.0`
- Pet ID: `doopal`
- Display name: `Doopal`
- Sprite contract: v2
- Atlas: 8 columns × 11 rows
- Cell: 192 × 208 px
- Full spritesheet: 1536 × 2288 px
- Format: transparent WebP
- SHA-256: `fe7fd8f267bf83fcd5c9b2da6c61fa79c9489f446fbbe3c0016160afe1474138`

`v2.1.0` keeps the stable `doopal` identity and v2 sprite contract. Hover now plays a seated yawn that starts and ends on the exact idle frame. Cursor dragging uses a compact, hand-free scruff-pickup pose for both directions, with a shared neutral start and stable body proportions. All other state and look-direction pixels remain unchanged from `v2.0.0`.

See [the state map](docs/STATE-MAP.md) for the animation semantics and [the asset specification](docs/ASSET-SPEC.md) for the row contract.

## Development and releases

Released directories are immutable. A visual revision gets a new semantic version and Git tag, so an experiment can always be undone by reinstalling the previous version. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
