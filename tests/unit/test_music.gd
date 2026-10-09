extends TestCase

func _track(id: StringName, version: int = 1, tone: StringName = &"base") -> MusicTrack:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 8000
	var silence := PackedByteArray()
	silence.resize(8000 * 8)
	silence.fill(128)
	stream.data = silence
	var track := MusicTrack.new()
	track.id = id
	track.version = version
	track.tone = tone
	track.stream = stream
	return track

func _mixer() -> MusicMixer:
	var playlist := MusicPlaylist.new()
	playlist.cue_id = &"test"
	playlist.tracks = [_track(&"one"), _track(&"two", 2), _track(&"three", 3)]
	var library := MusicLibrary.new()
	library.playlists = [playlist]
	var mixer := MusicMixer.new()
	mixer.library = library
	(Engine.get_main_loop() as SceneTree).root.add_child(mixer)
	return mixer

func _settle(mixer: MusicMixer) -> void:
	mixer._update_fade(mixer._fade_start + 10000000)

func test_shuffle_uses_all_versions_without_repeats_or_gameplay_rng() -> void:
	var mixer := _mixer()
	mixer.cue_id = &"test"
	var previous: StringName
	for cycle in 4:
		var ids := []
		for draw in 3:
			var track := mixer._pick()
			assert_ne(track.id, previous, "no immediate repeat at bag boundaries")
			assert_false(ids.has(track.id))
			ids.append(track.id)
			previous = track.id
	seed(771)
	var expected := randf()
	seed(771)
	mixer._pick()
	assert_eq(randf(), expected, "music selection never consumes gameplay/global RNG")
	mixer.queue_free()

func test_same_cue_preserves_deck_rapid_changes_and_missing_cues_cleanup() -> void:
	var mixer := _mixer()
	mixer.request(&"test")
	_settle(mixer)
	var deck := mixer._active
	var track := mixer.current_track
	mixer.seek(2.0)
	mixer.request(&"test")
	assert_eq(mixer._active, deck)
	assert_eq(mixer.current_track, track)
	assert_false(mixer._fading)
	assert_eq(mixer.playing_count(), 1)
	for index in 12:
		mixer.request(&"missing" if index % 2 == 0 else &"test")
		assert_lte(mixer.playing_count(), 2)
	_settle(mixer)
	assert_eq(mixer.playing_count(), 1)
	mixer.request(&"missing")
	_settle(mixer)
	assert_eq(mixer.playing_count(), 0)
	assert_eq(mixer._players.size(), 2, "players are pooled rather than allocated per request")
	mixer.queue_free()

func test_tones_prefer_matching_version_and_fallback_to_base() -> void:
	var mixer := _mixer()
	for version in 3:
		mixer.library.playlists[0].tracks.append(_track(StringName("intense%d" % version), version + 1, &"intense"))
	mixer.request(&"test")
	_settle(mixer)
	var version := mixer.current_track.version
	mixer.request(&"test", &"intense")
	assert_eq(mixer.current_track.version, version)
	assert_eq(mixer.current_track.tone, &"intense")
	_settle(mixer)
	mixer.request(&"test", &"calm")
	assert_eq(mixer.current_track.tone, &"base")
	assert_eq(mixer.current_track.version, version)
	mixer.queue_free()

func test_track_end_schedules_next_variant_and_fades_on_real_time() -> void:
	var mixer := _mixer()
	mixer.request(&"test")
	_settle(mixer)
	var previous := mixer.current_track
	mixer.seek(7.9)
	mixer._process(0.0)
	assert_ne(mixer.current_track.id, previous.id, "next deck overlaps the outro")
	assert_eq(mixer.playing_count(), 2)
	var old_speed := Engine.time_scale
	Engine.time_scale = 0.01
	_settle(mixer)
	Engine.time_scale = old_speed
	assert_eq(mixer.playing_count(), 1)
	assert_eq(mixer.process_mode, Node.PROCESS_MODE_ALWAYS, "music keeps playing during tree pause")
	mixer.queue_free()

