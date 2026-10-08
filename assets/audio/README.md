# Hollow Choir audio library

Read [AUDIO_CONTRACT.md](AUDIO_CONTRACT.md) before adding media or implementing playback.
The current AudioManager plays the existing 23 SFX cues and creates Music/SFX buses; music playback
is not implemented by this asset pass. Music volume settings already exist.

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

Put existing music (including M4A originals) in `source/inbox/`. Keep original names and bytes there;
the receiving agent can prepare `delivery.template.json` metadata. An agent auditions and maps
candidates before producing approved runtime exports. Folder presence does not grant approval.
External local paths are also accepted for intake.

Received 8 October 2026: six originals, two variants each for title, Briarfen battle and Mirebell boss.
Metadata and whole-file comparison Oggs are prepared. See [the listening/review sheet](../../docs/audio/DELIVERY_REVIEW_2026_10_08.md).
Catalog v2 records both candidates for each cue; none is selected or integrated yet. Comparisons stay
under `source/review/`, and `music/global/` / `music/regions/briarfen/` remain for approved runtime exports.

[Suno requests](../../docs/audio/SUNO_REQUESTS.md) prioritize ordinary battle, Mirebell boss and title.
Reuse suitable existing music first. Exploration is later preparation, not a new playable world scope.
