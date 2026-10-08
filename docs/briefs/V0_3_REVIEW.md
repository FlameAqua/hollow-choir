# V0.3 engineering return review

8 October 2026. Implementation is in the uncommitted working tree on top of V0.2.1.
Authority: [V0.3 contract](../design/V03_FIELD_GUIDE_AND_AUDIO.md).
Evidence: [implementation report](../reports/V0_3_FIELD_GUIDE_AND_AUDIO.md).

## IMPLEMENTATION BRIEF

Review the completed Field Guide, music playlists, Audio Lab/importer and enlarged reaction footer. Director work
includes the presentation contract, UI/readout integration, playlist preparation and captures.
Engineering review should audit knowledge filtering, transport lifetime, media preparation and
regressions. Preserve the existing V0.2.1 changes. No commit or push is requested.

## DATA CONTRACT

FieldGuideReadout reads saved BestiaryState plus existing definitions and ResearchConfig. It
shares research predicates with BattleKnowledge; no BattleEngine or temporary reveal is stored.
MusicLibrary → MusicPlaylist → MusicTrack lives outside the combat registry. Version/tone suffixes
group full mixes, not synchronized stems. The source ledger and prepared manifest are tooling data.
User explicitly approved all six base tracks, the new v01 battle intense example and future playlist additions/swaps; no independent
license verification, agent audition or beat alignment is claimed. No save/rule/balance changes.

## STATE FLOW

Title → Field Guide → existing bestiary/practice → Title. Reading never saves or grants points.
Practice remains unrecorded; Lab recording is opt-in. Title/Settings/Guide/Setup use global_title;
battle selects regional/boss cue by existing enemy identity. Same cue is inert across restart.
Setup changes music and resume restores the battle cue. Pause/focus loss keep music running.
Two streaming decks overlap near the end and on cue changes using real time and private RNG.
Title → Audio Lab selects a song, version and tone; subsequent rotation remains random. Same-song
tone/dropdown selections retain source time, including trim-offset mapping. Next version starts
another mix from zero. Preview ending leaves five seconds before automatic end scheduling, shows
a countdown and is disabled during a fade. The clickable/draggable/keyboard playhead seeks the
selected deck and clears outgoing audio. New song requests start at zero.
The importer accepts one or more paths/inbox names, copies external originals, normalizes filenames,
and rebuilds the library. Explicit --replace archives prior audio/metadata. Both boss inbox names
and sidecars now use underscores. Original filename metadata remains historical provenance.

## ACCEPTANCE TESTS

Run the documented script check, full suite, Python preparation tests and seeded simulation smoke
through isolated QA homes. Review real captures in docs/reports/v0_3. Specifically audit saved
knowledge levels, phase move cards, removed IDs, read-only navigation, native-rate/hash-preserving
preparation, playlist discovery, same-cue requests, tone fallback, repeated/rapid transitions,
missing cues and pooled-player cleanup. Listen to three joins per variant and compare with SFX.
Audit the manual APIs (audition/next_mix/test_loop/seek/playback_status), shuffle history after explicit
selection and same-version tone switches, Lab focus/scroll at 100/150/200%, and importer replacement
recovery. Also check rapid switches, pending audio-mix interpolation, source trim offsets,
shorter target files, seeks during fades and real pointer/keyboard slider input. See
[import instructions](../audio/MUSIC_IMPORT.md) and Audio Lab captures in the report.

## KNOWN EDGE CASES

Understood species traits follow existing combat policy and may mention later moves; later-phase
move cards remain Mastered only. Very long rebound key labels may need more footer space. Rapid
cue changes replace the quieter deck. Missing tone falls back to base; a single version repeats
through an overlap. Source swaps require preparation and Godot import, not a live exported-game scan.
The intense example is a separate full mix, with a prepared length of 118.50 seconds versus base
v01's 118.28 seconds; no aligned arrangement/transport is established by the filename or duration.
Claude's next audio integration should specify aligned-layer transport and public-state intensity
inputs before adding automatic battle-tone changes. The current Lab can audition full-mix switches.

## NON-GOALS

No human gate can be passed by this review. World/expedition persistence, new content or mechanics,
balance tuning, simultaneous aligned layers, beat synchronization and public-state intensity
routing need later specifications/content. No new media generation, external dispatch or release.
