# IMPLEMENTATION BRIEF

Implemented Adrian's final UI/pacing corrections: expanded details scroll from action sources,
Cinder Pup grows through existing portrait fitting, and manual timed sequences get one short
preparation beat showing their actual timing UI. The opening banner now sheds temporary autowrap
height before fading in; announcements suppress contextual inspection until they finish.
Authority: [pre-push design](../design/V02_PRE_PUSH_POLISH.md).
Latest validation/captures: [opening and timing preview evidence](../reports/v02_ui/OPENING_AND_TIMING_PREVIEW.md).

# DATA CONTRACT

FamiliarDefinition.display_scale defaults to 1.0; Cinder Pup uses 1.2. Rounded slot 62×70 keeps its
existing floor. BattleScene.PREPARATION_MS = 400. Shared scene-bound tween ignores time_scale and
pauses on focus loss. No core spec, balance, saved progress or input-binding change.
CommandWidget/ReactionWidget.begin(..., preparing=false) remains backward compatible. Passing true
builds their real UI at frozen zero time with inert input. start_timing() releases preparation once,
relatches held keys and starts the unchanged clock/assist wait. is_preparing() is presentation state.

# STATE FLOW

Collapsed action → wheel scrolls list. Expanded action → wheel over current source/card scrolls
details. Confirmed manual timing request → actual widget.begin(..., true), meter/ring at zero →
400 ms real time → same widget.start_timing()/fresh-press latch → unchanged timing/result/safe point. Simulated
execution skips the presentation-only beat. Assist pause still waits for Confirm after preparation.
Announcement → clear/suppress inspector → transparent layout settling → fit content → fade/hold →
fade or condition docking → hide → normal inspection resumes. No new modal or combat phase.

# ACCEPTANCE TESTS

Real action wheel routing in both directions and on collapse; Pup scale/floor/containment; real
command/reaction preparation with the same visible widget; all four command types ignore preview
input then grade normally; held-key/Confirm suppression; focus freeze; exact-impact success; restart
cancels wait and preview. First/repeated banner fit, title/body changes and opening/condition hover
suppression at enlarged text. Retain full suite and actual rendered captures in the UI report.

# KNOWN EDGE CASES

Alt expanded source steals wheel from the list intentionally; collapsed lists keep navigation.
Toggle/Always follow the same expanded rule. Pause/Setup still defer until the current action's
safe point. Preview widgets and the preparation wait are owned by the battle; restarting frees
both. No advancing clock, NOW cue, charge, rhythm beat or reaction attempt exists during preparation.
The visible preview uses filtered information already available to the player. Empty announcements
are skipped; title-only reuse discards old body height. No hover box can cover an announcement.

# NON-GOALS

No new cooldown statistic, difficulty setting, countdown system, input buffering, clock/grading
changes, extra result delay, familiar mechanics, new sprite generation, release, commit or push.
