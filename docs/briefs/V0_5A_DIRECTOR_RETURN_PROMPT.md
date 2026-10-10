# Director return prompt — V0.5A Salvage and Preparation backend complete

You are continuing Hollow Choir as Game Director / Systems Designer and owner of UI/UX direction,
art consistency, copy, audio/SFX and UI integration (Codex implements presentation in the repo).
Claude (lead backend/systems engineer) has implemented **V0.5A, the Salvage and Preparation
backend**, in the working tree on `dev` after `35c8763` (V0.4). Check `git status` first, because
Adrian may have committed it since. Application stays 0.3.0, and save version stays 1 (it gains an
additive `rewards` section). Preserve this work and every authored scene and asset; do not reset the
checkout.

Repository: `C:\Users\Adrian\Code\Games\hollow-choir`.

## Read first

1. `docs/reports/V0_5A_BACKEND_IMPLEMENTATION.md`. It covers behaviour, what is and is not connected
   for players (§1), verification (§7), the Codex API/fixture guide (§8) and Claude's questions (§10).
2. `docs/DATA_CONTRACTS.md`: the section "V0.5A salvage and preparation", the save `rewards` section
   in §6, and the MaterialDefinition / RewardDefinition / RewardItem field reference.
3. `docs/TESTING.md`: "V0.5A salvage and preparation (Claude)".
4. Background: `docs/briefs/V0_5A_BACKEND_HANDOFF.md` and `docs/design/V05_BACKEND_ROADMAP.md`. The
   fifth engineering review (`docs/reports/V0_4_FIFTH_PLAYTEST_ENGINEERING_REVIEW.md`) is complete and
   committed.

## What now exists

- **Rewards.** Defined in `data/rewards/*.tres`; quantities are provisional and tunable in data.
  - First committed patrol victory → 2 Bog Iron.
  - First guard victory → 2 Bog Iron + 1 Storm Salt.
  - Ringing the wayside bell → the existing Storm Salt Charm. Its Grounding trait is unchanged:
    "Shock you apply to a Wet target also deals 12 Stagger."
  - Materials live in `data/materials/{bog_iron,storm_salt}.tres` and have no icons yet
    (`MaterialDefinition.icon` is optional).
- **Exactly once, transactionally.**
  - Each grant happens in the same save write as its accomplishment.
  - Claims (`rewards.claims`) survive Reset journey, so repeating a site or the bell grants nothing.
  - A failed write publishes nothing.
  - Practice, the Lab, defeat and leaving a battle grant nothing.
  - Older saves catch up at world entry in one write, through the existing save-failure card.
- **Preparation commands.**
  - `WorldSession.equip(slot, id)`, `unequip(slot)` and `choose_weapon(id)` work only while the bench
    interaction is open (a session station context) and no encounter is pending.
  - Only owned, approved items in the right slot are accepted.
  - A loadout over the 8-action limit is rejected whole.
  - Typed reasons are in `session.last_preparation`.
  - The bench now lists every owned weapon (today still the three starters, in the same order).
- **Typed readouts** (plain data, item facts only): `session.preparation()`, `session.inventory()`,
  `RewardReadout` (receipts and previews) and `EncounterCardReadout.rewards`.
- **Connected for players now:** the grants, the catch-up, the bench's station context, and
  provisional "Received: …" lines on the victory card and the rung bell's dialogue.
- **Not connected:** no screen shows materials, and no UI equips the charm, garb or relic. The charm is
  earned but cannot be used in play until you add it.

**Verification** (isolated QA homes, Godot 4.7.2):
- Full suite, headless: 358/0 (5,091 assertions); hidden window: 358/0.
- Scripts 266/0; material polish 264/0; Python 10 OK.
- Battle determinism (120 battles) and the simulation smoke are identical to `35c8763`.
- All 25 mutation checks were caught.
- `python tools/qa_godot.py --headless --script res://tools/demo_v05a.gd` runs the whole chain:
  played guard victory → salvage → bell → charm → equip at the bench → Grounding fires on Wet →
  Shock.

Human, controller and listening gates remain **open**.

## Integration work for you (Codex)

Present the backend with the existing textured UI, and keep gameplay validation out of widgets.

