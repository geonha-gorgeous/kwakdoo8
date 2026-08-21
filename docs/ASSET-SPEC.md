# Asset specification

`kwakdoo8` uses the custom Pet v2 sprite contract.

- `spriteVersionNumber`: `2`
- columns: `8`
- rows: `11`
- cell size: `192 × 208`
- atlas size: `1536 × 2288`
- format: transparent WebP
- required row frame counts: `6, 8, 8, 4, 5, 8, 6, 6, 6, 8, 8`

Each version directory contains a complete installable package:

```text
versions/<version>/<pet-id>/
├── pet.json
└── spritesheet.webp
```

The package directory name matches the `pet.json` ID. It is `dupal` in v1 and `doopal` from v2 onward. The v2 identity change is intentionally breaking; compatible revisions after v2 keep `doopal` stable.
