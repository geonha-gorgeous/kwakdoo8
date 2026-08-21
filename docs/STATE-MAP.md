# Pet state map

The current desktop app selects rows from the spritesheet according to Pet and task state.

| Row | State | Meaning |
| ---: | --- | --- |
| 0 | `idle` | Calm default loop |
| 1 | `running-right` | Cursor drag toward screen right; hand-free scruff-pickup pose |
| 2 | `running-left` | Cursor drag toward screen left; hand-free scruff-pickup pose |
| 3 | `waving` | Greeting |
| 4 | `jumping` | Hover/seated yawn; the app state name remains `jumping` |
| 5 | `failed` | Failed task |
| 6 | `waiting` | Waiting for user input |
| 7 | `running` | Task processing |
| 8 | `review` | Work ready for review |
| 9 | look directions `000°–157.5°` | Eight cursor-facing frames |
| 10 | look directions `180°–337.5°` | Eight cursor-facing frames |

## Hover transition

When the pointer enters the Pet, the app temporarily selects `jumping`. When the pointer leaves, it restores the underlying state that was active before hover:

- no active task → `idle`
- processing → `running`
- waiting for input → `waiting`
- ready for review → `review`
- task failure → `failed`

This behavior was verified against the installed desktop app build on 2026-08-21. It is controlled by the app rather than `pet.json`, so future app releases may change it.

## Drag transition

Rows `running-right` and `running-left` are selected while the Pet is dragged. In `v2.1.0`, both directions begin from the same neutral, cursor-implied pickup frame before the body hangs and sways toward the drag direction. No human hand or cursor graphic is baked into the spritesheet.
