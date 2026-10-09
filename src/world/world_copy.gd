class_name WorldCopy
extends RefCounted
## Player-facing V0.4 text in one presentation boundary (Director copy from V04_WORLD_ART.md).
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
const STONES_TEXT := "The boards end here. Beneath the reeds, water keeps its own slow rhythm."

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
const PROMPT_APPROACH := "Approach the %s"
const PROMPT_EXAMINE := "Examine the %s"
const PROMPT_GATE := "Examine the gate"
const PROMPT_LOOK := "Look at the %s"
const MAP_CLEARED := "The path is clear here now."
const MAP_HOME_RESTORED := "The town bell answers the fen. The square's lamp is lit."

const SAVE_NOTE := "Progress saves on area arrival, after interactions and victories, and when you choose Save.\n\n" + \
	"You resume at your last saved safe place. Your exact footsteps are not saved.\n\n" + \
	"Quitting during a battle returns you to its approach. That attempt earns no progress."

## Menu → Reset journey (third playtest). The body states exactly what WorldSession.reset_journey()
## resets and keeps.
const ACTION_RESET := "Reset journey"
const ACTION_CANCEL := "Cancel"
const RESET_TITLE := "Reset journey"
const RESET_BODY := "Start this journey again from Gloamstead? Route discoveries, cleared encounters, the wayside " + \
	"bell and the return gate will reset. Research, weapon mastery and equipment will be kept."

const SAVE_FAILED_TITLE := "Progress could not be saved"
const SAVE_FAILED_BODY := "This step has not been saved. Retry to keep it. Returning to the title leaves this step " + \
	"unrecorded; your earlier saved progress is safe."
const ACTION_RETRY_SAVE := "Retry save"
const ACTION_TITLE := "Return to title"

const DEFEAT_BODY := "The party falls back. This attempt earns no research, weapon practice or route progress. " + \
	"Earlier saved progress is safe. Retry with the same battle setup, or return home."
const ACTION_RETRY_ENCOUNTER := "Retry encounter"
const ACTION_RETURN_HOME := "Return to Gloamstead"
const VICTORY_BODY := "The path is clear. This victory, its research and weapon practice have been saved."
const LEAVE_BATTLE := "Leave battle"
