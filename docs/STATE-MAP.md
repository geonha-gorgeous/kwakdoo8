# Pet state map

The current desktop app selects rows from the spritesheet according to Pet and task state.

| Row | State | Meaning |
| ---: | --- | --- |
| 0 | `idle` | Calm default loop |
| 1 | `running-right` | Pet movement toward screen right |
| 2 | `running-left` | Pet movement toward screen left |
| 3 | `waving` | Greeting |
| 4 | `jumping` | Hover/playful jump |
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
