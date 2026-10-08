# V0.2 support presentation evidence — 8 October 2026

Current pass: [design contract](../../design/V02_SUPPORT_PRESENTATION.md),
[Claude handoff](../../briefs/V02_SUPPORT_PRESENTATION.md),
[Cinder Pup source/prompt](../../art/CINDER_PUP_V01.md). This supplements the earlier UI report.

## Result

Guard's authored description existed but describe_details skipped it; support actions without
damage/healing were painted with a synthetic green dash. Expanded cards now retain authored rules,
with direct support effects presented as icon/name and recipient fields. Guard shows Guarding and
+1 Focus; Intercept shows cover and shielding; Focus Tincture shows +4 Focus with recipient cap
wording. No empty Details heading or support damage placeholder remains.

All existing cast assignments were audited: two party characters, nine enemies and both familiars.
Cinder Pup was the only missing art assignment. Its generated PNG is saved in the global familiar
folder with an AtlasTexture portrait; both familiar portraits use aspect-fit floor anchoring.

Stage HP/break now use shared stepped frame textures and beveled fills; the heart adds stepped
shading. Break remains narrower and immediately beneath HP, with values available on inspection.
Condition announcements are compact framed cards, then compress/fly to the matching header icon.
Reduced motion keeps the card still and adds a steady icon border. Opening condition prose is no
longer repeated in the encounter banner. Announcements appear above floating combat feedback;
terrain-caused status feedback renders compactly and floating labels stay below the header.
The lower action preview uses the existing 82% native-font transform, including its field hit tests.

## Validation

- Godot 4.7.2: 180 scripts checked, 0 failed.
- Full suite: 175 passed, 0 failed, 1,431 assertions (30.07 s in the final run).
- Added regressions cover authored support rules, named effects/no fabricated dash, field bounds,
  all current cast art, familiar proportions/footing, zero/half/full resource fills, condition
  docking/reduced motion/missing destination, and enlarged terrain feedback staying below the header.
- Existing knowledge filtering, presentation ledger, scrolling, modifier/input, explicit target
  review, Practice resolution/scale and completed-battle tests continue passing.
- Scoped tracked-file whitespace check passed; Git printed only CRLF normalization notices.
- QA uses isolated APPDATA under .godot/art_qa_home, without touching player saves/preferences.

The four invalid-save errors and one illegal-Focus warning in full-suite output are expected fixture
checks. Asset import succeeded and registered the new art/classes; the editor's import exit also
printed a Windows “Safe save failed” editor-settings diagnostic. Runtime compilation, gameplay tests
and final rendered captures completed without that diagnostic or unexpected script errors.

## Rendered evidence

Captured from the actual battle scene with OpenGL compatibility rendering. The capture-only harness
accelerates the intro, waits for real planning, then restores normal time for inspection/docking
snapshots. It does not modify production timing, battle rules or art files. Advanced analysis at
200% intentionally scrolls within the available battlefield space.

- [Guard rules and effects, standard](guard_support_1280.png)
- [Guard rules/effects and compact dock, 200%](guard_support_200.png)
- [Intercept cover/shielding, standard](intercept_support_1280.png)
- [Focus Tincture, standard](tincture_support_1280.png)
- [Cinder Pup and textured resource bars](cinder_and_bars_1280.png)
- [Compact Flooded Ground introduction](condition_card_1280.png)
- [Condition card during docking flight](condition_flight_1280.png)
- [Stationary reduced-motion card and header marker, 200%](condition_reduced_200.png)

Generated art remains available for human visual review. These checks do not certify fresh-player
comprehension, physical controller use or color-vision comfort. No release, commit or push was made.
