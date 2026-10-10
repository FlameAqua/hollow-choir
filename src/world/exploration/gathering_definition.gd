class_name GatheringDefinition
extends Resource
## One authored gathering node (V0.5C): a GATHERING landmark and its explicit refresh policy. What
## it yields is an ordinary RewardDefinition (source GATHERED, source_id = the landmark id), so the
## claim, receipts, catalog checks and catch-up are the V0.5A reward path. Owned by the
## WorldDefinition beside its landmark; placement and art belong to the area scene.

enum Refresh {
	## Yields once per save. Gathering records the node in the world section and claims its reward in
	## the same write; Reset journey keeps the node gathered (and the claim kept), so a reset never
	## regrows it. No clock, timer or visit count is involved.
	ONCE_PER_SAVE = 0,
}

## The GATHERING landmark id (unique in the world).
@export var landmark: StringName = &""
@export var refresh: Refresh = Refresh.ONCE_PER_SAVE
