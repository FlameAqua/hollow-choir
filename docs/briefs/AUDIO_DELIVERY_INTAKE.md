# First music intake — engineering handoff

## IMPLEMENTATION BRIEF

Six user-supplied Suno originals are registered: two variants each for title, ordinary Briarfen battle
and Mirebell boss. ChatGPT prepared metadata, measurements and whole-file comparison exports under
the [audio contract](../../assets/audio/AUDIO_CONTRACT.md). See
[the review sheet](../audio/DELIVERY_REVIEW_2026_10_08.md). No production code changed in this pass.

## DATA CONTRACT

`assets/audio/music/catalog.json` v2 keeps one stable record per cue in `tracks`. Its
`candidate_delivery_ids` reference six explicit `candidates` entries. Cue selected source/runtime,
delivery ID, version and approval fields remain null. Per-file `.delivery.json` v2 in `source/inbox/`
records unchanged original filename/path/SHA-256, actual container/codec/rate/channels/duration,
input loudness/true peak, prompt relationship and export provenance. Original boss filenames use
hyphens; stable cue IDs and comparison exports use `briarfen_boss_mirebell`. Do not rename originals.

All six comparison Oggs are native-rate 48 kHz stereo Vorbis, whole-file, with no source edit or gain.
They remain under `source/review/{global,regions/briarfen}/`, excluded from Godot import/export. They
are not runtime-ready or approved masters. BPM, meter, exact generation prompt/date, loop bounds,
musical-fit approval and playback gain remain unknown/unselected; requested tempo is not measurement.

## STATE FLOW

User drop → original hashed/probed → complete decode/measurement → per-file received metadata →
whole-file comparison export/decode → six received candidates in ledger. Listening and version choice
then lead to approved master → separately reviewed level/loop export → runtime_ready → explicit later
playback integration. A file arriving, decoding or having the larger version number cannot skip steps.

## ACCEPTANCE TESTS

Six unique IDs; two candidates for each intended cue; source/export paths and hashes resolve; every
original/export fully decodes; sample rate/channels agree; source and export durations differ by less
than 0.15 seconds; all originals retain their hashes; candidate references resolve; selection fields
stay null; review exports remain outside runtime music folders. Apply AUDIO-02/03 before promotion,
then AUDIO-04/05 for any later playback wiring. Current technical results are on the review sheet.

## KNOWN EDGE CASES

M4A sources contain Opus; probe their payload rather than assume AAC from extension. Conversion to
Vorbis is lossy and cannot restore missing quality. Supplied levels are louder than the preparation
target; preserve source and choose any gain/limiting only for reviewed exports. Near-zero source peaks
and a successful decode alone do not prove inaudible artifacts or a seamless join. Native loop and
musical fit remain unauditioned. Sparse/long endings need listening, not automatic silence trimming.

## NON-GOALS

No selected default, automatic newest-variant choice, music player, adaptive layers, forced stems,
normalisation/trim/crossfade, tempo-driven gameplay, changed combat clocks, usage-policy conclusions,
new exploration content or unverified human audition claim.
