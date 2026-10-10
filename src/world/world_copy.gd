class_name WorldCopy
extends RefCounted
## Player-facing world and journey text in one presentation boundary (Director copy, V0.5).
## No branching conditions live here; WorldRules picks which line applies from typed state.

const OBJECTIVE_FIND := "Find the wayside bell"
const OBJECTIVE_RESTORE := "Restore the wayside bell"
const OBJECTIVE_RETURN := "Return to Gloamstead"
const OBJECTIVE_DONE := "The town bell answers again."

const BELLKEEPER := "Bellkeeper"
const BELLKEEPER_BEFORE := ["The fen bell has gone quiet. Ours has nothing to answer.",
	"Follow the old boards beyond the reed gate. If the bell still hangs, give it a voice."]
const BELLKEEPER_AFTER := ["There. Did you hear it? Not loud, but ours answered.",
	"We can keep a place for that sound."]

const WAYSIDE_BELL := "Wayside bell"
const BELL_GUARDED := "Roots crowd the bell's frame. The creatures at its foot have not moved."
const BELL_READY := "The bell is whole beneath the roots. Its rope is within reach."
const BELL_RESTORED := "A thin note carries home."
const ACTION_RING := "Ring the bell"

const LATCH := "Return latch"
const LATCH_NEAR := "The latch is on the far side."
const LATCH_FAR := "A wooden bar holds the gate shut. From here, you can lift it free."
const LATCH_OPEN := "The return gate stands open. The short way home is clear."
const ACTION_OPEN_LATCH := "Open the return gate"

const STONES := "Listening stones"
const STONES_TEXT := "Three stones carry a worn instruction: Low, then high, then middle. Let each note settle. A wrong note breaks the rhythm; the low stone can begin it again."

const BENCH := "Preparation bench"
const RESOURCE_RULE := "The party regroups between fights. HP, Focus and potion uses reset for each encounter."

const ACTION_LEAVE := "Leave"
const ACTION_CLOSE := "Close"
const ACTION_CONTINUE := "Continue"
const ACTION_ENGAGE := "Engage"

const UNKNOWN_CREATURE := "Unknown creature"
const ENCOUNTER_OPTIONAL := "The outer path passes around this group. Leaving costs nothing."
const ENCOUNTER_GUARD := "This group holds the bell approach. Leaving costs nothing."
const MAP_LEGEND := "Hollow: you · Lines: walked paths"
const MAP_EMPTY := "No places charted yet. Explore to discover them."
const PROMPT_TALK := "Talk to the %s"
const PROMPT_PREPARE := "Use the %s"
const PROMPT_ENGAGE := "Engage the %s"
const PROMPT_EXAMINE := "Examine the %s"
const PROMPT_GATE := "Examine the gate"
const PROMPT_LOOK := "Look at the %s"
const MAP_CLEARED := "The path is clear here now."
const MAP_HOME_RESTORED := "The town bell answers the fen. The square's lamp is lit."

const SAVE_NOTE := "Progress saves on area arrival, after interactions and victories, and when you choose Save.\n\n" + \
	"You resume at your last saved safe place. Your exact footsteps are not saved.\n\n" + \
	"Quitting during a battle returns you to its approach. That attempt earns no progress."
## The help card's controls line: the sprint input, then the Loadout, Inventory, Journal, Field Guide
## and Map shortcuts, each as its current binding prompt.
const CONTROLS_NOTE := "Hold %s to sprint while your stamina lasts. Shortcuts: %s Loadout · %s Inventory · %s Journal · %s Field Guide · %s Map."

## Menu → Reset journey (third playtest). The body states exactly what WorldSession.reset_journey()
## resets and keeps.
const ACTION_RESET := "Reset journey"
const ACTION_CANCEL := "Cancel"
const RESET_TITLE := "Reset journey"
const RESET_BODY := "Start this journey again from Gloamstead? Route discoveries, cleared encounters, the wayside " + \
	"bell and the return gate will reset. Research, weapon mastery, equipment and salvage will be kept. " + \
	"Recipes and fittings stay yours; gathered nodes stay gathered. Secrets, puzzles and rune attempts reset. " + \
	"Rewards stay claimed: solving or finding again, repeating a site or ringing the bell again grants nothing."

const SAVE_FAILED_TITLE := "Progress could not be saved"
const SAVE_FAILED_BODY := "This step has not been saved. Retry to keep it. Returning to the title leaves this step " + \
	"unrecorded; your earlier saved progress is safe."
const ACTION_RETRY_SAVE := "Retry save"
const ACTION_TITLE := "Return to title"

const DEFEAT_BODY := "The party falls back. This attempt earns no research, weapon practice or route progress. " + \
	"Earlier saved progress is safe. Retry with the same battle setup, or return home."
const ACTION_RETRY_ENCOUNTER := "Retry encounter"
const ACTION_RETURN_HOME := "Return to Gloamstead"
const LEAVE_BATTLE := "Leave battle"