func test_tone_only_playlist_still_plays_without_a_base_mix() -> void:
	var mixer := _mixer()
	mixer.library.playlists[0].tracks = [_track(&"calm", 1, &"calm"), _track(&"intense", 1, &"intense")]
	mixer.request(&"test")
	assert_eq(mixer.current_track.tone, &"calm", "base requests prefer calm when only tone variants exist")
	mixer.request(&"test", &"intense")
	assert_eq(mixer.current_track.tone, &"intense")
	mixer.queue_free()

func test_manual_audition_rotation_and_tone_switch_do_not_immediately_repeat() -> void:
	var mixer := _mixer()
	mixer.library.playlists[0].tracks.append(_track(&"intense_one", 1, &"intense"))
	assert_true(mixer.audition(&"test", &"one"))
	_settle(mixer)
	assert_eq(mixer.playback_status().track, &"one")
	assert_false(mixer.audition(&"test", &"missing"))
	assert_eq(mixer.current_track.id, &"one", "invalid audition preserves playback")
	mixer.request(&"test", &"intense")
	_settle(mixer)
	assert_eq(mixer.current_track.id, &"intense_one")
	mixer.request(&"test", &"base")
	_settle(mixer)
	assert_eq(mixer.current_track.id, &"one", "tone switches prefer matching version")
	assert_true(mixer.test_loop())
	assert_almost_eq(mixer.playback_status().seconds_until_transition, 5.0, 0.1,
		"end preview leaves an audible five-second run-up instead of changing immediately")
	assert_true(mixer.next_mix())
	assert_ne(mixer.current_track.id, &"one", "explicit auditions and tone changes update shuffle history")
	assert_false(mixer.test_loop(), "seeking during a crossfade is disabled")
	assert_lte(mixer.playing_count(), 2)
	_settle(mixer)
	var before := mixer.current_track
	mixer.request(&"test", &"missing_tone")
	assert_eq(mixer.current_track, before, "fallback to the playing base mix preserves position")
	assert_true(mixer.next_mix())
	assert_ne(mixer.current_track, before, "fallback tone requests also preserve shuffle history")
	mixer.queue_free()

func test_tone_and_manual_selection_preserve_position_and_preparation_offsets() -> void:
	var mixer := _mixer()
	var base := mixer.library.playlists[0].tracks[0]
	base.source_offset_seconds = 0.75
	var intense := _track(&"intense_one", 1, &"intense")
	intense.source_offset_seconds = 0.25
	mixer.library.playlists[0].tracks.append(intense)
	assert_true(mixer.audition(&"test", &"one"))
	_settle(mixer)
	assert_true(mixer.seek(2.0))
	var source_position: float = mixer.playback_status().source_position
	mixer.request(&"test", &"intense")
	assert_almost_eq(mixer.playback_status().source_position, source_position, 0.1)
	assert_almost_eq(mixer.playback_status().position, 2.5, 0.1, "trim origins map to the same source time")
	_settle(mixer)
	mixer.request(&"test", &"base")
	assert_almost_eq(mixer.playback_status().position, 2.0, 0.15)
	_settle(mixer)
	assert_true(mixer.audition(&"test", &"one"))
	assert_false(mixer._fading, "selecting the playing variant does not restart or fade")
	assert_true(mixer.audition(&"test", &"two"))
	assert_almost_eq(mixer.playback_status().source_position, source_position, 0.15)
	_settle(mixer)
	assert_true(mixer.next_mix())
	assert_lt(mixer.playback_status().position, 0.1, "Next version explicitly starts at zero")
	assert_eq(mixer.playback_status().transition, &"next")
	mixer.queue_free()

