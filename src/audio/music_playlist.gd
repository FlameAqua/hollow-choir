class_name MusicPlaylist
extends Resource
## Explicit runtime playlist, generated from the user's authorized inbox at development time.
@export var cue_id: StringName
@export var tracks: Array[MusicTrack] = []

func available(tone: StringName = &"base") -> Array[MusicTrack]:
	var matches: Array[MusicTrack] = []
	var fallback: Array[MusicTrack] = []
	var calm: Array[MusicTrack] = []
	var playable: Array[MusicTrack] = []
	for track in tracks:
		if track == null or not track.playable():
			continue
		playable.append(track)
		if track.tone == tone:
			matches.append(track)
		if track.tone == &"base":
			fallback.append(track)
		if track.tone == &"calm":
			calm.append(track)
	if not matches.is_empty():
		return matches
	if not fallback.is_empty():
		return fallback
	return calm if not calm.is_empty() else playable