## V0.5A Director copy. Item facts and eligibility still come from the backend.
const REWARD_RECEIVED := "Secured: %s"
const REWARD_AVAILABLE := "Granted once per save, with this accomplishment."
const REWARD_CLAIMED := "Already claimed. Repeating this accomplishment grants no further reward."
const REWARD_SAVED := "Saved to inventory"
## Equipment and prepared supplies change from Character outside battle.
const REWARD_CHARM_NEXT := "Open Character → Equipment to wear it before your next encounter."
const REWARD_CATCH_UP := "Your earlier journey earned these rewards. They are now saved to your inventory."
const REWARD_INVENTORY_NEXT := "Find it in Character → Inventory. Equip it from the Equipment tab between encounters."
## V0.5 UI: Forge (anvil) and Stillroom are separate Gloamstead stations.
const MATERIALS_NOTE := "Bring salvage to Gloamstead: fittings at the Forge anvil, potion recipes at the Stillroom table. Prepare your supplies from Character between encounters."
const PREP_FOOTER := "Changes apply to the next encounter. The party regroups between fights."
const PREP_EMPTY := "This slot is empty. Equipment you earn will appear here."
## Legacy reason: V0.5A equipment needed a station; equipment no longer does (never returned).
const PREP_NO_STATION := "Change equipment from Character, outside battle."
const PREP_ENCOUNTER_PENDING := "Equipment cannot change during an encounter."
const PREP_UNKNOWN_ITEM := "That equipment is unavailable in this build."
const PREP_NOT_OWNED := "You do not have that item yet."
const PREP_WRONG_SLOT := "That equipment belongs in a different slot."
const PREP_REQUIRED_SLOT := "A weapon must stay equipped."
const PREP_ACTION_LIMIT := "This choice exceeds the %d-action limit. Your equipment has not changed."
const PREP_DUPLICATE_TRAIT := "A fitting already supplies this item's trait. Remove one source first. Your equipment has not changed."
const PREP_SAVED := "Equipment saved for your next encounter."
const PREP_UNCHANGED := "Already equipped. Your journey is unchanged."

## V0.5B Forge/Stillroom Director copy. Prices,
## eligibility and results always come from CraftingRules readouts.
const CRAFT_NO_STATION := "Use the Forge anvil or the Stillroom in Gloamstead."
const CRAFT_WRONG_STATION_FORGE := "Take this work to the Forge anvil in Gloamstead."
const CRAFT_WRONG_STATION_STILLROOM := "Take this recipe to the Stillroom table in Gloamstead."
const CRAFT_ENCOUNTER_PENDING := "Station work cannot change during an encounter."
const CRAFT_UNKNOWN_RECIPE := "That recipe is unavailable in this build."
const CRAFT_RECIPE_NOT_OWNED := "Not unlocked, so there is nothing to refund."
const CRAFT_INSUFFICIENT := "Not enough materials."
const CRAFT_MASTERY_REQUIRED := "Needs %d weapon mastery point with %s. Use one of them in a battle that records progress."
const CRAFT_REFUND_OVERFLOW := "The refund would take a material past %d. Nothing was refunded."
const CRAFT_UNKNOWN_FITTING := "That fitting is unavailable in this build."
const CRAFT_WRONG_WEAPON := "That fitting does not suit this weapon."
const CRAFT_WEAPON_NOT_OWNED := "You do not have that weapon."
const CRAFT_NO_CAPACITY := "Buy the fitting kit at the Forge to fit this weapon."
const CRAFT_DUPLICATE_TRAIT := "Your equipment already supplies this trait. Remove one source first."
const CRAFT_UNKNOWN_POTION := "That potion is unavailable in this build."
const CRAFT_POTION_LOCKED := "Unlock this recipe at the Stillroom first."
const CRAFT_DUPLICATE_POTION := "This potion is already prepared in the other slot."
const CRAFT_INVALID_POTION_SLOT := "There are only %d potion slots."
const CRAFT_SAVED := "Saved. Changes apply to the next encounter."

## V0.5 title copy. A free place starts immediately; an occupied place always asks again.
const SAVE_SLOT_LABEL := "Journey %d"
const SAVE_TIME_UNKNOWN := "Save time unknown"
const SAVE_SLOT_EMPTY := "Free place"
const SAVE_SLOT_FREE := "A free place for your new journey."
const SAVE_SLOT_VICTORY := "%d victory"
const SAVE_SLOT_VICTORIES := "%d victories"
const SAVE_SLOT_UNREADABLE := "Unreadable save. Kept here until you choose to replace it."
const SAVE_SLOT_UNSUPPORTED := "Saved in a newer game version. Kept here until you choose to replace it."
const SAVE_LOAD_FAILED := "Could not open this journey. Your saves are safe. Choose a journey to try again."
const JOURNEY_UNKNOWN_DIFFICULTY := "Choose a difficulty: Story, Adventurer or Tactician."
const JOURNEY_UNKNOWN_PRESET := "Choose a starter weapon for the road."
const JOURNEY_NO_SLOT := "Choose a place to save your new journey."
const JOURNEY_INVALID_SLOT := "Choose one of the %d journey places shown."
const JOURNEY_SLOT_OCCUPIED := "Journey %d now holds a save. Choose it again to review a replacement."
const JOURNEY_WRITE_FAILED := "Could not save. Your journeys are safe. Choose a place to retry."
const JOURNEY_PRESET_GARB := "You wear %s."
const JOURNEY_PRESET_PARTY := "%s and %s travel with you."
const JOURNEY_PRESET_SUPPLIES := "Prepared for the road: %s"
const JOURNEY_PRESET_OWNED := "You carry all three starter weapons. This choice equips one; change it between encounters."
const JOURNEY_SETUP_NOTE := "Next, choose where to save. Difficulty can change during your journey."
const JOURNEY_CHOOSE_SAVE := "Choose save place"
const JOURNEY_BACK_TO_SETUP := "Back to setup"
const JOURNEY_BEGIN_HERE := "Begin here"
const JOURNEY_SLOT_TITLE := "A place for your journey"
const JOURNEY_SLOTS_FULL := "All places are full. Choose one to review a replacement."
const JOURNEY_REPLACE_HINT := "Replace…"
const JOURNEY_REPLACE_TITLE := "Replace Journey %d?"
const JOURNEY_REPLACE_BODY := "%s will be erased and your new journey saved in its place. This cannot be undone."
const JOURNEY_REPLACE_ACTION := "Replace Journey %d"

