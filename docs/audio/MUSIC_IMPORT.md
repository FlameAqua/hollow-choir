# Import music

From the Hollow Choir project folder, pass one or more files to the importer:

```powershell
python .\tools\import_music.py "C:\Music\briarfen_battle_v3.m4a" "C:\Music\briarfen_battle_v3_intense.m4a"
```

Files already in the inbox can be passed by filename:

```powershell
python .\tools\import_music.py briarfen_battle_v01_intense.m4a
```

Requires Python 3.11+ and FFmpeg/FFprobe on PATH. Use `--ffmpeg PATH` and `--ffprobe PATH`
if needed. Names follow `<song>_v<number>[_<tone>].<format>`. Current songs are `global_title`,
`briarfen_battle` and `briarfen_boss_mirebell`; accepted formats are M4A, WAV, FLAC, MP3 and Ogg.
Versions are unrestricted positive numbers. Optional tones can be `intense`, `calm` or other
names. An unsuffixed file is the `base` tone. Each tone has its own version playlist.

The script copies external files, preserving their originals. It renames files already in the
inbox, along with their delivery metadata. Spaces and dashes become underscores, names become
lowercase and `v1` becomes `v01`. It verifies audio hashes, prepares cached runtime Oggs and
rebuilds the playlists and delivery records. Repeating an unchanged import is safe.

Different audio with the same song/version/tone is protected. To deliberately replace it:

```powershell
python .\tools\import_music.py "C:\Music\global_title_v01.m4a" --replace
```

The previous audio and metadata are copied to
`assets/audio/source/archive/<song_version_tone>/<previous-hash>/` before replacement.
Two formats for the same version/tone are rejected: move the old format out of the inbox first.
New song IDs need a destination in `tools/prepare_music.py` and an engine/scene request.

Open Godot afterwards to import the prepared audio, or let the script do it:

```powershell
python .\tools\import_music.py briarfen_battle_v01_intense.m4a --godot "C:\Users\Adrian\Code\Games\Godot_v4.7.2-stable_win64_console.exe"
```

After removing a version from the inbox, run `python .\tools\prepare_music.py` to rebuild the
active playlists. Old runtime exports stay available for recovery and are no longer selected.

In the game, open **Audio Lab** from the title. Select a song, then choose a version or tone.
Same-song changes crossfade at the current timestamp; they do not restart the music. A new song
starts at zero. **Next version** immediately crossfades into another version's beginning.
**Preview ending** skips to five seconds before the automatic transition and shows a countdown,
so you can hear the outro and normal end overlap. A single-version tone rotates into itself.
Click or drag the playhead to seek; arrow keys adjust it when focused. Seeking during a fade
commits the selected mix and stops outgoing audio at the old timestamp. **Stop** fades out.
Hit/parry buttons help check effects against music. Settings volume applies; nothing is saved.

The new `briarfen_battle_v01_intense.m4a` is included. Same-source timestamp mapping accounts for
leading trims. Shorter target files clamp to their available start/tail. Current playback switches
full mixes at matching timestamps; verified simultaneous layers and automatic battle intensity
remain later engine work.
