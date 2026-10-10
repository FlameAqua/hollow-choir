# V0.5B — One useful Forge and a small Stillroom

Director specification · 9 October 2026 · backend assignment for Claude

Implement this bounded backend stage after reviewing the shared V0.5A tree and
[Director acceptance](../reports/V0_5A_DIRECTOR_ACCEPTANCE.md). Check status first and preserve all
uncommitted work. Do not reset, commit, push, bump versions, redesign presentation or regenerate
areas. Codex owns the eventual station screens. Application is now **0.5.0**, following Adrian's
explicit version update; save version remains **1**. Preserve the atlas character-menu frames.
Human/controller/listening gates remain open. Adrian wants the full human test after the remaining
V0.5 systems are integrated, rather than using it as a gate before this backend assignment.
Follow the [current continuation sequence](V0_5_CONTINUATION_FOR_CLAUDE.md).

Preserve the subsequent [character-menu follow-up](../reports/V0_5A_CHARACTER_MENU.md): shared
item inspection, authored equipment icons and the ten-slot bag expanding by five through the
restoration claim. Crafting must not consume/remove that claim or recreate a separate capacity
counter. The new menu reads current action/passive facts from the real loadout factory.

## Experience and exact introductory economy

Return with salvage, make one reversible tactical weapon choice, unlock two alternatives for the
existing two prepared potion slots, then try a new encounter. No stat levels, new action, carried
potion depletion, random materials, gathering requirement, repeat-clear grant or reset grind.

| Recipe / command | Cost | Mastery | Permanent result |
|---|---|---|---|
| Forge fitting kit (`forge.first_fitting`) | 2 Bog Iron | At least 1 saved mastery point on any owned starter weapon: Pilgrim's Edge, Mire Maul or Reedbow | One introductory fitting on Pilgrim's Edge; both choices below available |
| Clotting Salve recipe (`stillroom.clotting_salve`) | 1 Bog Iron | 0 | This existing potion becomes a campaign preparation choice |
| Focus Tincture recipe (`stillroom.focus_tincture`) | 1 Storm Salt | 0 | This existing potion becomes a campaign preparation choice |

All purchases total **3 Bog Iron + 1 Storm Salt**, against the current full route's **4 + 1**.
The guard alone gives 2 + 1, so kit + tincture are reachable before the optional patrol; its 2 iron
fund the salve and leave 1. Buying in any order cannot permanently block the other purchases.
The one-point mastery threshold asks for a single recorded weapon use, not a Perfect or repeat
expedition. Use existing saved mastery; do not introduce a second XP counter. It unlocks the
introductory capacity globally, so changing starter weapons does not require grinding three tracks.
No further mastery tiers, sockets or prices are active in this stage. An unusual zero-weapon-use
win may leave the kit locked until one recorded weapon action: show this exact reason; route
completion never requires the kit.

Stillroom vocabulary: each recipe has a public Base (prepared salve / clear tincture stock), Reagent
(Bog Iron / Storm Salt) and no Catalyst. Bases are reusable home supplies, explicitly not new saved
material stacks or hidden costs. Recipe ownership unlocks selection, not a number of bottles.
Keep Mending Draught and Fen Water Flask available free as the campaign starters, with every
authored effect/capacity unchanged. Lab and Practice retain access to all authored potions.

## First reversible modification choice

Scope the first fitting to **Pilgrim's Edge**, a deliberate introductory exception to its current
`socket_count = 0`. Derive this capacity from the purchased kit and mastery in pure rules; do not
change shared common weapon resources or grant sockets to every weapon. Common base gear remains
viable. The first choices reuse complete, existing authored traits:

| Choice | Existing source | Exact behavior |
|---|---|---|
| Merciful Grip | `data/weapons/merciful_iron.tres`, trait `merciful_grip` | Good window ×1.6, Perfect ×1.5, Perfect damage multiplier 1.07 instead of 1.15; successful Parries restore 8 HP |
| Hollow Echo | `data/armor/hollow_reliquary.tres`, trait `hollow_echo` | Successful Parry also exposes the attacker's weak point for 1 turn |

