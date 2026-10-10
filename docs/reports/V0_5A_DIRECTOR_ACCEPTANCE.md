# V0.5A — Director review and integration acceptance

9 October 2026 · shared `dev` working tree after `35c8763` · application 0.3.0 / save version 1

Adrian's subsequent UI feedback is integrated in the [character-menu follow-up](V0_5A_CHARACTER_MENU.md):
compact inspected loot, a portrait/menu, ten starting bag slots, a five-slot restoration reward,
and an Exposed effect icon. Its captures supersede the earlier inventory/reading-control layout.

Claude's salvage/preparation backend is accepted as the integration foundation. The player can now
see salvage, earn the Storm Salt Charm, read Grounding, equip/remove it at the preparation bench,
and take it into the next encounter. This is acceptance for Adrian's playtest, not human approval
or release approval. The backend work, authored scenes and previous assets are preserved; nothing
has been committed, pushed, reset or regenerated. See the [presentation report](V0_5A_PRESENTATION.md)
for this pass's actual verification and rendered fixtures. Claude's earlier results remain historical
evidence in [his report](V0_5A_BACKEND_IMPLEMENTATION.md).

## Decisions 1–7

1. **Reset journey:** yes, state that salvage and reward claims are kept. The confirmation now says:
   “Start this journey again from Gloamstead? Route discoveries, cleared encounters, the wayside bell
   and the return gate will reset. Research, weapon mastery, equipment and salvage will be kept.
   Rewards stay claimed: repeating a site or ringing the bell again grants no further reward.”
   This explains existing backend behavior; no reset rule changes.
2. **Copy:** finalize the material descriptions and reward labels below. Receipts use a textured
   card headed by the reward label, “Saved to inventory”, item names/added quantities, descriptions
   and “Stock after reward” totals (each receipt's cumulative stock, including catch-up batches).
   The readout's default receipt text is “Secured: %s”. Availability is
   “Granted once per save, with this accomplishment.” Claimed is “Already claimed. Repeating this
   accomplishment grants no further reward.” PREP reasons are listed below.
3. **Encounter previews:** yes. Show “First-clear salvage”, the backend summary and its availability
   or already-claimed status. A repeat after Reset journey is explicitly already claimed. Previewing
   grants nothing, writes nothing and reveals no creature facts.
4. **Old-save catch-up:** yes, one dismissible “Rewards from your journey” card after the write
   succeeds, listing only newly added items. It says “Your earlier journey earned these rewards.
   They are now saved to your inventory.” Failed writes still require Retry save; there is no reward
   notice before adoption. Reloading does not repeat the notice. This deliberately supersedes the
   backend report's proposed silent catch-up human check. Repairs alone produce no reward notice.
5. **Grounding:** retain the authored 12 Stagger and Wet/Shock interaction. The reported 16.8
   Stagger after Shock and second-turn Bogshell break is a useful hypothesis for Adrian to test,
   not evidence that tuning is needed. Observe setup effort, payoff clarity and whether the charm
   dominates alternatives. No combat values or rules changed in this presentation pass.
6. **V0.5B:** the [Forge/Stillroom brief](../briefs/V0_5B_BACKEND_HANDOFF.md) is ready as a bounded
   specification. One refundable fitting kit costs 2 Bog Iron and unlocks a reversible choice on
   Pilgrim's Edge; one point of saved starter-weapon mastery opens that capacity. Clotting Salve
   unlock costs 1 Bog Iron; Focus Tincture unlock costs 1 Storm Salt. Total 3 Bog Iron + 1 Storm Salt
   fits the current route's 4 + 1. The two existing modification traits, precise refund boundary,
   compatibility and snapshot requirements are specified there. Nothing from V0.5B is implemented
   or advertised as usable in V0.5A; inventory explicitly says materials have no use in this build.
7. **Version:** keep application 0.3.0 and save version 1. A bump to 0.5.0 follows integration
   review and Adrian's test, through a separate release action. This pass authorizes no release.

## Authored copy

| Data | Final text |
|---|---|
| Bog Iron | Rust-dark iron drawn from the peat. Dense, rough and flecked with reed roots. |
| Storm Salt | Pale crystals left where lightning touched fen water. They prickle through cloth. |
| Patrol reward | Reedway salvage |
| Guard reward | Bell-approach salvage |
| Restoration reward | The bell's keepsake |
| Materials note | Kept for future crafting. Materials have no use in this build. |
| Charm next step | Take the charm to the preparation bench in Gloamstead to equip it. |
| Preparation success | Equipment saved. |
| Preparation footer | Changes apply to the next encounter. The party regroups between fights. |
| Empty slot | This slot is empty. Equipment you earn will appear here. |

| Typed rejection | Final text |
|---|---|
| NO_STATION | Change equipment at the preparation bench. |
| ENCOUNTER_PENDING | Equipment cannot change during an encounter. |
| UNKNOWN_ITEM | That equipment is unavailable in this build. |
| NOT_OWNED | You do not have that item yet. |
| WRONG_SLOT | That equipment belongs in a different slot. |
| REQUIRED_SLOT | A weapon must stay equipped. |
| ACTION_LIMIT | This choice exceeds the %d-action limit. Your equipment has not changed. |

These copy changes do not change claims, ownership, quantities, slots, action ceilings, station
eligibility, research, battle recovery or save truth. Widgets consume typed facts and eligibility.
Rejected preparation commands rebuild from the readout, keep the station open and show the typed
reason. A failed save keeps the station context for Retry; inventory opened inside preparation is
part of the same interaction, and walking/battle/transition still ends it. Paused-world inventory
never opens a station. Equipment success reuses the existing UI-confirm cue only after adoption;
no new SFX asset or listening claim is made. Material icons extend the native stepped SVG family,
with [provenance](../art/SALVAGE_ICONS_V01.md); no generated painting or optional armor art was needed.

## Adrian's next sessions — all still open

1. **Fresh keyboard journey:** use the outside path to leave the optional patrol alive; defeat the
   bell guard, check the salvage card, ring the bell and read the charm's next step. Return through
   the latch, inspect materials, equip the charm in Charm at the bench, close and reopen it.
   Save/quit/Continue and confirm the equipped state. Fight the untouched patrol: have the Hollow
   throw Fen Water Flask to apply Wet, then cast Spark at the same foe on the next turn to apply Shock.
   Mara can Guard while you set up. Check Grounding's feedback and break
   payoff. Compare an unequipped attempt after Reset journey if useful.
2. **Existing save and reset:** Continue a V0.4 save with the bell restored. A single catch-up
   notice should explain the inventory gain. Continue again: no second notice. Read the reset
   confirmation, reset, and replay a clear/restoration; preview says already claimed and inventory
   never grows from those repeat accomplishments. Keep a copy of the older save for comparison.
3. **Controller:** navigate all four slots, select/equip/remove the charm, use Read further/earlier,
   open Inventory and return to the same slot, and close with Cancel. Check that empty/disabled
   choices do not trap focus and that no closing press interacts with the world behind the screen.
4. **Listening and visual review:** compare the bench's existing confirm cue with normal menu
   confirmation; review reward pacing, material-icon silhouettes and 22 px text at the chosen
   supported resolution. Use sound off and reduced motion too. Screenshots do not pass these gates.

Decision Log: D-042 (integration/copy), D-043 (next backend specification). Human gameplay, art,
controller and listening acceptance remain **open**.
