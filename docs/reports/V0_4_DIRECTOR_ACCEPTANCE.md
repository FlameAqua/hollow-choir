# V0.4 First Footsteps — Director integration and acceptance

Director / UI integration · 9 October 2026 · `dev` after `6d8401d`

**Disposition: presentation integrated; ready for Adrian's human acceptance sessions.** This is
not a release approval or a passed human gate. Claude's world backend and the earlier display,
HUD, art and design work are preserved. Nothing was committed, pushed or reset. Application
version remains **0.3.0**, save version **1**. The original
[engineering review](V0_4_ENGINEERING_REVIEW.md) remains the backend evidence and interface reference.

## Decisions 1–6

| Requested decision | Director decision and reason |
|---|---|
| 1. Guard placement | **Move onto the bell steps near tile (62,22).** `GuardGroup` feet are now (2000,736), its `Interactions/bell_guard` point (2000,720). The planning tile matches. Keep the existing safe approach anchor. The outside-loop junction and far-side latch route can now be explored without an unsolicited guard card. Walking toward the bell still opens Engage / Leave; only guard victory permits ringing. |
| 2. Defeat stats | **Confirm: record nothing, including `battles_lost`.** Earlier committed progress survives. Retry uses the exact captured entry; Return to Gloamstead closes that entry without a failed-attempt award or penalty. |
| 3. Threat categories | **Keep “Patrol” and “Guard”.** They explain spatial function without leaking species or promising a difficulty tier. Known species still come exclusively from the filtered readout. |
| 4. Copy | **Finalize the runtime text.** Retain the approved Bellkeeper/bell/stones dialogue, objective lines and resource rule. Consolidate prompt templates in `WorldCopy`; approve the current Talk / Use / Approach / Examine / Look verbs. Revise far-side/open latch, save explanation/failure and victory/defeat bodies; refine landmark descriptions and make the restored square's map description reflect the existing bell flag. The town bell stays a visible consequence with no interaction. No extra dialogue is needed. |
| 5. Menu wording | **Confirm “Save” and “Save and return to title”.** Title return saves first. The separate failure card's “Return to title” makes no save promise. The menu explains safe-place resume and mid-battle quitting. |
| 6. Version | **Keep 0.3.0 now.** Recommend 0.4.0 after Adrian accepts the integrated walkthrough and any resulting fixes. Save version stays 1. No commit or push is authorized by this note. |

## What changed

- The world frame now has a fixed title, independently scrolling content and fixed closing/actions
  controls. Dialogue sits low enough to leave the speaker in view. The paused menu puts actions
  in a vertical column beside three short save/resume paragraphs. Directional and Tab navigation
  stay within each modal. The host's explicit CanvasLayer theme assignment is retained.
- Encounter cards present group size, compact repeated creature names, separately framed authored
  conditions, the resource rule and a free-leave explanation. `WorldEncounterView` consumes only
  `EncounterCardReadout`; it does not look up hidden species, stats, weaknesses or eligibility.
- The bench places the three owned starter weapons beside their complete shared descriptions and
  actions. “equipped” changes only after a successful save. All sword, hammer and bow text fits at
  22 px on the canonical canvas; Close stays fixed.
- The chart uses numbered discovered landmarks and a separate scrolling list, eliminating
  overlapping map names. A diamond identifies the player; lines show walked links. Focus and
  pointer/Confirm selection update the description and selected marker, never position or saves.
  Unknown space remains blank, and the backend continues to filter undiscovered/gated facts.
- The Field Guide's empty state now explains research from journey victories as well as the Lab
  recording option. Practice remains unrecorded.
- Existing area scenes were edited directly, without rebuilding their layouts. Boardwalk cells
  now occupy `GroundDetail` over peat; native shoreline meshes join the banks. Deterministic tile
  flips break some repeated texture, and detached town roofs overlap their wall tops by another
  eight world pixels. Facade footprints and lots stay as engineered.
- The reed gate reuses two source-post regions along the fence, leaving the east–west passage
  visibly empty. Town/wayside bell frames and the lamp post reuse the quiet asset outside small
  changing regions, so restoration no longer replaces unrelated timber/stone/post pixels.
- At 2×, Hollow's art and camera share a rounded world-pixel position; the feet retain continuous
  physics precision. The 24 px upward camera offset and area clamps stay in place. Motion shimmer
  still needs human observation, especially at non-integer output scaling.

Exploration music remains **intentional silence**; no area cue or new sound was selected.

## Rules and ownership

**No combat, reward, save-schema, retry, interaction eligibility or discovery rule changed.** The
only spatial behavior adjustment is the guard's relocated encounter radius/footprint. The added
restored-square description is derived presentation, not new state. Physics tile data was checked
byte-for-byte while dressing; portal nodes and all named safe anchors were retained. The authored
scenes still own geometry; `WorldRules` owns eligibility and `WorldSession` owns transactional writes.
Do not run the bootstrap with `--force` over these authored scenes.

## Verification and its limits

Final automated results are recorded below after running against a fresh project copy with isolated
user data. The full suite runs alone, without a concurrent capture or second Godot process.

