class_name GameSettings
extends RefCounted
## Player settings (global, not per save slot; DECISION_LOG D-009). Pure data + (de)serialisation;
## the Settings autoload applies them. Covers the GDD accessibility list.

enum Toggle { DEFAULT = 0, ON = 1, OFF = 2 }
enum WindowMode { WINDOWED = 0, FULLSCREEN = 1, BORDERLESS = 2 }
## Details (analysis layer): held, toggled by a press, or always on. Append-only (saved as ints).
enum TooltipMode { HOLD = 0, ALWAYS = 1, TOGGLE = 2 }

# Gameplay — two independent difficulty axes (GDD "Accessibility").
var tactical_difficulty: Enums.TacticalDifficulty = Enums.TacticalDifficulty.ADVENTURER
var execution_assist: Enums.ExecutionAssist = Enums.ExecutionAssist.STANDARD
## Overrides the assist preset's automatic Brace.
var auto_brace: Toggle = Toggle.DEFAULT
## Overrides the assist preset's pause before reactions.
var reaction_pause: Toggle = Toggle.DEFAULT

# Display & accessibility.
var window_mode: WindowMode = WindowMode.WINDOWED
## Explicit window size; the 1280x720 design canvas scales to the selected resolution.
const BASE_RESOLUTION := Vector2i(1280, 720)
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
var window_resolution := Vector2i(1280, 720)
var screen_shake: bool = true
var reduce_flashing: bool = false
## Removes decorative motion (bobbing, pulses, drifting motes). Timing cues stay.
var reduce_motion: bool = false
var show_damage_numbers: bool = true
var advanced_tooltips: TooltipMode = TooltipMode.HOLD
## Multiplies non-interactive combat animation speed (never the reaction windows).
var combat_speed: float = 1.0
var auto_advance_text: bool = false
var subtitles: bool = true

# Audio (linear 0..1).
var master_volume: float = 0.8
var music_volume: float = 0.7
var sfx_volume: float = 0.8

## Rebinds only (action -> binding codes). Missing actions use InputBindings.DEFAULTS.
var bindings: Dictionary = {}

const SECTION_FIELDS := {
	"gameplay": ["tactical_difficulty", "execution_assist", "auto_brace", "reaction_pause"],
	"display": ["window_mode", "window_resolution", "screen_shake", "reduce_flashing", "reduce_motion", "show_damage_numbers",
		"advanced_tooltips", "combat_speed", "auto_advance_text", "subtitles"],
	"audio": ["master_volume", "music_volume", "sfx_volume"],
}


## The chosen assist preset with the player's individual overrides applied (never mutates data).
func resolve_assist(preset: ExecutionAssistProfile) -> ExecutionAssistProfile:
	var resolved: ExecutionAssistProfile = preset.duplicate()
	if auto_brace != Toggle.DEFAULT:
		resolved.auto_brace = auto_brace == Toggle.ON
	if reaction_pause != Toggle.DEFAULT:
		resolved.pause_before_reaction = reaction_pause == Toggle.ON
	return resolved


func write_to(config: ConfigFile) -> void:
	# Old settings may be reused by tools; retire the independent font preference explicitly.
	if config.has_section_key("display", "text_scale"):
		config.erase_section_key("display", "text_scale")
	for section: String in SECTION_FIELDS:
		for field: String in SECTION_FIELDS[section]:
			config.set_value(section, field, get(field))
	if config.has_section("bindings"):
		config.erase_section("bindings")
	for action in bindings:
		config.set_value("bindings", String(action), Array(bindings[action]))


func read_from(config: ConfigFile) -> void:
	for section: String in SECTION_FIELDS:
		for field: String in SECTION_FIELDS[section]:
			if config.has_section_key(section, field):
				var value: Variant = config.get_value(section, field)
				if typeof(value) == typeof(get(field)) or (typeof(get(field)) == TYPE_INT and typeof(value) == TYPE_FLOAT):
					set(field, value)
	bindings = {}
	if config.has_section("bindings"):
		for key in config.get_section_keys("bindings"):
			bindings[StringName(key)] = PackedStringArray(config.get_value("bindings", key, []))
	_clamp()


func _clamp() -> void:
	if not RESOLUTIONS.has(window_resolution):
		window_resolution = RESOLUTIONS[0]
	if not TooltipMode.values().has(int(advanced_tooltips)):
		advanced_tooltips = TooltipMode.HOLD
	combat_speed = clampf(combat_speed, 0.5, 2.0)
	master_volume = clampf(master_volume, 0.0, 1.0)
	music_volume = clampf(music_volume, 0.0, 1.0)
	sfx_volume = clampf(sfx_volume, 0.0, 1.0)


## Use only a supported preset, never a monitor-shaped arbitrary window. ZERO requests fullscreen.
static func windowed_preset(requested: Vector2i, available: Vector2i) -> Vector2i:
	var result := Vector2i.ZERO
	for preset in RESOLUTIONS:
		if preset.x <= requested.x and preset.y <= requested.y and preset.x <= available.x and preset.y <= available.y:
			result = preset
	return result
