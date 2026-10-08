# M1.1 Combat Clarity: technical proposal

Engineering owner: Claude. Written 8 October 2026 against the Director's
[implementation brief](../briefs/M1_1_IMPLEMENTATION.md) and
[specification](../design/M1_1_COMBAT_CLARITY.md). The brief is marked *ready for implementation*,
so this proposal does not wait for approval. It records the plan, and it flags the places where I
read the brief one way or had to change engine behaviour. Every flagged item is repeated in the
[report](../reports/M1_1_COMBAT_CLARITY.md) for the Director's ruling.

## 1. Requirements restated

| # | Requirement (brief order) | Acceptance |
|---|---|---|
| 1 | One typed, presenter-level knowledge policy shared by dock, intents, details and the reaction header. Unknown affinity hides every derived number, claim and formula. Preview scope is honest (direct hit / per target / words). Intent slots are stable, and hovering never replaces the selected action | F1-A…E |
| 2 | One decision dock for planning, commands and reactions. Labels follow the active device's bindings. A fresh press is needed between states. Focus loss freezes the clock. A pause during timing is queued. ReactionRules and CommandRules are preserved | F2-A…E |
| 3 | The existing event ledger is extended to Focus, statuses and familiar readiness. Condition consequences are visible, with the full rule on focus | F3-A…D |
| 4 | Practice and Lab are two views of one BattleSetup builder. Practice keeps its own fixed rules and the player's difficulty and assist | F4 |
| 5 | Optional SpriteFrames in UnitView, a staged backdrop in Battlefield, an optional familiar portrait, and placeholder fallback | F5 |
| — | Settings gain a Details *toggle* mode and a 200% text option. Absent keys load safely | brief, data contract |

## 2. Reused systems (unchanged unless listed in section 6)

BattleEngine requests and input log · `ActionPreview` / `IntentPreview` / `PreviewRules` (still exact)
· `ResearchRules.detail_level` + `revealed_affinities` · `ReactionSpec` / `CommandSpec` and their
graders · `BalanceConfig` · `InputBindings` · `BattleEvent` + `BattleEventPlayer` ledgers ·
`CombatantDefinition.sprite_frames` · `UnitFactory` instance suffixes (Thornhound A/B already
exist) · the four command widgets · `CombatSandbox` form and preferences · D-016 code-built UI.

## 3. Architecture

```text
src/ui/battle/presentation/          (new: pure presenter-side models, no Nodes)
  battle_knowledge.gd   BattleKnowledge  the single display-knowledge policy
  action_readout.gd     ActionReadout    + TargetReadout, StatusLine: filtered outgoing preview
  intent_readout.gd     IntentReadout    filtered incoming threat (rail, details, reaction header)
  reaction_readout.gd   ReactionReadout  three fixed reaction rows from ReactionSpec/BalanceConfig
  unit_readout.gd       UnitReadout      details text for one unit (replaces UnitInfo)
  rule_notes.gd         RuleNotes        condition consequences derived from trait data
  battle_layout.gd      BattleLayout     reference rects for 1280×720 and 100/150/200% text
  presentation_ledger.gd PresentationLedger  per-unit displayed HP/Stagger/Focus/statuses/buffs/…
src/ui/battle/input/
  timing_clock.gd       TimingClock      freezable elapsed-time source shared by a widget
  fresh_press_latch.gd  FreshPressLatch  "held keys must be released first"
```

* **Widgets read readouts and never query research directly.** `PreviewPanel`, `IntentRail`,
  `ReactionWidget`, the log formatter and unit details all go through `BattleKnowledge`.
* **Stable intent rail.** `IntentRail` holds one `IntentSlot` per enemy, assigned by enemy order at
  battle start, in a 2×2 grid inside the stage. A slot never moves to another enemy. The matching
  slot number appears on the enemy's nameplate. This replaces the floating `IntentBubble`.
