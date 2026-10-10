class_name LandmarkDefinition
extends Resource
## One authored place in an area (V0.4 layout): a stable ID, a public map label and the explicit
## interaction kind. Eligibility is decided by WorldRules from typed state, never by expressions.

## V0.5C appends GATHERING (a node yielding once per save), SECRET (imperceptible until revealed)
## and RUNE (one switch of a rune-sequence puzzle); their rules live in ExplorationRules.
enum Kind { HOME, DIALOGUE, PREPARATION, PORTAL, LANDMARK, ENCOUNTER, RESTORATION, SHORTCUT, DISCOVERY,
	GATHERING, SECRET, RUNE }

## V0.5 UI: the station service a PREPARATION landmark authorizes. Only an open FORGE context accepts
## Forge purchases, fittings and refunds; only an open STILLROOM context accepts Stillroom purchases.
enum Service { NONE = 0, FORGE = 1, STILLROOM = 2 }

@export var id: StringName = &""
## Public label for the HUD prompt and the discovered map. Never an encounter or species name.
@export var display_name: String = ""
@export var kind: Kind = Kind.LANDMARK
## Planning position in tiles (tile centres, y down). Scene markers are the runtime geometry.
@export var tile: Vector2i = Vector2i.ZERO
## Discovered-map description (public facts only).
@export_multiline var description: String = ""
## Confirm reaches this landmark within this many pixels of its interaction point (0 = none).
@export var interact_radius: float = 0.0
## The landmark is also a named safe anchor (a Marker2D with the same name in the area's Anchors).
@export var safe_anchor: bool = false
## ENCOUNTER only: the unchanged existing encounter this visible group launches.
@export var encounter: EncounterDefinition
## ENCOUNTER only: public threat category shown on the encounter card.
@export var threat_label: String = ""
## ENCOUNTER only: the player may bypass this group.
@export var optional: bool = false
## SHORTCUT only: direction from the interaction point to the side it can be opened from.
@export var far_side: Vector2i = Vector2i.ZERO
## Distance (pixels) at which the landmark becomes discovered when the player approaches.
@export var discover_radius: float = 192.0
## PREPARATION only: the station service it opens (V0.5 UI); NONE for every other kind.
@export var service: Service = Service.NONE


func validate(area_id: StringName) -> PackedStringArray:
	var problems := PackedStringArray()
	var where := "%s/%s" % [area_id, id]
	if id == &"":
		problems.append("%s: landmark has no id" % area_id)
	if display_name.is_empty():
		problems.append("%s: no public label" % where)
	if kind == Kind.ENCOUNTER:
		if encounter == null:
			problems.append("%s: encounter landmark without an encounter" % where)
		if threat_label.is_empty():
			problems.append("%s: encounter landmark without a public threat category" % where)
		if interact_radius <= 0.0:
			problems.append("%s: encounter landmark needs an engage radius" % where)
	if kind in [Kind.GATHERING, Kind.SECRET, Kind.RUNE] and interact_radius <= 0.0:
		problems.append("%s: an exploration landmark needs an interaction radius" % where)
	if kind == Kind.PREPARATION and service == Service.NONE:
		problems.append("%s: a preparation landmark needs a station service" % where)
	if kind != Kind.PREPARATION and service != Service.NONE:
		problems.append("%s: only a preparation landmark offers a station service" % where)
	return problems
