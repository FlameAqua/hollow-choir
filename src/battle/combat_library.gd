class_name CombatLibrary
extends RefCounted
## Shared rule data a battle needs besides the combatants themselves: global numbers, status
## behaviour, role defaults and resonance synergies. Built by the Database autoload, or directly
## by tests from .tres files, so the engine never depends on autoloads.

var balance: BalanceConfig
var research: ResearchConfig
var statuses: Dictionary[int, StatusDefinition] = {}
var roles: Dictionary[int, EnemyRoleDefinition] = {}
var resonances: Dictionary[int, ResonanceDefinition] = {}


func status_def(status: Enums.StatusId) -> StatusDefinition:
	return statuses.get(status)


func role_def(role: Enums.EnemyRole) -> EnemyRoleDefinition:
	return roles.get(role)


func resonance_def(tag: Enums.ResonanceTag) -> ResonanceDefinition:
	return resonances.get(tag)


func add_status(definition: StatusDefinition) -> void:
	statuses[definition.status] = definition


func add_role(definition: EnemyRoleDefinition) -> void:
	roles[definition.role] = definition


func add_resonance(definition: ResonanceDefinition) -> void:
	resonances[definition.tag] = definition
