class_name Fixtures
extends RefCounted
## Small code-built definitions for engine unit tests. Independent of authored content, so tuning
## data/ never breaks rule tests. Numbers are chosen to make expectations easy to compute.


static func balance() -> BalanceConfig:
	var config := BalanceConfig.new()
	config.damage_variance = 0.0
	config.default_guard_action = guard_action()
	config.default_inspect_action = inspect_action()
	return config


static func research() -> ResearchConfig:
	return ResearchConfig.new()


static func library(p_balance: BalanceConfig = null) -> CombatLibrary:
	var lib := CombatLibrary.new()
	lib.balance = p_balance if p_balance != null else balance()
	lib.research = research()
	for status in [burn(), wet(), shock(), bleed()]:
		lib.add_status(status)
	return lib


static func difficulty(tier: Enums.TacticalDifficulty = Enums.TacticalDifficulty.ADVENTURER,
		variance: float = 0.0) -> TacticalDifficultyProfile:
	var profile := TacticalDifficultyProfile.new()
	profile.difficulty = tier
	profile.display_name = EnumText.difficulty(tier)
	profile.score_variance = variance
	if tier == Enums.TacticalDifficulty.STORY:
		profile.avoid_lethal_combinations = true
		profile.channel_extra_turns = 1
	return profile


static func assist(kind: Enums.ExecutionAssist = Enums.ExecutionAssist.STANDARD) -> ExecutionAssistProfile:
	var profile := ExecutionAssistProfile.new()
	profile.assist = kind
	profile.display_name = EnumText.assist(kind)
	if kind == Enums.ExecutionAssist.ASSISTED:
		profile.window_scale = 2.0
		profile.time_scale = 1.3
		profile.auto_brace = true
		profile.pause_before_reaction = true
		profile.minimum_grade = Enums.ExecutionGrade.GOOD
	elif kind == Enums.ExecutionAssist.GENEROUS:
		profile.window_scale = 1.5
	elif kind == Enums.ExecutionAssist.PRECISE:
		profile.window_scale = 0.75
	return profile


# --- Statuses ------------------------------------------------------------------------------------

static func burn() -> StatusDefinition:
	var status := _status(Enums.StatusId.BURN, "Burn", "BRN")
	status.tick_timing = Enums.TickTiming.TURN_START
	status.tick_damage_per_stack = 3.0
	status.blocked_by = [Enums.StatusId.WET]
	return status


static func wet() -> StatusDefinition:
	var status := _status(Enums.StatusId.WET, "Wet", "WET")
	status.removes_on_apply = [Enums.StatusId.BURN]
	return status


static func shock() -> StatusDefinition:
	var status := _status(Enums.StatusId.SHOCK, "Shock", "SHK")
	status.default_duration = 2
	var trait_def := TraitDefinition.new()
	trait_def.id = &"shock_rules"
	trait_def.display_name = "Shock"
	trait_def.modifiers = [modifier(Enums.ModifierStat.STAGGER_TAKEN, Enums.ModifierOp.MULTIPLY, 1.5)]
	var conduct := TriggeredEffectDefinition.new()
	conduct.trigger = Enums.TriggerType.STATUS_APPLIED
	conduct.watch = Enums.TriggerWatch.TARGET
	conduct.relation = Enums.TriggerRelation.OWNER
	conduct.conditions = [condition(Enums.ConditionType.EVENT_STATUS_IS, {"status": Enums.StatusId.SHOCK}),
		condition(Enums.ConditionType.HAS_STATUS, {"on": Enums.ConditionOn.TARGET, "status": Enums.StatusId.WET})]
	conduct.effects = [effect(Enums.EffectType.STAGGER_DAMAGE, Enums.EffectTarget.TARGET, 10.0)]
	trait_def.triggers = [conduct]
	status.traits = [trait_def]
	return status


static func bleed() -> StatusDefinition:
	var status := _status(Enums.StatusId.BLEED, "Bleed", "BLD")
	status.duration_mode = Enums.DurationMode.CHARGES
	status.default_duration = 3
	status.max_duration = 6
	status.expiry_turns = 4
	status.strenuous_damage_per_stack = 4.0
	return status


