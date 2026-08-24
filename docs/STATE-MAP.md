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

## Processing transition

At session start, the app changes from `idle` to row `running`. In `v2.3.0`, the first and last processing frames are the exact cleaned idle frame. Doopal uses the screen-right paw for the full grooming sequence: paw lick, cheek wipe, forehead wipe, and return. The screen-left paw stays planted, while the head size, body scale, center, and floor baseline remain aligned with idle.

## Review transition

When work becomes ready for review, the app selects row `review`. In `v2.3.0`, Doopal lifts one front paw from his chest to his cheek and forehead before lowering it. The six-frame motion uses the idle anatomy and returns to an idle cell with zero pixel difference at both ends. Its visible height stays within `197-198 px`, its floor baseline within `y=201-202`, and its horizontal center within `x=94.5-96.5`.

## Drag transition

Rows `running-right` and `running-left` are selected while the Pet is dragged. In `v2.2.0`, Doopal hangs in the approved longer, naturally stretched scruff-pickup pose. His gaze matches the cursor direction: screen-right drag looks right and screen-left drag looks left. No human hand or cursor graphic is baked into the spritesheet.
