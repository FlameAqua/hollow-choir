# Music intake

Drop original WAV, FLAC, MP3 or M4A deliveries here. Preserve original bytes.
Names such as `global_title_v01.m4a` and `global_title_v02.m4a` are suitable. Adrian can simply drop
the files; the receiving agent prepares `delivery.template.json` metadata for each delivery. Include
the creator/provider, prompt and preferred version if known; unknown fields stay null. A source
folder outside this repository is also fine; intake can copy selected files later.
Do not convert an MP3 into a pretend lossless master. Deliberate replacements use the importer,
which archives the previous audio and metadata first.
All content below `source/` is excluded from Godot imports/exports; this does not itself ignore Git.

V0.3: Adrian has authorized these songs and future version/tone additions as playlist members.
Run `python tools/import_music.py "path/to/file.m4a" "path/to/another.m4a"` to copy external files,
normalize names and rebuild playlists. Inbox filenames also work as arguments. Spaces/dashes
become underscores, including the two renamed boss files; source audio bytes stay unchanged.
See [usage and replacement options](../../../../docs/audio/MUSIC_IMPORT.md). After removing files,
run `python tools/prepare_music.py`. Let Godot import afterwards, or pass `--godot PATH`.
Recognized names are `<cue>_v<number>[_<tone>]`, such as `briarfen_battle_v3_intense.m4a`.
Playback does not inspect the inbox. Tone suffixes group full mixes and do not prove layer alignment.
