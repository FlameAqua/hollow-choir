class_name MusicMixer
extends Node
## Two streaming decks on one real-time transport. Crossfades use equal power and never consume
## gameplay RNG. Independent full mixes are sequenced, not falsely presented as synchronized stems.
const SILENCE_DB := -80.0
const SCENE_FADE := 0.75
const END_PREVIEW_SECONDS := 5.0
## Shortest end overlap, for a mix that is already closer to its end than its crossfade.
const MIN_END_OVERLAP := 0.05
var library: MusicLibrary
var cue_id: StringName = &""
var tone: StringName = &"base"
var current_track: MusicTrack
var transition_reason: StringName = &""
var _players: Array[AudioStreamPlayer] = []
## Track loaded on each deck, so a switch back to a still-sounding mix can reuse its deck.
var _tracks: Array[MusicTrack] = [null, null]
var _levels: Array[float] = [0.0, 0.0]
var _from: Array[float] = [0.0, 0.0]
var _to: Array[float] = [0.0, 0.0]
var _active := -1
var _fade_start := 0
var _fade_duration := 0.0
var _fading := false
## Per deck: the position given to its last play/seek, until the audio server mixes that deck.
var _pending: Array[bool] = [false, false]
var _written: Array[float] = [0.0, 0.0]
var _written_usec: Array[int] = [0, 0]
var _mix_age_at_write: Array[float] = [0.0, 0.0]
var _rng := RandomNumberGenerator.new()
var _bags: Dictionary[String, Array] = {}
var _last: Dictionary[String, StringName] = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.name = "MusicDeck%d" % index
		player.bus = &"Music"
		player.volume_db = SILENCE_DB
		add_child(player)
		_players.append(player)
		player.finished.connect(_on_finished.bind(index))

func request(next_cue: StringName, next_tone: StringName = &"base") -> void:
	if cue_id == next_cue and tone == next_tone:
		return
	var in_place := cue_id == next_cue and current_track != null
	cue_id = next_cue
	tone = next_tone
	var track := _pick(in_place)
	if track == null:
		current_track = null
		transition_reason = &"stop"
		_active = -1
		_fade([0.0, 0.0], SCENE_FADE)
		return
	if in_place and track == current_track:
		_remember(track)
		return
	if in_place:
		_switch_in_place(track, &"tone")
	else:
		_start_track(track, SCENE_FADE, 0.0, &"cue")

## Same-song selections retain source time; a new song starts at zero. Rotation remains random.
func audition(next_cue: StringName, track_id: StringName) -> bool:
	var playlist := library.find(next_cue) if library != null else null
	if playlist == null:
		return false
	for track in playlist.tracks:
		if track != null and track.id == track_id and track.playable():
			var in_place := cue_id == next_cue and current_track != null
			cue_id = next_cue
			tone = track.tone
			if in_place and track == current_track:
				_remember(track)
			elif in_place:
				_switch_in_place(track, &"selection")
			else:
				_start_track(track, SCENE_FADE, 0.0, &"selection")
			return true
	return false

func next_mix() -> bool:
	var track := _pick()
	if track == null:
		return false
	_start_track(track, SCENE_FADE, 0.0, &"next")
	return true

## Debug seek commits the selected deck, discarding any outgoing audio at the old timestamp.
func seek(seconds: float) -> bool:
	if current_track == null or _active < 0 or not is_finite(seconds):
		return false
	_fading = false
	for index in 2:
		if index == _active:
			# play() rather than AudioStreamPlayer.seek(): a deck that just ended restarts too.
			_play(index, current_track, seconds, _gain(current_track))
		else:
			_release(index)
	transition_reason = &"seek"
	return true

## Shorten a listening check without changing normal loop scheduling or stream metadata.
func test_loop() -> bool:
	if _fading or _active < 0 or current_track == null:
		return false
	return seek(current_track.stream.get_length() - current_track.fade_seconds() - END_PREVIEW_SECONDS)

## Stream time this deck mixes next. Same-timestamp switches start the incoming deck here; the time
## since the last mix belongs to audio already handed to the device, so adding it would start the
## new deck ahead of the old one (and walk the song forward on every switch).
func _cursor(index: int) -> float:
	if index < 0 or _tracks[index] == null or not _players[index].playing:
		return 0.0
	return _players[index].get_playback_position() if _mixed(index) else _written[index]

## Listening estimate for status and the Audio Lab: Godot's documented interpolation, once mixed.
func _position() -> float:
	if _active < 0 or current_track == null or not _players[_active].playing:
		return 0.0
	var position := _written[_active]
	if _mixed(_active):
		position = _players[_active].get_playback_position() + AudioServer.get_time_since_last_mix()
	return clampf(position, 0.0, current_track.stream.get_length())

## Until the server's first mix after play/seek, the playback has produced no audio: its decoder
## has read ahead and the server's last-mix age belongs to an earlier command.
func _mixed(index: int) -> bool:
	if _pending[index]:
		var elapsed := (Time.get_ticks_usec() - _written_usec[index]) / 1000000.0
		if AudioServer.get_time_since_last_mix() < _mix_age_at_write[index] + elapsed - 0.002:
			_pending[index] = false
	return not _pending[index]

func _stream_position(track: MusicTrack, source_position: float) -> float:
	return _clamp_position(track, source_position - track.source_offset_seconds)

func _clamp_position(track: MusicTrack, seconds: float) -> float:
	return clampf(seconds, 0.0, maxf(0.0, track.stream.get_length() - 0.001))

func _gain(track: MusicTrack) -> float:
	return db_to_linear(clampf(track.gain_db, SILENCE_DB, 0.0))