* **One decision dock.** `DecisionDock` has four columns: party, actions, preview, familiar. While a
  timed input runs, its centre region hosts the command widget or the reaction cards.
  `ReactionWidget` keeps its single clock and draws the rings on the stage. The dock cards and the
  dock's impact meter read that same clock.
* **Layout.** `BattleLayout.compute(size, text_scale)` returns the spec's rects. It is a pure
  function, so a test can check them. Above 175% text it switches to the stacked overlay mode.
* **Ledger.** `PresentationLedger` takes a snapshot at every batch reconcile and applies events in
  between. Status countdowns follow their own events. TURN_ENDED snaps a status only when no later
  event in the same batch touches it, so nothing from the future appears early.
* **Practice / Lab.** A `SandboxForm` model is built once and has two views. Practice applies a fixed
  rule set (manual play, Unknown knowledge, no autoplay, no debug AI, no progress) when it builds the
  setup, and takes difficulty and assist from Settings. Lab keeps today's full form and its own saved
  preferences.

## 4. Data structures and contracts

* New optional, designer-editable fields with safe defaults and no save impact:
  `BattlefieldConditionDefinition.summary` (ribbon text), `EncounterDefinition.practice_note`,
  `GameDefaults.practice_encounters` / `practice_loadouts`, `FamiliarDefinition.portrait`.
  `SpriteFrames` metadata `display_height` / `faces_left` stays with the art, as the brief asks.
* Settings: `TooltipMode.TOGGLE = 2` is appended, so values 0 and 1 keep their meaning. Text scale
  now clamps to 0.75–2.0, and out-of-range modes fall back to HOLD.
* Readouts are typed classes, not dictionaries. A hidden quantity is *absent* (a `has_*` flag plus
  no value). It is never shown as zero or as "?".

## 5. Edge cases covered by design

Duplicate names (existing suffixes plus slot numbers). Retarget after death (slot stays put, and the
INTENT_CHANGED text is shown). Intercept on either side. Broken units and channels, including
uninterruptible ones. Conditional or chance statuses ("may apply"). Burn doused by Wet ("doused:
target is Wet"). Focus at its cap. AoE with mixed knowledge (per-target rows, no total). Tiny
windows after modifiers (the meter draws the real window). Disabled Parry, then Brace. A/X shared
binding (latch). Device change mid-prompt (labels redraw). Text-scale change (deferred during
timing). Log opened during timing (clock unaffected). Window deactivation. Restart during a
feedback await (node-bound tweens). Placeholder art next to sprites.

## 6. Engine-touching changes (flagged for the Director)

1. **Defect fix: enemy Intercept now redirects party single-target attacks.** Shell Ward's
   always-visible telegraph says "attacks on that ally hit the shell". The HUD and the data contract
   say the same. M1 redirected only *enemy* attacks, so party hits went through, and M1.1 would
   otherwise show a rule that resolution ignores. The fix reuses `InterceptRules.redirect`, and the
   preview shows the redirect. Balance numbers are unchanged, but Bogshell encounters behave as
   authored, so I re-ran their simulations (see the report). Revert: one call in `BattleEngine`.
2. **A hit of any affinity now reveals that damage type** (neutral as well as weak or resisted).
   Without this, a neutral Slash hit left Slash "unknown" forever, while the floating numbers had
   already shown the answer. Knowledge flag only. Outcomes are unchanged.

## 7. Dependencies

Godot 4.7.2 only. No addons and no font acquisition (the bundled default font is used). The art
candidates stay untouched. Their SpriteFrames gain only metadata.

## 8. Non-goals (confirmed)

No new enemy, action, status, affinity value, reaction grade or tuning. No prediction engine,
mandatory aim, turn-order change, expedition persistence, world state, save-slot UI, tutorial
battles, art-based timing or hit detection, bespoke per-move animation, music, localization or
scene-tree migration. Animation never drives the reaction clock. Tactician does not read input. The
art is not declared final. The five-person comprehension gate is run by humans, not by headless
tests.
