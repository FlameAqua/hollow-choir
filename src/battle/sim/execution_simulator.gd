class_name ExecutionSimulator
extends RefCounted
## Approximates human execution for automated battles (GDD "AI and balance testing").
## Uses its own RNG, so switching skill profiles never shifts the battle's own random stream.

## How much a successful parry's Stagger is worth when choosing a reaction (fraction of a hit).
const PARRY_STAGGER_VALUE := 0.15

var profile: ExecutionSkillProfile
var rng := RandomNumberGenerator.new()


func _init(p_profile: ExecutionSkillProfile, seed: int = 1) -> void:
	profile = p_profile
	rng.seed = seed


func grade_command(spec: CommandSpec, assist: ExecutionAssistProfile) -> Enums.ExecutionGrade:
	if spec.type == Enums.ActionCommandType.NONE:
		return Enums.ExecutionGrade.GOOD
	var window_scale := assist.window_scale if assist != null else 1.0
	var perfect := profile.perfect_weight * window_scale
	var miss := profile.miss_weight / maxf(0.01, window_scale)
	var good := profile.good_weight
	var roll := rng.randf() * (perfect + good + miss)
	if roll < perfect:
		return Enums.ExecutionGrade.PERFECT
	if roll < perfect + good:
		return Enums.ExecutionGrade.GOOD
	return Enums.ExecutionGrade.MISS


## Picks the reaction with the best expected outcome for this skill level, then rolls success.
func react(balance: BalanceConfig, request: ReactionRequest) -> ReactionResult:
	if not profile.reacts:
		return ReactionResult.none()
	var spec := request.spec
	var best_type := Enums.ReactionType.NONE
	var best_value := 1.0
	var best_chance := 0.0
	for reaction in spec.allowed:
		var chance := success_chance(balance, spec, reaction)
		var success_mult := _success_multiplier(balance, reaction)
		var fail_mult := _fail_multiplier(balance, reaction)
		var value := chance * success_mult + (1.0 - chance) * fail_mult
		if reaction == Enums.ReactionType.PARRY:
			value -= chance * PARRY_STAGGER_VALUE
		if value < best_value:
			best_value = value
			best_type = reaction
			best_chance = chance
	if best_type == Enums.ReactionType.NONE:
		return ReactionResult.none()
	return ReactionResult.make(best_type, rng.randf() < best_chance)


## Profile success chance, adjusted for how much wider/narrower the actual window is than baseline.
func success_chance(balance: BalanceConfig, spec: ReactionSpec, reaction: Enums.ReactionType) -> float:
	var base := profile.success_chance(reaction)
	var baseline := balance.reaction_window_ms(reaction)
	if baseline <= 0.0:
		return base
	var ratio := spec.window_for(reaction) / baseline
	return clampf(1.0 - pow(1.0 - base, ratio), 0.0, 1.0)


static func _success_multiplier(balance: BalanceConfig, reaction: Enums.ReactionType) -> float:
	match reaction:
		Enums.ReactionType.BRACE:
			return balance.brace_damage_multiplier
		Enums.ReactionType.EVADE:
			return balance.evade_success_multiplier
		Enums.ReactionType.PARRY:
			return balance.parry_success_multiplier
	return 1.0


static func _fail_multiplier(balance: BalanceConfig, reaction: Enums.ReactionType) -> float:
	match reaction:
		Enums.ReactionType.EVADE:
			return balance.evade_fail_multiplier
		Enums.ReactionType.PARRY:
			return balance.parry_fail_multiplier
	return 1.0
