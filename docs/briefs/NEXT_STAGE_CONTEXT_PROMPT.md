# Hollow Choir — context for the next development stage (after V0.2.1)

Paste this into a new chat to continue. It suits the Director (ChatGPT) planning the next stage,
or a fresh engineering session (Claude) waiting for that plan. Repository: `hollow-choir`, branch
`dev`. The V0.2.1 work sits uncommitted in the working tree on top of commit `8d71810` ("V0.2")
unless it has since been committed.

---

You are continuing development of **Hollow Choir**, a 2D pixel-art RPG with reactive turn-based
combat. Each turn the player reads every enemy's declared intent, chooses a tactical action, executes
a short timing command, and defends in real time with Brace / Evade / Parry. Engine: **Godot 4.7.2,
GDScript**, no addons. Pillars: **READ · REACT · ADAPT · EXPERIMENT · AFFECT THE WORLD**. Hook:
"understanding an enemy is more powerful than out-leveling it."

## Where the project stands (version 0.2.1, 8 October 2026)

- **Built:**
  - a deterministic battle engine (`src/battle`, no Nodes): traits/effects/conditions as data,
    utility AI with three tactical difficulties and four execution assists, seeded replays;
  - data-driven content in `data/**/*.tres`: three starter loadouts, nine enemies, two familiars,
    eight encounters including the Mirebell Cantor boss, and the Flooded Ground and Spore Fog
    conditions;
  - a headless simulator CLI, the CombatSandbox (Practice/Lab) and a title/settings flow.
- **M1.1 combat clarity + V0.2 UI:** an icon-first combat UI with:
  - one immediate contextual inspector, per-icon explanations, and shared structured action and
    enemy-move cards;
  - explicit recipient review, a 400 ms preparation beat that shows the real timing UI, and
    condition announcements that dock to their header icon;
  - Cinder Pup art, textured bars, five window sizes, 75–200% text and reduced motion/flashing.

  Presentation follows `PresentationLedger` (never future engine state) and filtered typed
  readouts (`ActionReadout`, `IntentReadout`, `UnitReadout`).
- **V0.2.1:** an engineering cleanup with no design change. It removed dead UI scaffolding, applied
  one wheel-ownership rule, refreshed unit cards from their readout, and kept frozen battle text
  off Setup. It also added isolated QA tooling (`tools/qa_godot.py`), V0.2 capture states,
  `docs/` import hygiene, version 0.2.1 and release notes. Report:
  `docs/reports/V0_2_1_ENGINEERING_CLEANUP.md`.
- **Validation baseline:**
  - 179 scripts compile;
  - 187 tests pass with 1,696 assertions (~43 s);
  - the simulation smoke run is clean;
  - 96 seeded battles have byte-identical event streams before and after V0.2.1.

  Run `python tools/qa_godot.py --godot <Godot exe> --headless --script res://tests/run_tests.gd`.
  Expected diagnostics are four invalid-save fixture errors and one illegal-action warning.
- **Not built:** overworld, hub (Gloamstead), quests, corruption/world state, progression UIs,
  music playback (six candidates cataloged, none selected), expedition persistence.

## Roles and workflow

- **ChatGPT, Game Director:** design, balance models, scope, UI/UX direction, art consistency and
  UI integration (D-028).
- **Claude, Lead Gameplay Engineer:** engine and deterministic rules, the PresentationLedger and
  event-playback contract, input timing and graders, tools, tests, saves.
- The user relays between the two. Director output lands in `docs/design/*.md` (contracts),
  `docs/briefs/*.md` (handoffs using IMPLEMENTATION BRIEF / DATA CONTRACT / STATE FLOW / ACCEPTANCE
  TESTS / KNOWN EDGE CASES / NON-GOALS), and edits to `docs/DESIGN_DOCUMENT.md`, `docs/DECISION_LOG.md`
  and `docs/DESIGN_QUESTIONS.md`.
