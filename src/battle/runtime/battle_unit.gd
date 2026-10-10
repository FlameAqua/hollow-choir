class_name BattleUnit
extends RefCounted
## Runtime state of one combatant. Mutated only by battle rules; presentation only reads it.
## Links to other units are unit ids (never object references) to avoid reference cycles.

var uid: int = -1
var side: Enums.Side = Enums.Side.PLAYER
var definition: CombatantDefinition
var display_name: String = ""
var is_protagonist: bool = false
var is_companion: bool = false

# Base stats. Live values (with modifiers) come from Stats.*.
var max_hp: int = 1
var base_force: int = 0
var base_guard: int = 0
var base_tempo: int = 0
var max_focus: int = 10

var hp: int = 1
var focus: int = 0

# Weapon data (party units; companions carry a fixed weapon profile).
var weapon: WeaponDefinition
var weapon_family: Enums.WeaponFamily = Enums.WeaponFamily.NONE
var weapon_damage_type: Enums.DamageType = Enums.DamageType.SLASH
var weapon_power: float = 0.0
var weapon_stagger: float = 0.0

## Party units: the actions offered in the menu (items are offered from the potion slots).
var actions: Array[ActionDefinition] = []
## Enemies: the current action set (boss phases replace it).
var enemy_actions: Array[EnemyActionDefinition] = []

# The Break (Stagger) meter. Enemies always have one; since the playtest revision each controlled
# party member has its own (BalanceConfig.party_max_break). A unit without one has max_stagger 0.
var stagger: float = 0.0
var max_stagger: float = 0.0
var break_count: int = 0
var broken_turns_left: int = 0
# Enemy-only state.
var weak_point_turns: int = 0
var weak_point_from_break: bool = false
var intent: EnemyIntent
var phase_index: int = -1
var action_uses: Dictionary[StringName, int] = {}
var last_action_id: StringName = &""
var forced_next_action: EnemyActionDefinition
## Bestiary knowledge at battle start.
var research_level: Enums.ResearchLevel = Enums.ResearchLevel.UNKNOWN
var inspected: bool = false
## Damage types this battle has revealed as weak/resistant by hitting (shown in the HUD).
var revealed_affinities: Array[Enums.DamageType] = []

var statuses: Array[StatusInstance] = []
var traits: Array[TraitInstance] = []
var buffs: Array[BuffInstance] = []
var cooldowns: Dictionary[StringName, int] = {}
## Unit currently covering this one (Intercept), or -1.
var intercepted_by: int = -1
## Unit this one is covering, or -1.
var intercepting_for: int = -1
var damaged_since_turn: bool = false
## Placed last in the next round's order (DELAY_TURN after already acting).
var delayed_next_round: bool = false


func is_alive() -> bool:
	return hp > 0


func is_enemy() -> bool:
	return side == Enums.Side.ENEMY


func is_broken() -> bool:
	return broken_turns_left > 0


## Does this unit have a Break meter at all?
func has_break_meter() -> bool:
	return max_stagger > 0.0


## May this unit answer an incoming attack with a reaction? Not while defeated or Broken.
func can_react() -> bool:
	return is_alive() and not is_broken()


func is_weak_point_exposed() -> bool:
	return weak_point_turns > 0 or weak_point_from_break


func is_channeling() -> bool:
	return intent != null and intent.channeling


func is_guarding() -> bool:
	for buff in buffs:
		if buff.definition.is_guard_stance:
			return true
	return false


func hp_fraction() -> float:
	return float(hp) / float(maxi(1, max_hp))


func enemy_def() -> EnemyDefinition:
	return definition as EnemyDefinition


func has_status(status: Enums.StatusId) -> bool:
	return get_status(status) != null


func get_status(status: Enums.StatusId) -> StatusInstance:
	for instance in statuses:
		if instance.status == status:
			return instance
	return null


func status_stacks(status: Enums.StatusId) -> int:
	var instance := get_status(status)
	return instance.stacks if instance != null else 0


func has_buff(buff: BuffDefinition) -> bool:
	return get_buff(buff) != null


func get_buff(buff: BuffDefinition) -> BuffInstance:
	if buff == null:
		return null
	for instance in buffs:
		if instance.definition == buff or (buff.id != &"" and instance.definition.id == buff.id):
			return instance
	return null


func cooldown_left(action: ActionDefinition) -> int:
	return cooldowns.get(action.id, 0)


func uses_of(action: ActionDefinition) -> int:
	return action_uses.get(action.id, 0)


## Bitmask of current statuses (bit = StatusId value), used by metrics and replays.
func status_mask() -> int:
	var mask := 0
	for instance in statuses:
		mask |= 1 << int(instance.status)
	return mask
