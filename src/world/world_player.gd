class_name WorldPlayer
extends CharacterBody2D
## Hollow in the world: continuous eight-direction movement with normalized diagonals and a small
## feet box (16×9, immediately above the foot origin). The eight-facing art follows the input
## direction; walking plays only while the body actually moves, never while pushing into a wall.
## The host owns input: it calls step() with an already-gated direction.

const VISUAL := preload("res://assets/art/world/first_footsteps_v01/scenes/hollow.tscn")
const FEET := Vector2(16, 9)
const SPEED := 128.0
## Below this displacement per second the body counts as standing still.
const MOVING_EPSILON := 4.0
## Screen angle (y down) of each facing, and the hold band past a sector edge (see facing_for).
const FACING_DEGREES := {&"east": 0.0, &"southeast": 45.0, &"south": 90.0, &"southwest": 135.0, &"west": 180.0,
	&"northwest": -135.0, &"north": -90.0, &"northeast": -45.0}
const FACING_HOLD := 7.5

var facing := &"south"
var moving := false
var _sprite: AnimatedSprite2D
var _camera: Camera2D
var _visual: Node2D
var _step_distance := 0.0
signal footstep(at: Vector2)


func _init() -> void:
	name = "Player"
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 1
	collision_mask = 2
	var shape := RectangleShape2D.new()
	shape.size = FEET
	var feet := CollisionShape2D.new()
	feet.name = "Feet"
	feet.shape = shape
	feet.position = Vector2(0, -FEET.y * 0.5)
	add_child(feet)
	_visual = VISUAL.instantiate() as Node2D
	add_child(_visual)
	_sprite = _visual.get_node("Visual") as AnimatedSprite2D
	var idle_material := ShaderMaterial.new()
	idle_material.shader = preload("res://src/ui/world/hollow_idle.gdshader")
	_sprite.material = idle_material
	_camera = Camera2D.new()
	_camera.name = "Camera"
	_camera.zoom = Vector2(2, 2)
	# The compact HUD header covers the top of the canvas; frame Hollow slightly below centre.
	_camera.offset = Vector2(0, -24)
	_camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(_camera)
	_play()


func camera() -> Camera2D:
	return _camera


## Clamp the following camera to the area so it never shows outside the map.
func set_bounds(area_size: Vector2) -> void:
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(area_size.x)
	_camera.limit_bottom = int(area_size.y)


func place(at: Vector2, face: StringName = &"") -> void:
	position = at
	velocity = Vector2.ZERO
	moving = false
	_step_distance = 0.0
	if face != &"":
		facing = face
	_play()
	_snap_presentation()
	_camera.reset_smoothing()


## One physics step. [param direction] is already limited to the unit circle.
func step(direction: Vector2, delta: float) -> void:
	if direction.length() > 1.0:
		direction = direction.normalized()
	if direction != Vector2.ZERO:
		facing = facing_for(direction, facing)
	var before := position
	velocity = direction * SPEED
	move_and_slide()
	moving = delta > 0.0 and (position - before).length() / delta > MOVING_EPSILON
	if moving:
		_step_distance += position.distance_to(before)
		if _step_distance >= 34.0:
			_step_distance = fmod(_step_distance, 34.0)
			footstep.emit(position)
	else:
		_step_distance = 0.0
	_play()
	_snap_presentation()


## Snap the art and following camera together at 2×; the physical feet keep continuous precision.
func _snap_presentation() -> void:
	var correction := position.round() - position
	_visual.position = correction
	_camera.position = correction


func stop() -> void:
	velocity = Vector2.ZERO
	moving = false
	_play()


## Eight stable 45-degree sectors; stopping keeps the last facing. A stick held near a sector edge
## keeps the current facing within FACING_HOLD degrees past it, so analog noise cannot flip the art
## (and restart its walk cycle) every frame. Keyboard directions sit 45 degrees apart and always turn.
static func facing_for(direction: Vector2, current: StringName) -> StringName:
	if direction == Vector2.ZERO:
		return current
	if FACING_DEGREES.has(current) and absf(angle_difference(direction.angle(), deg_to_rad(FACING_DEGREES[current]))) \
			<= deg_to_rad(22.5 + FACING_HOLD):
		return current
	var horizontal := &"east" if direction.x > 0.0 else &"west"
	var vertical := &"south" if direction.y > 0.0 else &"north"
	var ax := absf(direction.x)
	var ay := absf(direction.y)
	if ay < ax * 0.4142:
		return horizontal
	if ax < ay * 0.4142:
		return vertical
	return StringName(String(vertical) + String(horizontal))


func animation_name() -> StringName:
	return StringName(("walk_" if moving else "idle_") + String(facing))


func _play() -> void:
	if _sprite == null:
		return
	var animation := animation_name()
	# The delivered front-diagonal idle pair faces right; mirror it for southwest only.
	_sprite.flip_h = not moving and facing == &"southwest"
	(_sprite.material as ShaderMaterial).set_shader_parameter("standing", not moving)
	if not moving and Settings.data.reduce_motion:
		_sprite.animation = animation
		_sprite.stop()
		_sprite.frame = 0
		return
	if _sprite.animation != animation:
		_sprite.play(animation)
	elif not _sprite.is_playing():
		_sprite.play()