These support comfort/recovery versus creating a weak-point opening. Keep the base Pilgrim's
Patience, actions, damage, Stagger, resonance and stance. One of the two fittings or none; choosing,
swapping and removing costs **0**, at the preparation station only. Both reuse trait resolution;
no bespoke combat hook, duplicated effect or action slot. Do not grant Merciful Iron or the relic.
Use approved trait references resolved from stable modification definitions, not UI lookups of
nested resources. Reject simultaneous duplication if a future loadout also supplies the chosen
trait (e.g. an owned Hollow Reliquary plus Hollow Echo fitting); return a typed reason. Do not
quietly double it or remove unrelated gear. Capture resolved modification IDs with EncounterEntry,
so retry remains immutable even when live progress changes. Test the actual trait behavior.

## Refunds and transaction boundaries

- Reclaiming the fitting kit refunds exactly **2 Bog Iron**, clears its unlock and any installed
  fitting together in one write. It leaves mastery, the base sword and owned equipment intact.
  No kit means no refund; repetition is a typed no-op/rejection, never another credit. Buying
  again is allowed for 2 iron. Removing/swapping a fitting alone never grants materials.
- Stillroom recipe purchases are permanent and have **no refund**. They are finite unlocks, not
  consumable crafting. Every recipe is reachable alongside the kit. Duplicate purchase is a no-op
  or typed already-owned rejection and never spends again. Potion selection is free.
- Purchase, refund, modification and potion selection require the open preparation station and no
  pending encounter. Reuse WorldSession's context and atomic copy → change → write → adopt path.
  The current bench can host both station services for this batch; no new world placement is needed.
- Failure changes no material count, recipe, fitting, loadout or receipt. Retry repeats the exact
  command and publishes once. Validate full loadouts against the existing eight-action ceiling,
  including the two potion slots. No truncation, stat assumptions or rules in widgets.
- Refund arithmetic must not lose materials at the stack cap: reject whole if the complete refund
  cannot fit. Include a typed reason rather than saturating away a paid refund.

## Data, compatibility and readouts

Propose the smallest typed recipe/cost/modification definitions, saved unlocks/installed fitting
and readouts before expanding unrelated abstractions. Extend existing progression rather than
adding an economy manager. Preserve V0.5A inventory/claims, legacy saves, reset policy and ownership
checks. New unlocks/fittings persist across Reset journey. New Game has none. Unknown saved IDs
stay inert; invalid loadouts repair at explicit reconciliation, never deserialization. Grandfather
approved legacy equipped potions as available during explicit reconciliation, as with V0.5A gear;
do not remove a valid old loadout merely because recipe ownership did not exist. No retroactive
material charge. Application/save versions remain 0.5.0/1 unless a concrete migration need is
reported first.

Return plain typed readouts containing recipe names, Base/Reagent/Catalyst facts, approved costs,
held counts, mastery requirement/current value, unlock/installed/selected state, availability and
typed rejection text, resulting public trait facts, action counts, refundable amount, and actual
spent/refunded receipts. Widgets must never compute affordability, duplicate trait checks, mastery
or resulting loadout rules. Keep knowledge filtering intact. If the exact trait reuse has a
technical mismatch, report it in the brief/review before replacing behavior or numbers.

## Acceptance and return package

Exercise real production commands with successful and failing writers: every purchase order fits
the finite budget; insufficient funds, zero mastery, unknown IDs, wrong weapon, duplicate purchase,
duplicate trait, no station, pending battle and action overflow publish nothing. Verify refunds
and rebuy loops conserve materials, including a cap conflict; reset/reload retain unlocks and
claims. Verify new and legacy potion preparation, base restoration, snapshot/retry immutability,
and that different saves/shared Resources are unaffected. Demonstrate purchase → fit → reload →
real battle trait behavior and purchase → potion preparation → battle with unchanged capacities.

Run focused tests, the complete suite alone, script/content validation and an isolated demo,
all through `tools/qa_godot.py`. Return `docs/reports/V0_5B_BACKEND_IMPLEMENTATION.md`, updated
DATA_CONTRACTS/TESTING, exact verification and a concise API/fixture guide for Codex. Stop at this
backend seam. New UI, recipes beyond these two, more weapons, bosses, Pressure, attrition, quests,
gathering and map changes require later work.
