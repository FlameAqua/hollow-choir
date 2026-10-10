# V0.5B/C — Integrated presentation and exploration

**Historical B/C integration evidence.** Adrian's later UI review supersedes the station/Character
navigation described here. See [the current prototype report](V0_5_UI_PROTOTYPE.md),
[updated human checklist](../playtests/V0_5_INTEGRATED_TEST.md) and
[new backend assignment](../briefs/V0_5_UI_BACKEND_HANDOFF.md). B/C gameplay and original results remain valid.

Codex · 10 October 2026 · shared uncommitted `dev` · application 0.5.0 / save 1.

V0.5A/B/C is ready for Adrian's integrated human test. The Forge and Stillroom now have usable
station screens. The iron seam, listening rhythm and drowned niche are placed in the existing
Reedway, with saved visual feedback, written clues and three new soft stone cues. Read the
[complete A/B/C test sheet](../playtests/V0_5_INTEGRATED_TEST.md). Human gameplay, controller,
art and listening acceptance remain open.

The inherited V0.5A presentation and Claude's B/C rules are preserved. No commit, push, version
change, area regeneration, combat retune or new backend assignment was performed.

## Station integration

`WorldCraftingView` reads `session.crafting()` and emits command/recipe/fitting/potion IDs.
`WorldHost` sends purchase, refund, fit, remove and prepare through `_commit(write, then, rejected)`.
Affordability, mastery, ownership, potion locks and duplicate-trait eligibility remain backend
facts. A stale command refreshes the supplied rejection text; a failed write uses the existing
Retry save card and captures the exact command and selection. Success rebuilds from adopted state
and shows the spent/refunded materials, stock and any fitting cleared by refund. Read-only
navigation writes nothing; free fitting/potion re-choices remain backend no-ops.

The bench opens Equipment, Forge, Stillroom and Inventory. Services use the existing cloth,
leather-bag and gold-focus language with independent choice/detail scrolling and fixed action
buttons. Back returns to Equipment; Close ends the station context. Page Up/Down reads long
details. Mouse and keyboard focus are covered by production-host tests; hardware controller
acceptance belongs to the human test.

The Forge presents the exact two-iron kit cost, saved starter mastery and zero-mastery reason,
refund preview, Merciful Grip/Hollow Echo facts, remaining Pilgrim's Patience and the eight-action
count. Free fitting changes apply whenever Pilgrim's Edge is equipped. The Stillroom presents
Base/Reagent/Catalyst, free reusable bases, permanent recipe costs, source and unlock reason,
both potion slots and refilling charges. Inspecting a choice is separate from committing it.

Director decisions are recorded as D046/D047 in the Decision Log: two identical prepared potions
are rejected; duplicate traits are checked against the resulting active loadout in both
directions; inactive fittings do not count; legacy prepared advanced potions unlock their recipe
for free; no-op fitting/potion choices write nothing. Merciful Grip plus Pilgrim's Patience is a
human balance observation, with authored combat numbers retained. No concrete backend blocker
was found.

## Bounded C content

The [C specification](../design/V05C_EXPLORATION.md) accepts the proposed rewards and grammar
with adjusted placements. Production now has one once-per-save iron seam, three listening
stones and one puzzle-revealed drowned niche. The sequence reveals the niche without a direct
reward; Search grants existing Fenrunner Leathers once. Gather grants one Bog Iron once. Total
available materials are five iron and one salt against the unchanged three-iron/one-salt budget.
Gate chimes remains test-only. These optional features do not gate the bell route.

Every new marker has a tested interaction radius and reachable feet position. Production-host
tests physically walk from the existing fork along the outer boards to the seam, and from the
existing overlook anchor to every rune and the niche. No painted terrain, footprint collision
or safe anchor was regenerated. The original listening-stones clue gives the complete order.

Each Confirm strikes immediately and saves once. Saved progress drives the prompt, static HUD
feedback and incisions; mistakes explain the restart, clear attempt lights and cost nothing.
Solving displays the revealed place and lights the stones. `WorldStateView` owns GATHERED,
FOUND, SOLVED and RUNE_LIT visuals: the niche is hidden before solving, its wrapping vanishes
after Search, and the seam dims after gathering. There is no sound-only clue, timer, flashing
or new gameplay randomness. Failed writes grant/reveal nothing and play no success cue.

Gathered nodes remain gathered through Reset journey. Found secrets, solved puzzles and attempts
reset; all claims, materials, owned gear, bag growth, recipes and fittings remain. Solving and
searching again grants nothing. The Reset journey card states this policy. New interactions do
not move the safe resume anchor; saved rune attempts survive quitting and returning.