func test_seek_during_fade_commits_selected_mix_and_clamps_invalid_positions() -> void:
	var mixer := _mixer()
	mixer.request(&"test")
	_settle(mixer)
	mixer.next_mix()
	assert_eq(mixer.playing_count(), 2)
	assert_true(mixer.seek(3.0))
	assert_false(mixer._fading)
	assert_eq(mixer.playing_count(), 1, "no outgoing audio continues at the old timestamp")
	assert_almost_eq(mixer.playback_status().position, 3.0, 0.1)
	assert_false(mixer.seek(NAN))
	assert_false(mixer.seek(INF))
	assert_true(mixer.seek(-10.0))
	assert_lt(mixer.playback_status().position, 0.1)
	assert_true(mixer.seek(1000.0))
	assert_lte(mixer.playback_status().position, 8.0)
	var short := _track(&"short_tone", mixer.current_track.version, &"short")
	(short.stream as AudioStreamWAV).data = (short.stream as AudioStreamWAV).data.slice(0, 32000)
	mixer.library.playlists[0].tracks.append(short)
	mixer.request(&"test", &"short")
	assert_lte(mixer.playback_status().position, short.stream.get_length(), "shorter variants clamp to their available tail")
	assert_eq(mixer.current_track, short)
	mixer.request(&"")
	assert_false(mixer.seek(2.0))
	mixer.queue_free()

func test_rapid_tone_changes_keep_a_common_playhead_and_two_decks() -> void:
	var mixer := _mixer()
	mixer.library.playlists[0].tracks.append(_track(&"intense_one", 1, &"intense"))
	mixer.audition(&"test", &"one")
	_settle(mixer)
	mixer.seek(3.0)
	var started := Time.get_ticks_usec()
	for index in 8:
		mixer.request(&"test", &"intense" if index % 2 == 0 else &"base")
		assert_lte(mixer.playing_count(), 2)
	var elapsed := (Time.get_ticks_usec() - started) / 1000000.0
	assert_almost_eq(mixer.playback_status().position, 3.0 + elapsed, 0.1)
	mixer.queue_free()

func test_overlapping_tones_continue_at_the_same_position_after_audio_frames() -> void:
	var mixer := _mixer()
	mixer.library.playlists[0].tracks.append(_track(&"intense_one", 1, &"intense"))
	mixer.audition(&"test", &"one")
	_settle(mixer)
	mixer.seek(3.0)
	await (Engine.get_main_loop() as SceneTree).create_timer(0.15).timeout
	var outgoing := mixer._active
	mixer.request(&"test", &"intense")
	await (Engine.get_main_loop() as SceneTree).create_timer(0.15).timeout
	assert_eq(mixer.playing_count(), 2)
	assert_almost_eq(mixer._players[mixer._active].get_playback_position(),
		mixer._players[outgoing].get_playback_position(), 0.1, "both actual streams stay within one audio block")
	assert_gt(mixer.playback_status().position, 3.2)
	mixer.queue_free()

func test_same_timestamp_switch_starts_at_the_outgoing_mix_cursor() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var mixer := _mixer()
	mixer.library.playlists[0].tracks.append(_track(&"intense_one", 1, &"intense"))
	mixer.audition(&"test", &"one")
	_settle(mixer)
	mixer.seek(1.0)
	await tree.create_timer(0.25).timeout
	var measured := false
	for attempt in 40:
		await tree.create_timer(0.01).timeout
		# Well after a mix is where adding the server's last-mix age started the new deck ahead.
		var age := AudioServer.get_time_since_last_mix()
		if age < 0.004:
			continue
		var outgoing := mixer._active
		var cursor: float = mixer._players[outgoing].get_playback_position()
		mixer.request(&"test", &"intense" if mixer.tone == &"base" else &"base")
		if AudioServer.get_time_since_last_mix() < age:
			_settle(mixer) # A mix landed between the two reads; sample again.
			continue
		assert_ne(mixer._active, outgoing)
		assert_almost_eq(mixer.playback_status().position, cursor, 0.0005,
			"the incoming mix starts where the outgoing deck mixes next")
		measured = true
		break
	assert_true(measured, "a request landed between two audio mixes")
	mixer.queue_free()

