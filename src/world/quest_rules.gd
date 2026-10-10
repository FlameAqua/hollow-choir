class_name QuestRules
extends RefCounted
## Playtest revision: a bounded quest journal for the existing bell journey. One quest, whose stage
## is derived from world truth (the cleared guard, the restored bell, standing in Gloamstead
## afterwards) and saved in the existing `quests` section. It adds no reward, flag, content or
## objective: the step text is the HUD objective's own WorldCopy lines.
##
## WorldSession re-derives the stage inside every world write (sync), so the journal can never
## disagree with the world: an older save, an edited save and Reset journey all converge on the
## derived stage. Only a change adopted by a real write is announced; loading and opening are silent.

const BELL := &"first_footsteps.wayside_bell"

enum BellStage {
	## Find the wayside bell (the guard still holds its approach).
	FIND = 0,
	## The guard is cleared: restore the bell.
	RESTORE = 1,
	## The bell is restored: return to Gloamstead.
	RETURN = 2,
	## Returned home with the bell restored. Kept once reached, until Reset journey.
	COMPLETE = 3,
}

const _GUARD := &"bell_guard"


## The bell journey's stage for [param world], given the stage the save recorded ([param saved];
## anything else than COMPLETE is ignored, the world decides).
static func bell_stage(world: WorldState, definition: WorldDefinition, saved: int) -> int:
	if not world.wayside_bell_restored:
		return BellStage.RESTORE if world.is_cleared(_GUARD) else BellStage.FIND
	if saved == BellStage.COMPLETE or world.area == definition.start_area:
		return BellStage.COMPLETE
	return BellStage.RETURN


## Brings [param progress]'s saved journal stage in line with its world (call on a commit candidate
## after the change, or on the live state to probe). Returns the change it made, or null when the
## saved stage already agreed. [param reset]: the write is Reset journey, so a stage that moved back
## is reported as RESET rather than silently rewound.
static func sync(progress: ProgressState, definition: WorldDefinition, reset: bool = false) -> QuestChange:
	var had: bool = progress.quests.has(BELL)
	var saved: int = progress.quests.get(BELL, -1)
	var stage := bell_stage(progress.world, definition, saved)
	if had and saved == stage:
		return null
	progress.quests[BELL] = stage
	var change := QuestChange.new()
	change.quest_id = BELL
	change.title = bell_title()
	change.previous_stage = saved if had else -1
	change.stage = stage
	change.objective = step_text(stage)
	if not had:
		change.kind = QuestChange.Kind.ACQUIRED
	elif reset or stage < saved:
		change.kind = QuestChange.Kind.RESET
	elif stage == BellStage.COMPLETE:
		change.kind = QuestChange.Kind.COMPLETED
	else:
		change.kind = QuestChange.Kind.ADVANCED
	return change


## Would sync() change [param progress]? (Pure probe; nothing is written.)
static func needs_sync(progress: ProgressState, definition: WorldDefinition) -> bool:
	return not progress.quests.has(BELL) or \
		int(progress.quests[BELL]) != bell_stage(progress.world, definition, int(progress.quests[BELL]))


## The journal for [param progress]: the bell journey, from the stage its world proves. A save whose
## recorded stage is missing or stale still reads the derived one (reading never writes).
static func journal(progress: ProgressState, definition: WorldDefinition) -> QuestJournalReadout:
	var result := QuestJournalReadout.new()
	var entry := bell_readout(bell_stage(progress.world, definition, progress.quests.get(BELL, -1)))
	if entry.completed:
		result.completed.append(entry)
	else:
		result.active.append(entry)
	return result


static func bell_readout(stage: int) -> QuestReadout:
	var entry := QuestReadout.new()
	entry.id = BELL
	entry.title = bell_title()
	entry.stage = stage
	entry.stage_count = BellStage.size()
	entry.completed = stage >= BellStage.COMPLETE
	entry.objective = step_text(stage)
	for step in [BellStage.FIND, BellStage.RESTORE, BellStage.RETURN]:
		entry.steps.append({"stage": step, "text": step_text(step), "done": stage > step,
			"current": stage == step})
	return entry


## The quest's public title.
static func bell_title() -> String:
	return WorldCopy.QUEST_BELL_TITLE


## The public text of [param stage]: the HUD objective's own lines (the completion line for COMPLETE).
static func step_text(stage: int) -> String:
	match stage:
		BellStage.FIND:
			return WorldCopy.OBJECTIVE_FIND
		BellStage.RESTORE:
			return WorldCopy.OBJECTIVE_RESTORE
		BellStage.RETURN:
			return WorldCopy.OBJECTIVE_RETURN
	return WorldCopy.QUEST_BELL_COMPLETE