1. **Preparation station screen.**
   - Build on the bench (`WorldHost.open_bench`) or replace it, but keep its lifecycle: it calls
     `session.enter_station(landmark.id)` when it opens and `session.leave_station()` when it closes.
     `_set_mode` also ends the context on any return to exploration.
   - Read `session.preparation()`. It has one `EquipmentSlotReadout` per Weapon, Garb, Charm and
     Relic, with `equipped_id`, `equipped_name`, `optional`, `can_remove` and `options`.
   - Each option carries `name, description, category, rarity, equipped, selectable, reason_text,
     actions, traits[{name, description}], grants[{name, description}], resonance`.
   - Show the Hollow's action count against `action_limit` (8). Disable options with
     `selectable == false` and show their `reason_text`.
2. **Commands.**
   - Call them through the host's existing pattern:
     `_commit(func() -> Error: return session.equip(slot, id), then)` (and the same for `unequip`).
     A save failure then shows the save-failure card, and Retry repeats the command.
   - `_commit` currently closes the modal on `ERR_INVALID_PARAMETER` or `ERR_UNAVAILABLE`. If the
     station should stay open after a rejection, show `session.last_preparation.text()` instead.
3. **Inventory / materials view** from `session.inventory()`: materials with counts, and owned
   equipment with its slot and equipped state. Materials have no use until V0.5B; say so honestly or
   keep the view minimal.
4. **Reward presentation.**
   - Replace the provisional lines (`WorldHost._received_lines()`, `WorldCopy.REWARD_*`) with your
     reward feedback.
   - Receipts come from `EventBus.rewards_granted(receipt)`, or `session.last_receipts` right after a
     successful `commit_victory`, `restore_bell` or `reconcile`. Neither fires on a failed write.
   - `RewardReadout` provides `label`, `summary()`, `status_text()` and
     `items[{kind, id, name, description, icon_path, count, added, total, owned}]`.
   - World-entry catch-up for old saves has no visible notice yet.
5. **Assets.**
   - Material icons, wired through `MaterialDefinition.icon`; readouts expose `icon_path`.
   - Optional charm/armor art.
   - Optional reward/equip SFX through the existing AudioManager path.
   - Follow the style guide and keep provenance notes.
6. **Keep the tests meaningful.**
   - `tests/world/test_world_salvage_host.gd` checks that the victory card and the rung bell show
     each receipt once, and that the bench owns the station context. When you change the
     presentation, update its text assertions rather than deleting that coverage.
   - Run `--filter=reward`, `--filter=preparation`, `--filter=salvage` and `--filter=world`, then
     the full suite alone, all through `tools/qa_godot.py`.

Keep save truth, claims, ownership checks, the station rule and the action ceiling backend-owned.
If the presentation needs a new readout field or command, ask Claude in a brief rather than computing
rules in widgets.

## Decisions requested from you

1. **Reset journey copy.** `WorldCopy.RESET_BODY` says research, mastery and equipment are kept.
   Salvage and reward claims are kept too, and a repeated site or bell grants nothing again. Should the
   copy say so?
2. **Provisional copy to finalize:**
   - material descriptions (`data/materials/*.tres`);
   - reward labels ("Patrol salvage", "Bell approach salvage", "Wayside bell");
   - `WorldCopy` receipt and eligibility lines (`REWARD_RECEIVED`, `REWARD_AVAILABLE`,
     `REWARD_CLAIMED`);
   - station rejection lines (`PREP_*`).
3. Show first-clear salvage on the encounter card before a fight? The data is in
   `EncounterCardReadout.rewards` but is not rendered today.
4. Should the world-entry catch-up for old saves show a notice?
5. **Observation, no balance change made:** with the charm equipped, Fen Water Flask then Spark added
   16.8 Stagger and Broke the Bogshell on the Hollow's second turn in the demo battle. Keep it as is,
   or flag it for tuning after Adrian plays it?
6. **V0.5B (Forge/Stillroom)** needs a small specification before Claude starts:
   - recipe prices;
   - mastery thresholds;
   - the first reversible weapon modification choice;
   - refunds;
   - what Bog Iron and Storm Salt unlock.

   Costs must be reachable on the bounded route without a reset grind; the current total is
   4 Bog Iron + 1 Storm Salt.
7. **Version.** Claude recommends bumping to 0.5.0 only after your integration pass and Adrian's test.

## Please return

- A Director review/acceptance note under `docs/reports/` that answers decisions 1–7 and records any
  rule or copy changes explicitly, with Decision Log entries (you own the log).
- Your presentation report with rendered evidence.
- When V0.5B is ready, a Claude brief under `docs/briefs/`.
- Which human sessions Adrian should run next. At minimum: earn the charm, equip it at the bench and
  use it against the patrol.

Do not mark human, controller or listening gates passed.
