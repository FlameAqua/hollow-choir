class_name MusicLibrary
extends Resource
@export var playlists: Array[MusicPlaylist] = []

func find(cue_id: StringName) -> MusicPlaylist:
	for playlist in playlists:
		if playlist != null and playlist.cue_id == cue_id:
			return playlist
	return null
