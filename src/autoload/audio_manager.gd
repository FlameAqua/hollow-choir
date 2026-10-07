extends Node
## Plays short sound cues through a small player pool on the SFX bus. Every battle mechanic maps to
## a cue (GDD: "Every battle mechanic must have audiovisual feedback"). Placeholder sounds are
## synthesised by tools/generate_placeholder_sfx.py and live in assets/audio/sfx/.

enum Cue {
	UI_MOVE, UI_CONFIRM, UI_CANCEL, HIT, HIT_HEAVY, WEAKNESS, PERFECT, GOOD, MISS, PARRY, BRACE,
	EVADE, BREAK, STATUS, HEAL, FOCUS, TELEGRAPH, CHANNEL, BEAT, CHARGE, VICTORY, DEFEAT,
}

const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
const POOL_SIZE := 12
const SFX_DIR := "res://assets/audio/sfx/"

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary[int, AudioStream] = {}
var _next := 0


func _ready() -> void:
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		_players.append(player)
	for cue in Cue.values():
		var path := SFX_DIR + String(Cue.keys()[cue]).to_lower() + ".wav"
		if ResourceLoader.exists(path):
			_streams[cue] = load(path)


func play(cue: Cue, pitch_variation: float = 0.0, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _streams.get(cue)
	if stream == null:
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0
	if pitch_variation > 0.0:
		player.pitch_scale += randf_range(-pitch_variation, pitch_variation)
	player.play()


func set_bus_volume(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, linear <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.001)))


func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, BUS_MASTER)