| Check | Result |
|---|---|
| Pre-integration script baseline | 223 scripts, 0 failed |
| Existing world suites after integration | 39 passed, 0 failed, 785 assertions |
| Final script check | 225 scripts, 0 failed (fresh copy and final working-tree check) |
| Final full suite | 259 passed, 0 failed, 2,637 assertions (58.59 s; fresh copy) |
| World art validation | 204 checks, 0 failures |
| Simulation smoke | All encounters / MIXED / 10 runs / seed 1; exit 0, no errors |
| Python tooling tests | 9 passed (music preparation/import tooling) |
| Whitespace / scene ownership | Whitespace check passed; dressing retained collision tile bytes, portals and anchors |

Seven added presentation tests cover fixed action bounds/focus containment, all owned weapon text,
map pointer/Confirm selection and focus scrolling, actual feet-body traversal of the outside loop
to the closed far-side latch without either encounter card, guard confirmation on the bell steps,
integer presentation with subpixel physics, and restored-home map copy. They complement the existing
transaction, exact-retry, old-save, knowledge-leak, portal and latch tests; they are not human play.

Cold import completed, but this Windows sandbox emitted one **“Safe save failed”** editor diagnostic
at startup. This is not described as a clean cold-import pass. Content/script/test diagnostics and
capture teardown were also inspected: the full suite contains only its declared invalid-save,
rejected-action and world-sanitization diagnostics. Early synthetic-outcome captures could leak
the opening presenter's suspended coroutine; the harness now renders those notices over the world
without launching/interruption of a live battle. Final outcome captures completed without those
teardown errors. No user editor security or safe-save preference was disabled.

## Native visual evidence

All [Director captures](v0_4_director/README.md) are actual Godot renders with in-memory seeded state,
direct placement/opening of UI and a dummy audio driver. They do not measure a completed journey,
human comprehension, controller comfort, timing, listening or playtime.

The canonical captures are 1280×720. Additional restored-map captures cover requested 1366×768
(the game-content texture is 1365×768 within that aspect-constrained window), 1600×900 and
1920×1080. A requested 2560×1440 window fell back to 1920×1080 under the existing usable-screen
policy on this machine; that image is labelled as a fallback, **not 1440p verification**.

The world art remains an integrated **candidate pack**, not finished pixel cleanup. Native component
reuse addresses state-change consistency and gate orientation; source walk/idle contours, residual
terrain seams/repetition and the willow canopy's clipped source edge still need artist/human review.
No generated source or atlas PNG was overwritten. A new art generation/cleanup pass should version
its exports and provenance rather than change collision to match alpha.

## Human acceptance sessions Adrian should run next — all OPEN

1. **Uncoached first journey, keyboard.** Use a fresh disposable profile and Continue journey.
   Find the Bellkeeper, compare the three bench weapons, depart, identify the fork and find the
   outside loop without instructions. Scout to the latch without fighting, return to the bell
   approach, deliberately engage the guard, ring the bell, open the shortcut and come home.
   Ask the player what changed at home and how they would return to the fen. Record uncertainty,
   wrong turns, time and any coaching; the 10–15 minute target is still unmeasured. Repeat the
   bell errand before speaking to the Bellkeeper to confirm the acknowledgement makes sense.
2. **Controller and remapped traversal.** Walk both routes using stick and D-pad; test diagonal
   corners, walls, both portals and near/far latch sides. Cancel and reopen each encounter card;
   browse every weapon, all seven map places, Field Guide and Settings. Remap interact/map/menu,
   swap devices and check prompts. Hold movement/Confirm while closing a modal or crossing a
   portal, then release/repress. Alt-tab and return. Look for focus escapes, double activations,
   unreachable text, camera jumps and shimmer. Automated input checks do not pass this session.
3. **Real-profile-copy persistence.** Keep the original profile untouched. On a copy of an old V0.3
   slot, verify research/practice/loadout before and after first world entry. Quit/reload after
   arrival, weapon choice, victory, bell restoration, latch opening, explicit Save and Save and
   return to title. Quit once mid-battle; deliberately lose, retry and return home. Confirm clear
   groups stay absent, earlier progress survives and defeats add no loss stat. Any save-failure
   exercise must use a disposable fixture/profile, never damage the real save to manufacture it.
4. **Display and art walkthrough.** Check 720p and the output presets the display can actually
   support, including 1440p on a suitable display, plus fullscreen letterboxing. Read dialogue,
   every weapon and both encounter cards at normal viewing distance. Inspect gate clearance,
   roofs/footprints, banks, the quiet/restored bells and lamp, and canopy/player occlusion while
   moving. Review reduced-motion behavior and integer/non-integer scaling separately.
5. **Continue the separate M1.1 clarity and listening gates.** Use the existing
   [combat session pack](../playtests/M1_1_SESSION_PACK.md), identified as the integrated candidate,
   for READ/REACT/ADAPT observations and manual controller combat. Audition the actual battle
   playlists/transitions with sound enabled. World silence is the approved presentation choice;
   dummy-audio captures provide no listening evidence. The aligned-audio pilot remains separate
   and was not started.

Record the branch/base commit, working-tree identity, profile copy, device/bindings, output preset
and assist choices with each session. Accept or fix observed issues before the 0.4.0 decision.
The [Claude continuation brief](../briefs/V0_4_POST_INTEGRATION.md) preserves this boundary.

