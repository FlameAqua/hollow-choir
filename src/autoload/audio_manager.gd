extends Node
## Plays music playlists through two streaming decks and short cues through a pool on the SFX bus.
## Every battle mechanic maps to
## a cue (GDD: "Every battle mechanic must have audiovisual feedback"). Soft material sounds are
## synthesised by tools/generate_placeholder_sfx.py; see assets/audio/sfx/README.md.

enum Cue {
	UI_MOVE, UI_CONFIRM, UI_CANCEL, HIT, HIT_HEAVY, WEAKNESS, PERFECT, GOOD, MISS, PARRY, BRACE,
	EVADE, BREAK, STATUS, HEAL, FOCUS, TELEGRAPH, CHANNEL, BEAT, CHARGE, VICTORY, DEFEAT,
	STEP_PEAT, STEP_STONE, STEP_WOOD,
}

const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
const POOL_SIZE := 12
const SFX_DIR := "res://assets/audio/sfx/"

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary[int, AudioStream] = {}
var _next := 0
var music: MusicMixer


func _ready() -> void:
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)
	music = MusicMixer.new()
	music.library = load("res://assets/audio/music/runtime_library.tres")
	add_child(music)
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


## Stops every cue voice and cuts the music at once (test and capture teardown). The audio server
## drops a stopped playback on its next mix, so callers that exit afterwards should let a few
## frames pass; a voice still mixing at process exit is otherwise reported as a leaked instance.
func silence() -> void:
	for player in _players:
		player.stop()
		player.stream = null
	music.cut()


func set_bus_volume(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, linear <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.001)))


func request_music(cue_id: StringName, tone: StringName = &"base") -> void:
	music.request(cue_id, tone)


func battle_music(setup: BattleSetup) -> StringName:
	for enemy in setup.enemies:
		if enemy.id == &"mirebell_cantor":
			return &"briarfen_boss_mirebell"
	return &"briarfen_battle"


func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, BUS_MASTER)
