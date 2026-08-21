# Contributing

Thanks for helping improve Doopal.

## Versioning rules

1. Never edit a directory already published under `versions/`.
2. Create a new semantic version directory for every visual or metadata revision.
3. Keep the current Pet ID, `doopal`, stable unless the change intentionally creates a breaking identity release.
4. Update `LATEST`, `CHANGELOG.md`, checksums, and documentation together.
5. Validate the complete v2 atlas and visually review every state and direction before release.
6. Tag the release with the exact directory version, for example `v2.1.0`.

Use a patch version for packaging or metadata fixes, a minor version for compatible visual revisions, and a major version for a breaking sprite-contract or identity change.

## Privacy

Do not add private source photos, personal filesystem paths, raw workspace notes, credentials, or rejected private generation artifacts. Public contributions should contain only reviewable, redistributable assets and documentation.

## Testing an older version

```bash
./scripts/install.sh v1.0.0
```

Restart or refresh the desktop app and verify `idle`, hover `jumping`, task states, and cursor-direction tracking.
