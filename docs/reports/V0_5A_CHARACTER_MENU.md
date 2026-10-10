# V0.5A — Character menu and inspection follow-up

9 October 2026 · Adrian's UI feedback · shared uncommitted `dev` · application 0.3.0 / save 1

The exploration HUD now has a Hollow portrait at the top right. It opens Inventory, Actions,
Magic and Skills. Inventory from pause or preparation opens the same menu and returns to its
caller; the bench retains its selected slot and station context. Actions/Magic come from the
same action factory as battle. Skills shows saved weapon mastery and currently equipped passives.
These tabs inspect facts; equipment still changes through the existing preparation commands.

Inventory shows thin one-pixel equipment frames in five columns: ten starting slots, two rows.
Ingredients have their own icon/quantity list and consume no equipment slots. A fixed information
panel uses the actual combat `HoverInspector`: hover/focus, Alt or the rebound info control,
Always/Toggle detail preferences, right-click pin/release and wheel/Page Up/Down reading. Item
effects precede flavor text. Equipment uses original native icons, with a small equipped check.

Adrian selected **specific progression rewards** for bag growth. First bell restoration now
unlocks five more slots. The authored reward defines this expansion; the inventory readout derives
capacity from approved persistent claims. Save failure gives no extra row, successful retry gives
one, and reset/reload preserve it. Existing saves with the claim gain the row without rewriting a
save. Further milestones can author more rows. This does not add item disposal or a full-bag
acquisition rejection; legacy equipment is never hidden or lost.

Read earlier/Read further buttons are removed from all world cards and preparation. Existing
scrollbars and Page Up/Down remain. Loot cards/previews show icons, item names and quantities;
descriptions are inspection-only. Successful receipt timing, no duplicate rewards, eligibility
wording and failed-save retries are unchanged. Slot expansion is shown as `Equipment slots +5`.

Exposed no longer paints a banner or a bullseye over a sprite. One compact crosshair effect joins
the other effect icons. Its hover explains increased damage, the extra Precision bonus, Mark's
two target activations and Break recovery. It follows the presentation ledger, so an engine
result cannot announce exposure before its event plays. It adds no status enum or combat rule.

## Evidence and validation

Fresh Compatibility renders in [v0_5a_character_menu](v0_5a_character_menu/README.md) cover the
ten-slot start, earned row, item detail, all character tabs, portrait, compact bell reward,
preparation and Exposed inspection, including a 1920×1080 inventory render. Seeded fixtures are
presentation evidence, not a human playthrough. The previous integration report and captures
remain historical.

- Script compilation: **274 checked, 0 failed**.
- Complete suite, hidden Compatibility renderer and Dummy audio, run alone: **371 passed,
  0 failed, 5,319 assertions, 111.46 s**.
- World suite in Compatibility: **106 passed, 0 failed, 2,791 assertions**.
- Focused character menu: **5 passed, 0 failed, 81 assertions**; icon UI: **7 passed,
  0 failed, 136 assertions**. Subsequent layout refinements are covered by the final full run.
- Music suite in Compatibility: **15 passed, 0 failed, 175 assertions**.
- Ten actual viewport captures inspected, including one at 1920×1080; no capture errors.
  `git diff --check` passes.

The initial headless run was **370 passed, 1 failed, 5,295 assertions**: the unchanged music
test `test_same_timestamp_switch_starts_at_the_outgoing_mix_cursor` missed its 0.5 ms cursor
tolerance. That case also failed alone in headless mode. The same music suite and the entire
suite pass under Compatibility/Dummy above. No audio code or music test was modified to obtain
that result. This headless timing discrepancy remains an engineering limitation, not a claim
of audio/listening acceptance.

No commit, push, application/save version change, painted scene regeneration, crafting
implementation or human/controller/listening acceptance is implied. The existing V0.5B brief
remains the next bounded backend assignment and must preserve this menu and slot reward.
