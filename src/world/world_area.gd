class_name WorldArea
extends Node2D
## One editable area scene: native TileMapLayers plus placed instances, with backend-owned geometry
## in named groups. Layers: Ground, GroundDetail, LowDecoration, DepthSorted (shared Y-sort),
## Overhead, WorldLighting, WorldEffects; Collision (painted solid cells) and Solids (footprints);
## Interactions (WorldPoint per landmark), Anchors (Marker2D per safe anchor), Portals (WorldPortal).

@export var area_id: StringName = &""


func depth_layer() -> Node2D:
	return $DepthSorted


func collision_layer_node() -> TileMapLayer:
	return $Collision


## Surface is authored TileSet data. Decoration takes precedence over the ground beneath it.
func surface_at(feet: Vector2) -> StringName:
	for layer: TileMapLayer in [$GroundDetail, $Ground]:
		var cell := layer.local_to_map(layer.to_local(to_global(feet)))
		var data := layer.get_cell_tile_data(cell)
		if data != null and layer.tile_set.get_custom_data_layer_by_name("surface") >= 0:
			var surface: String = data.get_custom_data("surface")
			if not surface.is_empty():
				return StringName(surface)
	return &"peat"


func has_point(landmark_id: StringName) -> bool:
	return has_node(NodePath("Interactions/" + String(landmark_id)))


func point(landmark_id: StringName) -> Vector2:
	var node := get_node_or_null(NodePath("Interactions/" + String(landmark_id))) as Node2D
	return node.position if node != null else Vector2.INF


func has_anchor(anchor_id: StringName) -> bool:
	return has_node(NodePath("Anchors/" + String(anchor_id)))


func anchor(anchor_id: StringName) -> Vector2:
	var node := get_node_or_null(NodePath("Anchors/" + String(anchor_id))) as Node2D
	return node.position if node != null else Vector2.INF


func portals() -> Array[WorldPortal]:
	var result: Array[WorldPortal] = []
	for child in $Portals.get_children():
		if child is WorldPortal:
			result.append(child)
	return result


## The portal landmark whose trigger contains [param feet], or &"".
func portal_at(feet: Vector2) -> StringName:
	for portal in portals():
		if portal.trigger_rect().has_point(feet):
			return StringName(portal.name)
	return &""


## landmark id -> area pixel position, for the map and discovery.
func landmark_positions() -> Dictionary:
	var result := {}
	for child in $Interactions.get_children():
		if child is Node2D:
			result[StringName(child.name)] = (child as Node2D).position
	return result


## Applies flag/cleared visibility and collision to every WorldStateView in the area.
func apply_state(world: WorldState) -> void:
	for view in state_views():
		view.apply(world)


func state_views() -> Array[WorldStateView]:
	var result: Array[WorldStateView] = []
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is WorldStateView:
			result.append(node)
		stack.append_array(node.get_children())
	return result