## Assets and captures

Six original native stepped SVG world assets and a Fenrunner Leathers item icon extend the
existing art language. Existing paintings, actors, terrain and menu frames are reused. Three
original procedural stone contacts append to the existing SFX palette; the original 25 WAVs
and cue indices are unchanged. These use the existing SFX bus, pooling and volume setting,
with normalization and looping off. Recorded PCM hashes/metadata were checked. This is technical
validation, with human listening pending; no LUFS, true-peak or audition claim is made.

Existing approved Gloamstead/Briarfen music is reused. No additional audio delivery is required
from Adrian. [Asset provenance](../art/EXPLORATION_V05.md) describes the native art and synthesis.
The small props remain candidates for human art review rather than final pixel-artist cleanup.

[Capture index](v0_5bc_presentation/README.md): 22 actual viewport PNGs, twenty at 1280×720 and two
at 1920×1080, opened and visually inspected. They cover locks, costs, traits, refund, receipts,
recipe ingredients, potion source, scrolling, clue, mistake/progress, reveal/search/reward,
gathering and reset copy. Text and fixed actions fit at both inspected resolutions. These are
isolated, seeded presentation fixtures with in-memory writers, not a human playthrough.

## Fresh verification

Godot 4.7.2 on Windows; all Godot checks use `tools/qa_godot.py` and workspace-local isolated
user-data homes. Complete suites ran alone. The normal player save was not used or modified.

| Check | Fresh result |
|---|---|
| Full suite, headless | **411 passed / 0 failed**, 6,416 assertions, 114.33 s |
| Full suite, hidden Compatibility / Dummy audio | **411 passed / 0 failed**, 6,440 assertions, 112.64 s |
| New production integration filter, Compatibility | **8 passed / 0 failed**, 119 assertions, 4.97 s |
| Script compilation, final tools included | **300 checked / 0 failed** |
| Material polish validation | **264 checks / 0 failures** |
| Python tooling tests | **10 tests OK**, workspace-local temporary directory |
| A demo | Exit 0: saved salvage/bell reward, equip charm, disk reload, Grounding adds Stagger and Break |
| B demo | Exit 0: purchase/reject/refund/rebuy/fit, disk reload, real Parry restores 8 HP, tincture adds 4 Focus, reset keeps unlocks |
| C demo | Exit 0: gather, mistake/solve/reveal/search, disk reload, reset and no-repeat grants on independent fixture |
| SFX manifest | All three SHA-256 hashes and mono/16-bit/44.1 kHz frame metadata match |
| Captures | 22 saved and visually inspected; no capture errors |
| Whitespace | `git diff --check` clean |

The eight new integration tests cover read-only navigation, typed locks, exact refund and
battle-entry preparation, purchase/fit/potion failed-write retry, preserved selection, stale
rejection, refund overflow, actual placement traversal, hidden-secret perception, restored
scene/prompt state, mistake/reveal feedback, failed final-strike retry, reload/reset and claims.

Initial integration runs exposed outdated test expectations that production still had only
three rewards, no exploration definitions and four iron. Those expectations now include the
accepted C content; the route test correctly keeps the unrevealed secret undiscovered. The
independent exploration fixture excludes production feature markers before authoring its own,
preserving separate grammar/validation coverage. The final full runs above include these fixes.

Claude's earlier **403/0**, determinism/simulation comparison and **42/42** mutation result remain
in the preserved backend reports. Those comparison/mutation checks were not rerun in this
presentation pass and are not fresh evidence. Historical reports' missing UI/unplaced-content
notes describe their return time. The current return queue and contracts point to this report.

## Reproduction

Substitute the local Python/Godot paths if they are not on PATH. Do not run another suite,
capture or editor import concurrently with a complete suite.

```powershell
python tools/qa_godot.py --godot <Godot-console.exe> --home .godot/qa/v05bc-headless --headless --script res://tests/run_tests.gd
python tools/qa_godot.py --godot <Godot-console.exe> --home .godot/qa/v05bc-rendered --hidden --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/run_tests.gd
python tools/qa_godot.py --godot <Godot-console.exe> --home .godot/qa/v05bc-capture --hidden --rendering-method gl_compatibility --audio-driver Dummy --script res://tools/capture_world.gd -- --state=forge-fitted --size=1920x1080 --out=res://docs/reports/v0_5bc_presentation/forge-fitted-1920.png
```

The [human checklist](../playtests/V0_5_INTEGRATED_TEST.md) is the remaining acceptance work:
fresh/older saves, all A/B/C content, preparation into actual battles, save/reload/reset,
mouse/keyboard and hardware controller, readability and listening. V0.6 remains later scope.
