class_name OperationFeedback
extends Node
## The one sound owner for adopted operations: each changed result arrives once, after its write
## (AudioManager.operation_cue picks the cue; -1 is silence). Never driven by buttons.
static func install(owner: Node) -> void:
	if owner.has_node("OperationFeedback"): return
	var adapter := OperationFeedback.new()
	adapter.name = "OperationFeedback"
	owner.add_child(adapter)

func _ready() -> void:
	EventBus.crafting_completed.connect(_adopted_result)
	EventBus.preparation_completed.connect(_adopted_result)
	EventBus.familiar_changed.connect(_adopted_result)

func _adopted_result(result: RefCounted) -> void:
	var cue := AudioManager.operation_cue(result)
	if cue >= 0: AudioManager.play(cue, 0, -6)
