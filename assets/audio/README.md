# Hollow Choir audio library

Read [AUDIO_CONTRACT.md](AUDIO_CONTRACT.md) before adding media or implementing playback.
AudioManager plays the existing 23 SFX cues and V0.3 music playlists on separate Music/SFX buses.
Adrian approved the supplied mixes; title, ordinary battle and boss each use both base versions.
The battle playlist also includes the v01 intense example, selectable in the title's Audio Lab.

```text
source/                              excluded from Godot import/export by .gdignore
  inbox/                             unchanged incoming files + delivery metadata
  review/global/                     unapproved comparison exports
  review/regions/briarfen/            unapproved comparison exports
  masters/global/                    approved original global masters
  masters/regions/briarfen/           approved original regional masters
music/catalog.json                   delivery/approval ledger, not a runtime registry
music/global/                        approved runtime music exports
music/regions/briarfen/               approved runtime music exports
ambience/global/                     future reusable ambient loops
ambience/regions/briarfen/             future regional ambient loops
stingers/global/                     future approved short musical cues
sfx/                                 existing cue filenames; preserve these
```

Import existing music (including M4A originals) with `tools/import_music.py`; it accepts external
paths or inbox filenames, standardizes names and preserves source bytes. Adrian has authorized
version/tone additions to these songs. New song IDs still need a cue/destination mapping.

Received 8 October 2026: six originals, two variants each for title, Briarfen battle and Mirebell boss.
Metadata and whole-file comparison Oggs are prepared. See [the listening/review sheet](../../docs/audio/DELIVERY_REVIEW_2026_10_08.md).
Catalog v2 records delivery history. Active runtime playlists live in `music/runtime_library.tres`;
`music/prepared_manifest.json` records measured exports and source hashes. Comparisons stay unchanged
under `source/review/`; prepared runtime Oggs live in `music/global/` and `music/regions/briarfen/`.

To add/swap music: `python tools/import_music.py "path/to/global_title_v3.m4a"`, with additional
paths as arguments. See [instructions](../../docs/audio/MUSIC_IMPORT.md) for safe replacement and
optional Godot import. After removing files, run `python tools/prepare_music.py` (Python 3.11+ and
FFmpeg/FFprobe required) and let Godot import. Every recognized inbox version joins its playlist;
removed files leave it. Source bytes remain unchanged. A new cue requires a destination entry in
the preparation tool and a scene request. Exported games use prepared resources, not the inbox.
Calm/intense tone groups are supported for full-mix crossfades. Truly synchronized layers require
aligned arrangements and a later playback adapter; current files have no verified beat alignment.

[Suno requests](../../docs/audio/SUNO_REQUESTS.md) prioritize ordinary battle, Mirebell boss and title.
Reuse suitable existing music first. Exploration is later preparation, not a new playable world scope.
