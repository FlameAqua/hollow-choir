class_name ActionPreview
extends RefCounted
## What the selected action is expected to do, per execution grade (GDD "selected action preview",
## "Advanced previews should show expected damage ranges"). Arrays are indexed by ExecutionGrade.

var action: ActionDefinition
var actor_uid: int = -1
## The unit the action would actually hit (after Intercept cover).
var target_uid: int = -1
## The unit that was chosen when cover redirects the hit to [member target_uid], otherwise -1.
var redirected_from: int = -1
var deals_damage: bool = false
var damage_min: Array[int] = [0, 0, 0]
var damage_max: Array[int] = [0, 0, 0]
var stagger: Array[float] = [0.0, 0.0, 0.0]
var heal: Array[int] = [0, 0, 0]
var focus_gain: Array[int] = [0, 0, 0]
var focus_cost: int = 0
var damage_type: Enums.DamageType = Enums.DamageType.NONE
var is_weakness: bool = false
var is_resisted: bool = false
## False until research/inspection/hits reveal the target's affinity for this damage type.
var affinity_known: bool = false
var hits_weak_point: bool = false
var target_broken: bool = false
var would_break: bool = false
var would_kill: bool = false
var statuses: Array[Enums.StatusId] = []
var area_targets: int = 1
## Analysis-layer lines for the GOOD grade.
var breakdown: PackedStringArray = PackedStringArray()
