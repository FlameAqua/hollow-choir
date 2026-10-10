class_name FamiliarRules
extends RefCounted
## Playtest revision: the travelling familiar and its one selected passive. Uses the existing
## familiar definitions (Bell Crow, Cinder Pup): ownership is ProgressState.familiars, the choice is
## loadout_familiar, and the passive is one of FamiliarDefinition.passive_choices() (the legacy
## trait_def when a familiar authors a single one). Pure: WorldSession owns availability and every
## write. A familiar remains a passive: no turn, no target, no HP.


## Familiar commands run outside a pending or active encounter (its captured loadout is final).
static func availability(progress: ProgressState) -> FamiliarResult.Reason:
	if progress.world.pending_entry != null:
		return FamiliarResult.Reason.ENCOUNTER_PENDING
	return FamiliarResult.Reason.OK


## The approved familiars this save owns, in the save's order, without duplicates.
static func owned(progress: ProgressState, registry: DefinitionRegistry) -> Array[FamiliarDefinition]:
	var result: Array[FamiliarDefinition] = []
	for familiar_id in progress.familiars:
		var familiar: FamiliarDefinition = registry.familiars.get(familiar_id)
		if familiar != null and not result.has(familiar):
			result.append(familiar)
	return result


## The travelling familiar, or null.
static func current(progress: ProgressState, registry: DefinitionRegistry) -> FamiliarDefinition:
	return registry.familiars.get(progress.loadout_familiar)


## The passive id in effect for [param progress] (&"" without a familiar or a passive).
static func passive_id(progress: ProgressState, registry: DefinitionRegistry) -> StringName:
	var familiar := current(progress, registry)
	var passive := familiar.resolved_passive(progress.loadout_familiar_passive) if familiar != null else null
	return passive.id if passive != null else &""


static func familiar_check(progress: ProgressState, registry: DefinitionRegistry, familiar_id: StringName) -> FamiliarResult.Reason:
	if not registry.familiars.has(familiar_id):
		return FamiliarResult.Reason.UNKNOWN_FAMILIAR
	if not progress.familiars.has(familiar_id):
		return FamiliarResult.Reason.NOT_OWNED
	return FamiliarResult.Reason.OK


static func passive_check(progress: ProgressState, registry: DefinitionRegistry, chosen: StringName) -> FamiliarResult.Reason:
	var familiar := current(progress, registry)
	if familiar == null:
		return FamiliarResult.Reason.UNKNOWN_FAMILIAR
	if chosen == &"" or familiar.passive(chosen) == null:
		return FamiliarResult.Reason.UNKNOWN_PASSIVE
	return FamiliarResult.Reason.OK


## Makes [param familiar] travel (already checked) and selects its default passive in the same
## change, so a saved selection always belongs to the travelling familiar.
static func choose(progress: ProgressState, familiar: FamiliarDefinition) -> void:
	progress.loadout_familiar = familiar.id
	var passive := familiar.default_passive()
	progress.loadout_familiar_passive = passive.id if passive != null else &""


## Compatibility repair (WorldSession.reconcile): an approved travelling familiar the save does not
## list as owned becomes owned (a loadout is never stripped for that); an unknown one is replaced by
## the first owned familiar (or none); a selected passive the familiar does not offer falls back to
## its default. Returns one line per repair; empty when nothing changed.
static func repair(progress: ProgressState, registry: DefinitionRegistry) -> PackedStringArray:
	var repairs := PackedStringArray()
	var familiar_id := progress.loadout_familiar
	if familiar_id != &"":
		if registry.familiars.has(familiar_id):
			if not progress.familiars.has(familiar_id):
				progress.familiars.append(familiar_id)
				repairs.append("travelling familiar %s was not listed as owned; it is owned now" % familiar_id)
		else:
			var fallback := owned(progress, registry)
			progress.loadout_familiar = fallback[0].id if not fallback.is_empty() else &""
			repairs.append("familiar '%s' is not approved content; %s travels instead" % [familiar_id,
				progress.loadout_familiar if progress.loadout_familiar != &"" else &"none"])
	var familiar := current(progress, registry)
	var saved := progress.loadout_familiar_passive
	if saved != &"" and (familiar == null or familiar.passive(saved) == null):
		progress.loadout_familiar_passive = &""
		repairs.append("familiar passive '%s' is not offered by %s; its default applies" % [saved,
			progress.loadout_familiar if progress.loadout_familiar != &"" else &"no familiar"])
	return repairs


static func _portrait_path(familiar: FamiliarDefinition) -> String:
	return familiar.portrait.resource_path if familiar.portrait != null else ""


static func readout(progress: ProgressState, registry: DefinitionRegistry) -> FamiliarReadout:
	var result := FamiliarReadout.new()
	result.reason = availability(progress)
	result.reason_text = reason_text(result.reason)
	var travelling := current(progress, registry)
	if travelling != null:
		result.familiar_id = travelling.id
		result.name = travelling.display_name
		result.description = travelling.description
		result.playstyle = travelling.playstyle
		result.portrait_path = _portrait_path(travelling)
		result.passive_id = passive_id(progress, registry)
		for passive in travelling.passive_choices():
			var reason := result.reason
			if reason == FamiliarResult.Reason.OK:
				reason = passive_check(progress, registry, passive.id)
			result.passives.append({"id": passive.id, "name": passive.display_name, "description": passive.description,
				"details": passive.details, "selected": passive.id == result.passive_id,
				"selectable": reason == FamiliarResult.Reason.OK, "reason": reason, "reason_text": reason_text(reason)})
	for familiar in owned(progress, registry):
		var reason := result.reason
		if reason == FamiliarResult.Reason.OK:
			reason = familiar_check(progress, registry, familiar.id)
		result.choices.append({"id": familiar.id, "name": familiar.display_name, "description": familiar.description,
			"playstyle": familiar.playstyle, "portrait_path": _portrait_path(familiar),
			"selected": familiar.id == result.familiar_id, "selectable": reason == FamiliarResult.Reason.OK,
			"reason": reason, "reason_text": reason_text(reason)})
	return result


## Public wording for [param reason] ("" for OK).
static func reason_text(reason: FamiliarResult.Reason) -> String:
	match reason:
		FamiliarResult.Reason.ENCOUNTER_PENDING:
			return WorldCopy.FAMILIAR_ENCOUNTER_PENDING
		FamiliarResult.Reason.UNKNOWN_FAMILIAR:
			return WorldCopy.FAMILIAR_UNKNOWN
		FamiliarResult.Reason.NOT_OWNED:
			return WorldCopy.FAMILIAR_NOT_OWNED
		FamiliarResult.Reason.UNKNOWN_PASSIVE:
			return WorldCopy.FAMILIAR_UNKNOWN_PASSIVE
		FamiliarResult.Reason.WRITE_FAILED:
			return WorldCopy.FAMILIAR_WRITE_FAILED
	return ""
