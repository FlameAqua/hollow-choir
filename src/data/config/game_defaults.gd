class_name GameDefaults
extends Resource
## Starting choices that code would otherwise name by id: the new-game loadout, the fight a
## directly opened battle scene and a fresh CombatSandbox start with, and the loadouts the
## simulation CLI compares by default. Designers change them here (data/config/defaults.tres).

## New games (and unknown saved ids) fall back to this loadout; its protagonist leads the party.
@export var starter_loadout: PartyLoadout
## The combat-toy fight: CombatSandbox default and the battle scene when opened on its own.
@export var practice_encounter: EncounterDefinition
## tools/simulate.gd compares these when no --loadout is given.
@export var simulation_loadouts: Array[PartyLoadout] = []

@export_group("Practice (CombatSandbox)")
## Encounters offered in Practice, in order; the first is the default (M1.1 F4).
@export var practice_encounters: Array[EncounterDefinition] = []
## Loadouts offered in Practice, in order; the first is the default.
@export var practice_loadouts: Array[PartyLoadout] = []

@export_group("Presentation")
## Painted stage backdrop for battles (null = the procedural fen). Single-biome pass (M1.1 F5).
@export var battle_backdrop: Texture2D

@export_group("Journey")
## V0.5 UI: the starter presets New Journey offers, in order (preset id = weapon id). Each must be a
## weapon a fresh campaign owns; the rest of the starting loadout is the fresh campaign's
## (JourneyRules.validate_catalog checks both).
@export var journey_presets: Array[WeaponDefinition] = []


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if starter_loadout == null or starter_loadout.protagonist == null:
		problems.append("GameDefaults needs a starter_loadout with a protagonist")
	if practice_encounter == null:
		problems.append("GameDefaults needs a practice_encounter")
	if simulation_loadouts.is_empty():
		problems.append("GameDefaults needs at least one simulation loadout")
	if practice_encounters.is_empty() or practice_loadouts.is_empty():
		problems.append("GameDefaults needs practice encounters and loadouts")
	for encounter in practice_encounters:
		if encounter == null:
			problems.append("GameDefaults has a null practice encounter")
	for loadout in practice_loadouts:
		if loadout == null:
			problems.append("GameDefaults has a null practice loadout")
	for weapon in journey_presets:
		if weapon == null:
			problems.append("GameDefaults has a null journey preset")
	return problems