## V0.5 Combat copy. CombatRules decides every reason and supplies the counts.
const COMBAT_ENCOUNTER_PENDING := "Finish or leave this encounter before arranging your actions."
const COMBAT_LOCKED_POSITION := "Locked · opens with future progression."
const COMBAT_INVALID_POSITION := "Choose one of the combat positions shown."
const COMBAT_UNKNOWN_ACTION := "This action is unavailable. Choose another."
const COMBAT_NOT_GRANTED := "Equip the gear that grants this action before placing it."
const COMBAT_PASSIVE := "Always active with your current loadout. Passive skills use no combat position."
const COMBAT_EMPTY_POSITION := "Choose a filled position to move its action."
const COMBAT_UNARRANGED := "Unplaced · place this in an unlocked position to use it in battle."
const COMBAT_ARRANGED := "Ready in combat position %d."
const COMBAT_SOURCE_COMMON := "Shared party action"
const COMBAT_REPLACED := "%s takes %s's place in combat position %d."
const COMBAT_LEFT := "%s leaves combat position %d."
const COMBAT_JOINED := "%s is ready in combat position %d."

## V0.5C exploration Director copy. Which line applies is
## decided by WorldRules from typed state.
const PROMPT_GATHER := "Gather from the %s"
const PROMPT_SEARCH := "Search the %s"
const PROMPT_STRIKE := "Strike the %s"
const ACTION_GATHER := "Gather"
const ACTION_SEARCH := "Search"
const GATHERED_TEXT := "Only rust-stained peat remains. This seam has given all it can."
const GATHER_DONE := "Gathered and saved to your inventory."
const SECRET_FOUND_TEXT := "The niche stands open. Its cloth wrapping is empty."
const SECRET_FOUND_BODY := "You draw the dry wrapping from beneath the roots. Its contents are now saved to your inventory."
const SECRET_EMPTY := "Whatever was hidden here has already been taken."
const PUZZLE_SOLVED_TEXT := "The stones answer together."

## V0.5 playtest revision; adopted facts and eligibility remain owned by the backend.
const QUEST_BELL_TITLE := "The Wayside Bell"
const QUEST_BELL_COMPLETE := "The bell's song has returned to Gloamstead."
const CRAFT_STOCK_OVERFLOW := "Stock limit: %d doses. No room for this batch."
const CRAFT_FITTING_OWNED := "Already crafted."
const CRAFT_NOT_REFUNDABLE_NOW := "This item cannot be refunded."
const CRAFT_NO_STOCK := "Brew more doses at the Stillroom."
const CRAFT_RECIPE_RETIRED := "Choose an individual fitting to craft."
const CRAFT_FITTING_NOT_OWNED := "Craft this fitting first."
const CRAFT_INVALID_SOCKET := "Choose one of the three sockets shown."
const CRAFT_LOCKED_SOCKET := "This socket is locked."
const CRAFT_NOT_BREWABLE := "Choose a supply recipe to brew."
const FAMILIAR_ENCOUNTER_PENDING := "Finish or leave the encounter before changing your pet."
const FAMILIAR_UNKNOWN := "That pet is unavailable."
const FAMILIAR_NOT_OWNED := "That pet has not joined your journey."
const FAMILIAR_UNKNOWN_PASSIVE := "Choose one of this pet's passives."
const FAMILIAR_WRITE_FAILED := "Could not save this choice. Try again."
const JOURNAL_TITLE := "Journal"
const BAG_LOCKED_CELL := COMBAT_LOCKED_POSITION
const SUPPLY_LOCKED_POSITION := COMBAT_LOCKED_POSITION
const SUPPLY_LOCKED_TITLE := "Locked supply position"
const SUPPLY_EMPTY_TITLE := "Empty supply position"
const SUPPLY_EMPTY_TEXT := "Nothing is prepared here."
const SUPPLY_FACT_HELD := "Held  ×%d"
const SUPPLY_FACT_USABLE := "Next encounter  %d of %d"