static func _status(id: Enums.StatusId, name: String, glyph: String) -> StatusDefinition:
	var status := StatusDefinition.new()
	status.status = id
	status.display_name = name
	status.glyph = glyph
	status.description = name
	return status


# --- Rules building blocks -----------------------------------------------------------------------

static func modifier(stat: Enums.ModifierStat, op: Enums.ModifierOp, value: float,
		conditions: Array[ConditionDefinition] = []) -> ModifierDefinition:
	var mod := ModifierDefinition.new()
	mod.stat = stat
	mod.operation = op
	mod.value = value
	mod.conditions = conditions
	return mod


static func condition(type: Enums.ConditionType, fields: Dictionary = {}) -> ConditionDefinition:
	var cond := ConditionDefinition.new()
	cond.type = type
	for key: String in fields:
		cond.set(key, fields[key])
	return cond


static func effect(type: Enums.EffectType, target: Enums.EffectTarget, amount: float = 0.0,
		fields: Dictionary = {}) -> EffectDefinition:
	var eff := EffectDefinition.new()
	eff.type = type
	eff.target = target
	eff.amount = amount
	for key: String in fields:
		eff.set(key, fields[key])
	return eff


static func trigger(type: Enums.TriggerType, watch: Enums.TriggerWatch, relation: Enums.TriggerRelation,
		effects: Array[EffectDefinition], conditions: Array[ConditionDefinition] = [],
		max_per_round: int = 0) -> TriggeredEffectDefinition:
	var trig := TriggeredEffectDefinition.new()
	trig.trigger = type
	trig.watch = watch
	trig.relation = relation
	trig.effects = effects
	trig.conditions = conditions
	trig.max_per_round = max_per_round
	return trig


static func trait_with(name: String, modifiers: Array[ModifierDefinition] = [],
		triggers: Array[TriggeredEffectDefinition] = []) -> TraitDefinition:
	var trait_def := TraitDefinition.new()
	trait_def.id = StringName(name.to_snake_case())
	trait_def.display_name = name
	trait_def.modifiers = modifiers
	trait_def.triggers = triggers
	return trait_def


# --- Actions -------------------------------------------------------------------------------------

static func timing_command() -> ActionCommandDefinition:
	var command := ActionCommandDefinition.new()
	command.type = Enums.ActionCommandType.TIMING
	command.duration_ms = 1000.0
	command.target_position = 0.75
	command.good_window_ms = 300.0
	command.perfect_window_ms = 100.0
	command.lead_in_ms = 400.0
	return command


static func strike(id: StringName = &"strike") -> ActionDefinition:
	var action := ActionDefinition.new()
	action.id = id
	action.display_name = "Strike"
	action.category = Enums.ActionCategory.ATTACK
	action.uses_weapon_power = true
	action.uses_weapon_stagger = true
	action.generates_focus = true
	action.command = timing_command()
	return action


static func technique(id: StringName, focus_cost: int, power_multiplier: float,
		effects: Array[EffectDefinition] = []) -> ActionDefinition:
	var action := ActionDefinition.new()
	action.id = id
	action.display_name = String(id).capitalize()
	action.category = Enums.ActionCategory.TECHNIQUE
	action.focus_cost = focus_cost
	action.uses_weapon_power = true
	action.weapon_power_multiplier = power_multiplier
	action.uses_weapon_stagger = true
	action.effects = effects
	action.command = timing_command()
	return action


static func guard_action() -> ActionDefinition:
	var buff := BuffDefinition.new()
	buff.id = &"guarding"
	buff.display_name = "Guarding"
	buff.is_guard_stance = true
	buff.expiry = Enums.BuffExpiry.OWNER_TURN_START
	buff.trait_def = trait_with("Guarding", [modifier(Enums.ModifierStat.DAMAGE_TAKEN, Enums.ModifierOp.MULTIPLY, 0.5)])
	var action := ActionDefinition.new()
	action.id = &"guard"
	action.display_name = "Guard"
	action.category = Enums.ActionCategory.GUARD
	action.target_rule = Enums.TargetRule.SELF
	action.effects = [effect(Enums.EffectType.GRANT_BUFF, Enums.EffectTarget.OWNER, 0.0, {"buff": buff}),
		effect(Enums.EffectType.GAIN_FOCUS, Enums.EffectTarget.OWNER, 1.0)]
	return action


