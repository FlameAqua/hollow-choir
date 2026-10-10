# V0.5 UI backend — Director acceptance

10 October 2026 · Codex, Creative & Frontend Director · shared uncommitted `dev`.
Application **0.5.0**, save version **1**.

Accept Claude's [UI backend return](V0_5_UI_BACKEND_IMPLEMENTATION.md) for integrated presentation
and Adrian's full human test. The six requested rulings are recorded below. Automated and rendered
evidence belongs to [the presentation report](V0_5_UI_PRESENTATION.md); this is not human acceptance.

| Requested decision | Director ruling | Decision Log |
|---|---|---|
| 1. Difficulty per journey | Accept. Setup records it, load applies it, Settings changes live journey difficulty and the next save persists it. Assist/accessibility remain per player; encounter retries retain the captured value. | D-049, amends D-009 |
| 2. Kindle starts unplaced | Confirm the first six, Actions then Magic, for all starters and older saves without an arrangement. Keep Kindle visible in Magic and name it in the Unplaced line. It enters battle only after placement. | D-050 |
| 3. Older saves use Adventurer | Accept the deterministic default. Former Tactician players choose it once again; no speculative migration from current Settings. | D-051 |
| 4. Freed positions refill in grid order | Accept. Shared actions retain positions; weapon-specific actions refill freed positions in the same write. No per-weapon memory. | D-052 |
| 5. Equipped-item re-choice writes nothing | Accept. Show the unchanged result and emit no save success. Supersedes the V0.5A exception. | D-053, amends D-046 |
| 6. Notices hide during battle | Accept. Timers continue normally. Give save confirmations reserved footer space in stations and Character so Close/Back remain visible. | D-054 |

See [Decision Log](../DECISION_LOG.md). These are Director implementation rulings within the
requested scope. Kindle's six-position tradeoff, controller usability, readability, art fit,
listening and the full gameplay loop still need Adrian's assessment.

The slot step and replacement review now use the established cloth/brass components, structured
save facts and a recap of the selected weapon/difficulty. Replacement retains a distinct,
explicit action and initial Cancel focus. Damaged and newer saves remain occupied.
All requested WorldCopy families have final presentation copy, with truthful field/station guidance.

The internal bench and its capture/tests are retained. Drag and drop is deferred; the supported
position-then-candidate interaction uses the real transaction. The reported material/scale
shadowing and unassigned focus locals are corrected. No authored area, balance data, application
version or save version was regenerated or changed; no reset, commit or push was performed.

Return the integrated tree to Adrian with [the updated full human checklist](../playtests/V0_5_INTEGRATED_TEST.md).
There is no further backend handoff required for this presentation scope. Human, controller,
art and listening gates remain **open**.
