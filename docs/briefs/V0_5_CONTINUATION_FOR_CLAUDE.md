# V0.5 — Current continuation for Claude

**Superseded assignment:** B/C were returned and integrated. Adrian's newest UI/backend requests
are in [V0_5_UI_BACKEND_HANDOFF.md](V0_5_UI_BACKEND_HANDOFF.md); use that brief next. This document
preserves the earlier B/C assignment and is not an instruction to reimplement completed systems.

9 October 2026 · prepared handoff · application 0.5.0 / save 1

Continue Hollow Choir in the shared `dev` tree. Check status and preserve all uncommitted work.
Adrian requested the version update to V0.5 and wants the subsequent V0.5 systems integrated
before the full human test. This is a prepared assignment; it does not claim a Claude session
has started or that later systems already exist.

The fifth engineering pass is complete in `35c8763`. V0.5A salvage/preparation and its Codex
presentation are integrated, including the character menu, shared combat inspection controls,
compact loot, Exposed effect icon and ten starting equipment slots. First bell restoration grants
five further slots through its persistent reward claim. Preserve these rules and the existing
atlas frames; never recreate capacity as a separate saved counter.

1. **Claude: implement V0.5B now.** Use the exact
   [Forge/Stillroom specification](V0_5B_BACKEND_HANDOFF.md): one reversible fitting kit and two
   permanent potion recipe unlocks. Its prices, mastery requirement, refunds, snapshot contracts
   and return package are already specified. Do not wait for a full human playthrough of V0.5A.
2. **Codex: integrate and review the returned station screens.** Validate actual commands,
   rejection reasons, item inspection and save-failure retries. Resolve concrete defects with
   Claude and prepare the bounded V0.5C content/placement specification using the
   [roadmap](../design/V05_BACKEND_ROADMAP.md).
3. **Claude: implement V0.5C against that specification.** Add the authored gathering node,
   discoverable secret and first reusable puzzle grammar. Return deterministic state, save/reset
   policy, reward hooks, tests and fixtures. Codex integrates the agreed scene interactions and
   visible feedback. V0.6 Pressure, quests, bosses and further regions remain later work.
4. **Qualify the integrated V0.5 build, then run the full human test.** Automated checks continue
   after each stage. The final test should cover a fresh journey and older-save reconciliation;
   salvage and slot growth; purchase/fit/refund and both recipe unlocks; preparation into real
   battle; gathering/discovery/puzzle rewards; save/reload/reset and failed-write recovery; and
   mouse/keyboard, controller, readability and listening review. Human acceptance remains open
   until Adrian actually performs it.

Read [V0.5A Director acceptance](../reports/V0_5A_DIRECTOR_ACCEPTANCE.md), the
[character-menu follow-up](../reports/V0_5A_CHARACTER_MENU.md) and
[atlas presentation update](../reports/V0_5_MENU_ATLAS.md) for the current tree. Keep inherited
test evidence separate from tests run on new work. Do not reset, commit, push, change versions or
regenerate authored areas as part of this assignment. Preserve all-reset battles, two potion
slots, the eight-action ceiling, filtered knowledge and immutable encounter retries.