static func inspect_action() -> ActionDefinition:
	var action := ActionDefinition.new()
	action.id = &"inspect"
	action.display_name = "Inspect"
	action.category = Enums.ActionCategory.INSPECT
	action.target_rule = Enums.TargetRule.SINGLE_ENEMY
	action.effects = [effect(Enums.EffectType.GAIN_FOCUS, Enums.EffectTarget.OWNER, 1.0)]
	return action


static func enemy_attack(id: StringName = &"claw", power: float = 10.0) -> EnemyActionDefinition:
	var action := EnemyActionDefinition.new()
	action.id = id
	action.display_name = String(id).capitalize()
	action.category = Enums.ActionCategory.ATTACK
	action.damage_type = Enums.DamageType.SLASH
	action.power = power
	action.telegraph_text = "Attacks."
	return action


# --- Combatants ----------------------------------------------------------------------------------

static func sword(power: float = 20.0, stagger: float = 10.0) -> WeaponDefinition:
	var weapon := WeaponDefinition.new()
	weapon.id = &"test_sword"
	weapon.display_name = "Test Sword"
	weapon.family = Enums.WeaponFamily.SWORD
	weapon.damage_type = Enums.DamageType.SLASH
	weapon.base_power = power
	weapon.base_stagger = stagger
	weapon.basic_attack = strike()
	weapon.traits = [trait_with("Test Edge")]
	return weapon


static func hero(force: int = 0, guard: int = 0, tempo: int = 10, max_hp: int = 100) -> ProtagonistDefinition:
	var definition := ProtagonistDefinition.new()
	definition.id = &"hero"
	definition.display_name = "Hero"
	definition.max_hp = max_hp
	definition.force = force
	definition.guard = guard
	definition.tempo = tempo
	return definition


static func companion(tempo: int = 9) -> CompanionDefinition:
	var definition := CompanionDefinition.new()
	definition.id = &"buddy"
	definition.display_name = "Buddy"
	definition.max_hp = 100
	definition.force = 0
	definition.guard = 0
	definition.tempo = tempo
	definition.weapon_power = 10.0
	definition.weapon_stagger = 5.0
	definition.basic_action = strike(&"buddy_strike")
	definition.techniques = [technique(&"buddy_tech_a", 2, 1.5), technique(&"buddy_tech_b", 2, 1.5)]
	definition.passive = trait_with("Buddy Passive")
	return definition


static func enemy(id: StringName = &"dummy", max_hp: int = 200, guard: int = 0, tempo: int = 5,
		actions: Array[EnemyActionDefinition] = []) -> EnemyDefinition:
	var definition := EnemyDefinition.new()
	definition.id = id
	definition.display_name = String(id).capitalize()
	definition.max_hp = max_hp
	definition.force = 0
	definition.guard = guard
	definition.tempo = tempo
	definition.max_stagger = 50.0
	if actions.is_empty():
		definition.actions = [enemy_attack()]
	else:
		definition.actions = actions
	return definition


static func loadout(weapon: WeaponDefinition = null, hero_def: ProtagonistDefinition = null,
		companion_def: CompanionDefinition = null) -> PartyLoadout:
	var party := PartyLoadout.new()
	party.id = &"test_party"
	party.protagonist = hero_def if hero_def != null else hero()
	party.weapon = weapon if weapon != null else sword()
	party.companion = companion_def
	return party


static func setup(enemies: Array[EnemyDefinition], party: PartyLoadout = null, seed: int = 1,
		lib: CombatLibrary = null, tier: Enums.TacticalDifficulty = Enums.TacticalDifficulty.ADVENTURER,
		assist_kind: Enums.ExecutionAssist = Enums.ExecutionAssist.STANDARD) -> BattleSetup:
	var battle_setup := BattleSetup.new()
	battle_setup.loadout = party if party != null else loadout()
	battle_setup.enemies = enemies
	battle_setup.library = lib if lib != null else library()
	battle_setup.difficulty = difficulty(tier)
	battle_setup.assist = assist(assist_kind)
	battle_setup.seed = seed
	return battle_setup