func test_switching_back_reuses_the_still_sounding_deck() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var mixer := _mixer()
	mixer.library.playlists[0].tracks.append(_track(&"intense_one", 1, &"intense"))
	mixer.audition(&"test", &"one")
	_settle(mixer)
	var original := mixer._active
	await tree.create_timer(0.15).timeout
	mixer.request(&"test", &"intense")
	await tree.create_timer(0.2).timeout
	var playback := mixer._players[original].get_stream_playback()
	mixer.request(&"test", &"base")
	assert_eq(mixer._active, original, "the base mix still sounding on its deck fades back in")
	assert_eq(mixer._players[original].get_stream_playback(), playback, "it continues rather than restarting")
	assert_ne(mixer._players[0].stream, mixer._players[1].stream, "no second, offset copy of the same mix")
	assert_eq(mixer.playing_count(), 2, "the intense mix fades out instead of being cut")
	_settle(mixer)
	assert_eq(mixer.playing_count(), 1)
	assert_eq(mixer.current_track.id, &"one")
	mixer.queue_free()

func test_end_overlap_is_limited_to_the_outgoing_mix_remaining_time() -> void:
	var mixer := _mixer()
	mixer.request(&"test")
	_settle(mixer)
	var length := mixer.current_track.stream.get_length()
	var fade := mixer.current_track.fade_seconds()
	mixer.seek(length - fade)
	mixer._process(0.0)
	assert_eq(mixer.transition_reason, &"end")
	assert_almost_eq(mixer._fade_duration, fade, 0.1, "a normal end overlaps for the full crossfade")
	_settle(mixer)
	mixer.seek(mixer.current_track.stream.get_length() - 0.5)
	mixer._process(0.0)
	assert_eq(mixer.transition_reason, &"end")
	assert_lte(mixer._fade_duration, 0.5, "never fade out for longer than the outgoing mix has left")
	mixer.queue_free()

func test_seek_restarts_a_deck_that_already_ended() -> void:
	var mixer := _mixer()
	mixer.request(&"test")
	_settle(mixer)
	mixer._players[mixer._active].stop() # As if the mix ended just before its finished signal.
	assert_true(mixer.seek(2.0))
	assert_true(mixer._players[mixer._active].playing)
	assert_almost_eq(mixer.playback_status().position, 2.0, 0.1)
	assert_eq(mixer.playing_count(), 1)
	mixer.queue_free()

func test_runtime_playlists_include_intense_example_and_music_mute() -> void:
	var library: MusicLibrary = load("res://assets/audio/music/runtime_library.tres")
	assert_eq(library.playlists.size(), 5)
	for cue in [&"gloamstead_town", &"briarfen_exploration"]:
		var playlist := library.find(cue)
		assert_not_null(playlist)
		assert_eq(playlist.tracks.size(), 2)
		for track in playlist.tracks:
			assert_almost_eq(track.crossfade_seconds, 3.0, 0.01)
	var intense := library.find(&"briarfen_battle").available(&"intense")
	assert_true(intense.any(func(track: MusicTrack) -> bool: return track.id == &"briarfen_battle_v01_intense"))
	for playlist in library.playlists:
		assert_gte(playlist.available().size(), 2, "additional inbox versions are supported")
		for track in playlist.tracks:
			assert_true(track.playable())
			assert_gt(track.stream.get_length(), 100.0)
			assert_eq(track.stream.loop, false, "mixer overlaps whole mixes instead of a hard file wrap")
	var bus := AudioServer.get_bus_index(&"Music")
	var previous_db := AudioServer.get_bus_volume_db(bus)
	var previous_mute := AudioServer.is_bus_mute(bus)
	AudioManager.set_bus_volume(&"Music", 0.0)
	assert_true(AudioServer.is_bus_mute(bus))
	AudioManager.set_bus_volume(&"Music", 0.5)
	assert_false(AudioServer.is_bus_mute(bus))
	assert_almost_eq(AudioServer.get_bus_volume_db(bus), linear_to_db(0.5))
	AudioServer.set_bus_volume_db(bus, previous_db)
	AudioServer.set_bus_mute(bus, previous_mute)
