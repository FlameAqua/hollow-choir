# V0.3 Director acceptance

8 October 2026 · application version 0.3.0 · save version 1

**Engineering acceptance: approved for push.** Adrian authorized the V0.3 push after review.
Claude's [engineering review](V0_3_ENGINEERING_REVIEW.md) supplies the measured transport,
knowledge-gate, media and combat-regression evidence. This follow-up records the final corrections
and an independent release check; it does not replace that report's historical measurements.

## Review and final corrections

Accepted the decoder-cursor alignment, reversal of an active tone fade, shortened end overlaps,
restart-on-seek, Stop/countdown handling and physical-key slider regression. The shared research
predicates now govern battle previews, filtered presentation and the saved Field Guide. Unknown
saved source values are omitted without mutating the save. These address concrete defects while
preserving combat rules, timing, bindings and save compatibility.

Fixed both remaining preparation inconsistencies identified in the report:

- The direct preparation command rejects version zero, matching the file-argument importer.
- A valid cached export missing source codec/channel fields now probes those fields and repairs
  its metadata. It keeps the existing export and source bytes. All seven active records were
  refreshed; a regression exercises the legacy-cache path with an unusable encoder command to
  prove that metadata repair does not encode audio again.

Resolved the report's presentation decisions: Audio Lab tone buttons now mark the actual selected
tone (also after automatic rotation), and the status uses singular/plural player labels correctly.
Keep 0.1-second keyboard steps for fine audition; click/drag already supplies larger jumps. Keep
natural quiet joins for V0.3 pending listening. An aligned base/intense v01 pilot is approved for
Claude's technical validation and manual Audio Lab use in a separate follow-up: shared sample
bounds, native synchronized playback and an honest alignment report are required before enabling
it. Filename grouping alone cannot authorize an alignment claim or automatic intensity policy.

## Final verification

| Check | Result |
|---|---|
| Godot script compilation | 189 checked, 0 failed |
| Full Godot suite, isolated user data | 212 passed, 0 failed; 1,976 assertions; 45.16 s (after final UI polish) |
| Python preparation/import suite | 9 passed, including real FFmpeg decode/cache/replacement |
| Simulation smoke run | All eight encounters × three starter loadouts × ten seeded runs completed |
| Active media | All seven source/export hash pairs valid; codec/channel fields complete |
| Cached preparation | Manifest, catalog, library, sidecars and media byte-identical after another run |
| Compatibility | Application 0.3.0; save version remains 1 |

Expected rejection diagnostics in negative save/action tests are test fixtures. The simulation
still reports known pacing and unused-action observations; a smoke pass establishes successful
execution, not balance approval. Claude separately verified unchanged battle fingerprints and
source/export hashes, and documented the limits of the acoustic measurements.

## Remaining human review and next stage

Fresh-player READ/REACT comprehension, controller comfort and runtime listening remain open.
Independent full mixes preserve source position but are not yet a sample-locked adaptive score.
Quiet outros/intros may create audible lulls; retaining the approved arrangements is the release
choice until listening informs any edits. No source is recut to satisfy a numerical proxy.

Adrian's latest request authorizes preparation of a bounded exploration/town stage. That is an
explicit scope decision, not evidence that the earlier human clarity gate passed. The next Director
contract will define the world loop and Claude's implementation boundary separately from this
V0.3 release. No overworld runtime is included in V0.3.