func playback_status() -> Dictionary:
	var duration := current_track.stream.get_length() if current_track != null else 0.0
	var position := _position()
	return {"cue": cue_id, "requested_tone": tone, "track": current_track.id if current_track != null else &"",
		"tone": current_track.tone if current_track != null else &"", "position": position, "duration": duration,
		"source_position": position + current_track.source_offset_seconds if current_track != null else 0.0,
		"transition": transition_reason,
		"seconds_until_transition": maxf(0.0, duration - position - current_track.fade_seconds()) if current_track != null else 0.0,
		"fading": _fading, "players": playing_count()}

func _pick(prefer_version: bool = false) -> MusicTrack:
	var playlist := library.find(cue_id) if library != null else null
	if playlist == null:
		return null
	var available := playlist.available(tone)
	if available.is_empty():
		return null
	# Tone changes prefer the same arrangement version. This is still a full-mix crossfade;
	# aligned simultaneous layers need explicit content and a synchronized playback adapter.
	if prefer_version and current_track != null:
		for track in available:
			if track.version == current_track.version:
				return track
	var key := String(cue_id) + ":" + String(tone)
	var bag: Array = _bags.get(key, [])
	if bag.is_empty():
		bag.assign(available)
		for index in range(bag.size() - 1, 0, -1):
			var swap := _rng.randi_range(0, index)
			var value: MusicTrack = bag[index]
			bag[index] = bag[swap]
			bag[swap] = value
		if bag.size() > 1 and bag.back().id == _last.get(key, &""):
			var first: MusicTrack = bag[0]
			bag[0] = bag.back()
			bag[bag.size() - 1] = first
	var chosen: MusicTrack = bag.pop_back()
	_bags[key] = bag
	_last[key] = chosen.id
	return chosen

func _remember(track: MusicTrack) -> void:
	# Explicit auditions and same-version tone switches must also avoid an immediate repeat.
	var key := String(cue_id) + ":" + String(tone)
	var bag: Array = _bags.get(key, [])
	bag.erase(track)
	_bags[key] = bag
	_last[key] = track.id

## Crossfade to another mix of the playing song at the same source time.
func _switch_in_place(track: MusicTrack, reason: StringName) -> void:
	var other := 1 - _active
	if _tracks[other] == track and _players[other].playing:
		# Still sounding on the outgoing deck (a quick switch back): fade back to it instead of
		# starting a second copy a few milliseconds apart, which would comb-filter.
		_remember(track)
		_update_fade(Time.get_ticks_usec())
		_active = other
		current_track = track
		transition_reason = reason
		var target: Array[float] = [0.0, 0.0]
		target[other] = _gain(track)
		_fade(target, SCENE_FADE)
		return
	var source_position := _cursor(_active) + current_track.source_offset_seconds
	_start_track(track, SCENE_FADE, _stream_position(track, source_position), reason)

func _start_track(track: MusicTrack, duration: float, position: float = 0.0, reason: StringName = &"end") -> void:
	_remember(track)
	_update_fade(Time.get_ticks_usec())
	# During rapid requests preserve the louder deck, replacing the quieter one.
	var keep := 0 if _levels[0] >= _levels[1] else 1
	var next := 1 - keep
	_play(next, track, position, 0.0)
	_active = next
	current_track = track
	transition_reason = reason
	var target: Array[float] = [0.0, 0.0]
	target[next] = _gain(track)
	_fade(target, duration)

func _play(index: int, track: MusicTrack, position: float, level: float) -> void:
	var player := _players[index]
	var start := _clamp_position(track, position)
	player.stop()
	player.stream = track.stream
	player.pitch_scale = 1.0
	_levels[index] = level
	player.volume_db = linear_to_db(maxf(level, 0.0001))
	player.play(start)
	_tracks[index] = track
	_pending[index] = true
	_written[index] = start
	_written_usec[index] = Time.get_ticks_usec()
	_mix_age_at_write[index] = AudioServer.get_time_since_last_mix()

func _release(index: int) -> void:
	_players[index].stop()
	_players[index].stream = null
	_players[index].volume_db = SILENCE_DB
	_tracks[index] = null
	_levels[index] = 0.0

func _fade(target: Array[float], duration: float) -> void:
	_from = _levels.duplicate()
	_to = target
	_fade_start = Time.get_ticks_usec()
	_fade_duration = maxf(0.001, duration)
	_fading = true

func _process(_delta: float) -> void:
	_update_fade(Time.get_ticks_usec())
	if _fading or _active < 0 or current_track == null or not _players[_active].playing:
		return
	var remaining := current_track.stream.get_length() - _cursor(_active)
	if remaining <= current_track.fade_seconds():
		var next := _pick()
		if next != null:
			# Overlap only what is left: a fade-out longer than the outgoing mix would end in a dip.
			_start_track(next, clampf(remaining, MIN_END_OVERLAP, minf(current_track.fade_seconds(), next.fade_seconds())))

func _update_fade(now_usec: int) -> void:
	if not _fading:
		return
	var amount := clampf((now_usec - _fade_start) / 1000000.0 / _fade_duration, 0.0, 1.0)
	for index in 2:
		_levels[index] = sqrt(lerpf(_from[index] * _from[index], _to[index] * _to[index], amount))
		_players[index].volume_db = linear_to_db(maxf(_levels[index], 0.0001))
		if amount >= 1.0 and _to[index] == 0.0:
			_release(index)
	_fading = amount < 1.0

func _on_finished(index: int) -> void:
	if index != _active:
		return
	# Late-frame recovery: never leave a playlist silent if a finish precedes our scheduling tick.
	var next := _pick()
	if next != null:
		_start_track(next, SCENE_FADE)

func playing_count() -> int:
	var count := 0
	for player in _players:
		count += int(player.playing)
	return count

func _exit_tree() -> void:
	for index in _players.size():
		_release(index)
