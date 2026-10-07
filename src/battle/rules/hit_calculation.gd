class_name HitCalculation
extends RefCounted
## Result of DamageCalculator: the numbers behind one hit, plus an optional human-readable
## breakdown for the analysis-layer tooltip (GDD "Interface philosophy").

var damage_type: Enums.DamageType = Enums.DamageType.NONE
## Damage before the variance roll (after every multiplier, including the reaction).
var expected: float = 0.0
var minimum: int = 0
var maximum: int = 0
var stagger: float = 0.0
var is_weakness: bool = false
var is_resisted: bool = false
var hits_weak_point: bool = false
var broken_bonus: bool = false
## A reaction reduced the damage to nothing.
var negated: bool = false
var breakdown: PackedStringArray = PackedStringArray()


## Rolls the final integer damage on the battle RNG (consumes exactly one roll when variance > 0).
func roll(ctx: BattleContext) -> int:
	if negated:
		return 0
	var value := expected * ctx.roll_variance()
	return maxi(ctx.balance.minimum_damage, roundi(value))
