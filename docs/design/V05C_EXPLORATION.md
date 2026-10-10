# V0.5C — Listening stones and the outer seam

Director specification and placement · 10 October 2026 · application 0.5.0 / save 1.
This accepts the backend proposal with adjusted, physically tested placements. Together with
[V0.5B](../briefs/V0_5B_BACKEND_HANDOFF.md), this is the bounded integrated V0.5 scope.

| Content | Player purpose / decision | Systems / cost | Failure case / cheaper reuse |
|---|---|---|---|
| Iron seam | Reward taking the outer path; carry a spare reagent home | One gathering definition, one claim, a static prop | Once per save prevents reset farming; reuse Bog Iron, no respawn timer |
| Listening stones | Read a clue and experiment with an ordered response | Existing rune grammar, three markers, saved feedback | No hearing/timing gate; mistakes cost no item or HP; no bespoke puzzle engine |
| Drowned niche | Recognize a changed place and return with an alternative garb | Existing secret reveal, claim, inventory and preparation | Hidden before solve, no repeated grant; reuse Fenrunner Leathers and its existing trait |

The rhythm reveals the niche; solving grants no direct reward. Searching grants the existing
Fenrunner Leathers once. The seam grants one Bog Iron once: total route materials become five
Bog Iron and one Storm Salt against the unchanged three-iron/one-salt purchase budget.
All three features are optional; the bell and return route work independently.

## Exact placement

All positions are in Briarfen Reedway, with 32 px tiles. Existing painted terrain, paths,
footprints and safe anchors are preserved. New markers live under `Interactions/<id>` and
presentation under `LowDecoration`; they are low, walkable stone surfaces rather than new walls.

| ID | Tile | Scene position | Interaction radius |
|---|---|---|---|
| `iron_seam` | (11, 38) | (368, 1232) | 48 |
| `rhythm_stone_low` | (82, 40) | (2640, 1296) | 36 |
| `rhythm_stone_mid` | (84, 42) | (2704, 1360) | 36 |
| `rhythm_stone_high` | (86, 40) | (2768, 1296) | 36 |
| `drowned_niche` | (86, 42) | (2768, 1360) | 36 |

The production feet-body test walks from the fork along the outer boards to the seam and from
the existing listening-stones anchor to every rune and the niche. The clue remains on the
original standing-stone landmark. New gathering/secret/rune interactions do not move the safe
resume anchor; quitting resumes at the previous safe place, retaining saved attempts and rewards.

## Grammar, state and presentation

- Low → high → middle. Confirm strikes immediately, without dialogue or a reaction clock.
- Each strike makes one atomic save. A mistake clears the attempt; striking low when it is wrong
  begins a new one-step attempt. The saved result alone drives feedback.
- The original stones state the entire order in text. One, two and three incisions distinguish
  low, middle and high without relying on color. The prompt shows saved progress; saved lit
  etchings persist after reload. Solved etchings remain lit until Reset journey.
- A mistake gives a readable, static message and clears attempt lights. There is no flashing,
  camera shake, sound-only clue, timed input or penalty. Low/middle/high have soft material tones
  on the existing SFX bus. No gameplay RNG is used for these tones.
- `WorldStateView` sources GATHERED, FOUND, SOLVED and RUNE_LIT own all scene visibility. No UI
  widget stores puzzle truth or receives the solution. A niche and its wrapping are hidden until
  solved; the wrapping disappears after finding. The seam darkens after gathering.
- Gathering and searching use dialogue with deliberate actions, followed by saved receipt cards.
  Failed writes reveal nothing, grant nothing and play no successful strike. Retry repeats the
  original command; a failed final strike retains the old attempt until saved.

## Persistence decision

Gathered nodes remain gathered through Reset journey. Found secrets, solved puzzles and rune
attempts reset. All reward claims, owned gear, bag expansion, materials, recipes and fittings
remain. Solving/finding again grants nothing. New Game is a new save and starts without these
accomplishments. The Reset journey card explains these distinctions.

## Acceptance

Production content validation, feet traversal, hidden-secret perception, scene visibility,
mistake/solve feedback, save failure/retry, reload/reset and no-repeat claims have automated
coverage in `test_world_v05_integration`. Existing backend suites retain independent grammar,
transaction and second-puzzle coverage. Gate chimes stays test-only. Human play, art fit,
controller operation and listening remain Adrian's gates; automated evidence does not pass them.
Pressure, quests, bosses, new regions and additional puzzle grammars remain later work.