- Claude answers with `docs/reports/*.md` (files, architecture, data contract, public API, save
  impact, test procedure, limitations, extension points, questions).
- Nobody commits or pushes unless the user asks. Human gates are never claimed as passed by
  automated evidence.

## Read first

`docs/DESIGN_DOCUMENT.md` (its opening "Current design authority" section and the V0.2 section at
the end), `docs/DECISION_LOG.md` (D-028 to D-035), the current UI contracts
`docs/design/V02_UI_INTERACTION.md`, `V02_UI_FOLLOWUP.md`, `V02_SUPPORT_PRESENTATION.md` and
`V02_PRE_PUSH_POLISH.md`, then `docs/DATA_CONTRACTS.md`, `docs/TESTING.md`, `docs/RELEASE_NOTES.md`,
`docs/reports/V0_2_1_ENGINEERING_CLEANUP.md`, `assets/art/STYLE_GUIDE.md`, `assets/audio/AUDIO_CONTRACT.md`
and `docs/playtests/M1_1_SESSION_PACK.md`.
Prompts: `docs/CHATGPT_PROMPT.md`, `docs/CLAUDE_PROMPT.md`. Older reports and the return queue
describe superseded behaviour. Treat them as history, not requirements.

## Contracts to preserve

- Combat rules stay in the engine and rule functions. Widgets never compute damage, status chance,
  target eligibility, grades or reaction legality.
- Playback shows ledger state advanced event by event. Live engine state is read only at stable
  points. Unknown information stays unknown: knowledge gates come from `BattleKnowledge`.
- Timing: `begin(..., preparing=true)` → `PREPARATION_MS = 400` real time → `start_timing()` in
  the same widget. Fresh-press latches, assist pause and impact-centred reaction windows must hold.
  Simulated execution skips preparation.
- Pause and Setup requests during timing or playback queue to a safe point. Setup exclusively
  covers and hides the suspended battle and resumes directly.
- Saves: `save_version` 1, content IDs and explicit saved bindings are untouched by incidental
  work. `game_version` is informational.
- Presentation data (display scale, art crops, frames, layout) never affects targeting or outcomes.
  Art-off procedural fallbacks are intentional.

## Open gates and known issues

- **The M1.1 human clarity gate is open.** It needs fresh-player READ/REACT sessions using the
  session pack (its blank sheets are intentional). Also open: a physical-controller pass, a
  colour-vision and contrast review, comfort with the 400 ms preparation beat, 200% readability on
  a real monitor, artist cleanup approval of the generated sprites, and music audition/selection.
- The GDD rule still holds: **do not begin the world slice or expand enemy, weapon or system
  counts until the combat clarity gate passes.** The expedition resource candidate is a held paper
  proposal.
- Known small issues:
  - the 200% reaction help bar truncates its tail (R4, UI-owned);
  - the action and move cards duplicate their status-tile drawing;
  - `UnitDetails.describe` is used only by tests;
  - committed CRLF blobs will be renormalized by the next commit (consider a separate
    `git add --renormalize .` commit);
  - announced conditions are matched by display name;
  - `BattleScene` (~970 lines) still owns dock state, the timed flow and result text.

## What to do now

1. Restate the current state and constraints in a few lines, so we know the context is understood.
2. As Director, propose the **next stage** with explicit gate dependencies. Plausible candidates,
   which you should choose between and justify:
   - (a) run the M1.1 human clarity sessions and turn their findings into a scoped fix brief;
   - (b) a small V0.2.x follow-up (R4, the card status-tile helper, test migration, the line-ending
     commit);
   - (c) authorize audio selection plus a minimal playback hook on the existing Music/SFX buses;
   - (d) only once the gate passes, plan the first world/expedition slice and the expedition
     resource boundary.
3. Deliver the chosen stage as a handoff in the standard format, with the six headings above,
   acceptance tests and non-goals, and say which parts are Director work and which are Claude work.
   Flag any rule, balance or save change prominently. Do not assume any human gate has passed.
