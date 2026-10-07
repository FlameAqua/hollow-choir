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


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if starter_loadout == null or starter_loadout.protagonist == null:
		problems.append("GameDefaults needs a starter_loadout with a protagonist")
	if practice_encounter == null:
		problems.append("GameDefaults needs a practice_encounter")
	if simulation_loadouts.is_empty():
		problems.append("GameDefaults needs at least one simulation loadout")
	return problems
