# Hollow Choir — V0.3 engineering handoff

You are the Lead Gameplay Engineer and Technical Designer for Hollow Choir. Work in
`C:\Users\Adrian\Code\Games\hollow-choir`, using Godot 4.7.2 and GDScript, without addons.
Continue from the current working tree on `dev`, application version 0.3.0. Preserve both the
preexisting V0.2.1 work and the V0.3 Director/UI integration. Nothing has been committed or pushed.

## IMPLEMENTATION BRIEF

Perform the engineering return review for V0.3 and fix verified defects within this scope.
The implemented stage adds a saved-knowledge Field Guide, authorized version/tone music playlists,
Audio Lab, a safe file-argument music importer and the enlarged reaction footer. ChatGPT owns the
presentation contract and UI integration; you own engine architecture, transport hardening and
deterministic rules. Do the engineering review and fixes, rather than only proposing a plan.

Read `docs/CLAUDE_PROMPT.md`, `docs/design/V03_FIELD_GUIDE_AND_AUDIO.md`,
`docs/briefs/V0_3_REVIEW.md`, `docs/reports/V0_3_FIELD_GUIDE_AND_AUDIO.md`,
`docs/DATA_CONTRACTS.md`, `docs/TESTING.md` and `assets/audio/AUDIO_CONTRACT.md` first.
Use the existing V0.2 UI/timing contracts where referenced. The older after-V0.2.1 context prompt
is historical: music playback and the Field Guide are now implemented.

## DATA CONTRACT

FieldGuideReadout uses saved BestiaryState, ResearchConfig and existing enemy definitions. It
shares knowledge predicates with BattleKnowledge. Unknown species and temporary battle reveals
stay hidden. Later boss move cards require Mastered; existing Understood species traits may
mention later moves, following current combat policy. Weapon practice displays saved totals,
without new rewards or persisted fields. Save compatibility remains version 1.

AudioManager owns MusicMixer with two pooled streaming players, a private RNG and real-time fades.
MusicLibrary → MusicPlaylist → MusicTrack is separate from the combat registry and JSON ledger.
Tracks include version, tone, stream, gain, crossfade duration and source_offset_seconds (the
preparation's leading trim). sync_group remains reserved; filenames do not prove sample alignment.
Adrian approved all supplied music and future version/tone additions. There are seven prepared
tracks: two base versions each for title/battle/boss, plus briarfen_battle_v01_intense.
Boss inbox filenames/sidecars now use underscores; their audio hashes are unchanged.
tools/import_music.py accepts paths/inbox names, normalizes names, preserves external originals
and archives explicit --replace swaps. Runtime uses prepared Resources and never scans the inbox.

## STATE FLOW

Title → Field Guide → Bestiary/Weapon practice → Title is read only. Practice stays unrecorded;
Lab Record progress remains opt-in. Title/Settings/Guide/Setup request title music; battle/resume
requests the existing regional/boss cue. Same-cue requests preserve playback.

In Audio Lab, selecting another version/tone of the same song crossfades at the current source
timestamp, including trim-offset mapping. Tone requests prefer a matching version. Selecting the
playing variant is inert. New songs and Next version start at zero. Preview ending seeks five
seconds before automatic end rotation and shows a countdown; a single version repeats through
the normal overlap. Click/drag/keyboard seeking commits the selected deck and clears outgoing
audio. Nonfinite seeks are rejected; bounds and shorter targets clamp safely. Fast switches must
not accumulate the audio server's pre-command mix age. Music never drives combat timing or RNG.

## ACCEPTANCE TESTS

Audit source-time mapping, queued play/seek position reads, crossfade interruptions, end recovery,
rapid switching, short/missing variants, private shuffle history, volume/mute, pause/focus and
pooled-player cleanup. Preserve the working timestamp behavior; do not restore tone restarts.
Review actual audible joins and SFX masking where possible; distinguish listening from transport
tests. Audit Field Guide knowledge boundaries, save compatibility, focus and scrolling at
100/150/200%, and the two visible reaction-help lines at 200%.

Current baseline: 189 scripts compile; 205 Godot tests pass with 1,937 assertions; eight Python
preparation/import tests pass. The initial V0.3 seeded smoke completed 240 battles; combat code is
unchanged by the audio follow-ups. Run documented checks through tools/qa_godot.py with fresh
isolated homes under .godot/qa. Run Python tests with unittest discovery. The four invalid-save
fixture errors and one rejected-action warning are expected. Never use the player's real saves.
Real UI fixtures are in docs/reports/v0_3; captures do not establish human comprehension or hearing.

## KNOWN EDGE CASES

The intense example and base v01 prepare to 118.50 and 118.28 seconds. Playback now preserves
timestamps; arrangement/sample alignment and seamless audible joins remain unverified. A target
without content at the requested source time clamps to its available start/tail. Current playback
crossfades two full mixes; all tone layers do not run simultaneously. Propose the smallest verified
aligned-layer transport/content contract and public-state automatic-intensity mapping in your
return report. Do not invent hidden-state triggers or arbitrary intensity thresholds during review.

## NON-GOALS

The M1.1 human clarity gate remains open. Do not start world/hub/expedition runtime, add combat
systems/content/rewards, retune balance, change timing windows/bindings, migrate saves or claim
human gates passed. Do not generate replacement music or commit/push without Adrian's request.

Return `docs/reports/V0_3_ENGINEERING_REVIEW.md` with fixes, architecture/API changes, save impact,
exact validation results, limitations and proposed adaptive-audio extension points. Update affected
contracts if behavior changes. End with a concise handoff back to the Director and the next gated
step toward the vertical slice.
