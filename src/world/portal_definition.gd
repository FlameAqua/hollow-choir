class_name PortalDefinition
extends Resource
## One direction of a paired exit: leaving [member from_area] at [member from_landmark] arrives at
## [member arrival_anchor] in [member to_area]. The arrival anchor lies outside every trigger.

@export var from_area: StringName = &""
@export var from_landmark: StringName = &""
@export var to_area: StringName = &""
@export var arrival_anchor: StringName = &""
