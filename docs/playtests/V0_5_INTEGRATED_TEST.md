# V0.5A / B / C — Adrian's integrated test

10 October 2026 · working tree · application 0.5.0 / save 1.
Open the project in Godot and run it. Title → Continue Journey → select a save, newest first.
With no saves, use New Journey: choose difficulty and a starter, then choose a free save place.
Automated QA uses isolated data; keep an older slot for reconciliation. Replacing a journey is
deliberate and irreversible, so use a free place for the fresh-journey checks first.

## Integrated V0.5 UI — try these first

- **Title:** exactly Continue Journey, New Journey, Settings, Credits and Quit. Empty Continue is
  grey. Try zero, one and three saves. Continue lists readable journeys newest first (ties by place),
  with UTC times, difficulty, weapon and victories. Damaged/newer saves are explained and disabled.
- **New Journey:** try each difficulty and starter, then Choose save place. Check the setup recap
  and initial focus on the first free place. Back to setup keeps your choices and writes nothing.
  A free place creates the journey and opens Gloamstead only after it saves.
- **Replacement:** with every place occupied, review the full-list explanation. Choosing an
  occupied place shows its facts and a separate irreversible-loss message. Cancel starts focused
  and returns without writing. Confirm on a disposable journey and verify that only its place
  now contains the fresh journey. A damaged/newer save also needs this explicit replacement.
- **Difficulty and older saves:** load an older journey with no difficulty: it starts at Adventurer.
  Change difficulty in Settings, save and reload; the journey keeps it. Assist/accessibility remain
  player preferences. Try Continue after a save changes or vanishes: failure should keep the title
  open, explain it and refresh the choices.
- **Map:** circular node names inside atlas frames, thinner selection and worn textured paths;
  no separate labels or explainer. Inspect longer names with hover/focus. Environment-map art is later.
- **Forge:** approach the anvil at the old bench location. Weapon in a circle, triangular fitting
  sockets (two future locks), owned weapons below, candidates and information box right. Ingredient
  costs use icon/count. Try Help and long inspection, purchase, fit, swap, remove and refund.
- **Stillroom:** dedicated table in front of the Stillroom building north of the anvil. Two active
  potion slots plus two locks; choose a slot then a candidate, inspect or prepare. Recipes and
  potion options use the right side; additional context is behind Help/expanded inspection.
- **Equipment:** leftmost HUD portrait → Equipment. Character artwork and Weapon/Garb/Charm/Relic
  icons left, supplies below, owned candidates right. Clicking Garb filters to garbs. Change gear
  and prepared potions anywhere between encounters. Inspect the Combat changes before equipping;
  the saved result names changed positions. Re-choosing the equipped item changes and writes nothing.
- **Inventory:** compact equipment left, ingredients below, information bottom right; upper right
  deliberately empty. Check the 10-pocket and expanded 15-pocket layouts and existing Alt/pin/scroll.
- **Combat:** eight positions, six usable and two locked. Select a position, then an Actions/Magic
  candidate to swap/replace. These choices save and set the next real battle's order. Each starter
  begins with Kindle unplaced: see the Unplaced line, inspect it in Magic and place it instead of
  another action. Check the new unplaced action, save/reload, and verify the actual battle grid.
  Skills inspect passives and use no position. Gear changes keep shared actions and refill freed
  positions in grid order; returning to a weapon does not restore a separate remembered order.
- **Field Guide:** opens from Character and returns to the same tab/slot filter.
- **Pause and notices:** no Reset, Inventory or Field Guide buttons. Save and Quit is present.
  Save shows Game Saved without moving the menu. In Forge, Stillroom and Character the confirmation
  uses a reserved footer space: Close/Back and station commands must remain visible immediately
  after saving. Exploration/pickups keep the bottom-right stack. Try several pickups and Reduced
  Motion. Battle hides notices while their timers continue. No save-success card on failure.
- **Save and exits:** Save and Quit / Save and return to title save first. If saving fails, Retry
  repeats the exact choice and leaves earlier progress safe. Check a successful exit and Continue.
- **Controls and presentation:** complete these paths with mouse, keyboard and controller; check
  focus, card reading order, Back/Cancel, scrolling, supported resolution presets, art fit and listening.

The earlier A/B/C mechanics below remain the gameplay checklist. References to separate
Actions/Magic/Skills tabs or choosing services at a preparation bench are superseded above.
Reset persistence is now an automated/debug-only check, with no public Reset Journey action.

## V0.5A — Earn, inspect and prepare

- **Character menu:** click Hollow's portrait while exploring. Equipment, Inventory and Combat
  use the existing cloth/leather atlas. Combat filters Actions/Magic/Skills. Check descriptions, magic availability,
  weapon mastery and current passives against your equipped loadout.
- **Inventory and inspection:** ten equipment pockets in two rows of five initially; ingredients
  have their own list. Hover/focus for details, hold Alt to expand, right-click to pin/release,
  and scroll long inspection. Ingredients consume no equipment pocket.
- **First-clear salvage:** inspect rewards before Engage. Patrol gives 2 Bog Iron; bell guard
  gives 2 Bog Iron + 1 Storm Salt. Victory shows a single saved receipt and stock. Leaving costs
  nothing; replays of claimed rewards explain that they grant nothing more.
- **Bell reward:** first restoration grants Storm Salt Charm and permanently expands the bag
  from ten to fifteen pockets. Use Character → Equipment between encounters to equip it.
- **Preparation:** Weapon, Garb, Charm and Relic show owned choices, equipped state, traits and
  action counts. Swap starters; inspect empty optional slots; remove an optional item. Inventory
  browsing never equips. Changes apply to the next encounter, with an eight-action ceiling.
- **Real battle:** take the charm into the untouched patrol; Fen Water Flask applies Wet and
  Spark applies Shock. Check Grounding's extra Stagger. Inspect Exposed's icon and Mark,
  Precision and Break explanations when that effect occurs.
- **Older save:** completed guard/patrol/bell accomplishments receive their missing rewards once
  on entry, with a catch-up notice. Existing equipped gear is retained. Reload should not repeat
  the notice or expand the bag again.

## V0.5B — Bring salvage home

At Gloamstead approach the **anvil** for Forge or the dedicated **Stillroom table**. Reading a
choice is separate from Purchase / Fit / Prepare. Equipment opens Character; Close returns to the world.

| Try | Expected |
|---|---|
| Fresh Forge before recorded combat | Kit is locked; current mastery and the exact requirement are shown |
| Earn one mastery point on any owned starter | Kit becomes eligible if you carry 2 Bog Iron |
| Buy Fitting kit | Spends exactly 2 Bog Iron; shows saved receipt and current stock |
| Fit Merciful Grip | Free; Pilgrim's Patience remains. Wider Good/Perfect windows, smaller Perfect multiplier, successful Parries heal 8 HP |
| Swap to Hollow Echo | Free; Parry exposes the attacker; no extra action is added |
| Remove fitting / reselect it | Removal is free; repeating the same fitting changes nothing |
| Equip another weapon, then the sword again | Fitting stays installed and activates with Pilgrim's Edge |
| Refund kit | Preview shows exactly 2 iron returned; purchase and fitting clear together. Rebuy conserves stock |
| Unlock Clotting Salve recipe | Costs 1 Bog Iron; permanent; inspect Base, Reagent and Catalyst |
| Unlock Focus Tincture recipe | Costs 1 Storm Salt; permanent; bases are reusable/free, Catalyst is none |
| Prepare both slots | Free starters remain. Recipes add their potions; two identical potions are rejected with a reason |
| Enter a real battle | Supplies match both prepared slots; doses refill between encounters. Tincture gives +4 Focus |
| Lose and retry | Same captured equipment, fitting, potions and battle setup |

Watch whether Merciful Grip feels too generous together with Pilgrim's Patience's Focus gain.
This is a balance observation to report, not a retune in this build. Duplicate active traits are
rejected in either direction; an unequipped weapon's fitting is inactive. A legacy save with an
advanced potion prepared keeps it and gets its recipe unlocked without a material charge.

## V0.5C — Explore the existing Reedway

- **Iron seam:** take the outer path around the patrol and look beside its north-running boards.
  Examine, then Gather: +1 Bog Iron, one saved receipt, a dimmed seam. It never regrows in that save.
- **Listening stones:** take the east branch to the waterside overlook. Read the original
  standing stones. Three smaller etched stones mark low (one incision), middle (two) and high
  (three). Each Confirm strikes immediately; there is no timing requirement.
- **Mistake and restart:** try middle first, or low → middle. The message explains that the rhythm
  broke, and the attempt lights clear. A low strike can begin a fresh attempt immediately.
- **Solve:** low → high → middle. Read progress in the prompt, lit etchings and saved feedback.
  A drowned niche opens beside the boards; solving itself grants no item.
- **Search the niche:** explicit Search grants Fenrunner Leathers once. The wrapping disappears.
  Bring them home, inspect and equip Garb, then try Evade in Flooded Ground. Successful Evades
  grant Focus and this garb prevents that Evade from soaking you.
- **Reload mid-attempt:** strike low, save/quit, Continue journey and return to the overlook.
  The saved attempt/light remains, though Hollow resumes at the last safe anchor.
- **Reload after discovery:** solved state, found state, owned garb and claims survive.

## Persistence, controls and sound

- Save and reload after purchases, fitting changes and potion preparation. Check both character
  passives and the next battle. Repeat with an older save.
- Debug/backend reset (covered automatically): route, bell, gate, found secrets, solved puzzles and attempts reset. Research,
  mastery, equipment, materials, recipes, fittings, bag growth and claims remain. The seam stays
  gathered. Solve/search again: no second garb, salvage reward or bag expansion.
- Failed writes are covered by injected failing writers in automated tests. If you encounter the
  Retry save card during ordinary play, the pending step should remain unapplied until Retry
  succeeds; report the action and screenshot. No manual save-corruption procedure is required.
- Try mouse/keyboard and hardware controller through every service and long list. Check focus,
  disabled reasons, scrolling, Back and Close; inspect at your normal resolution and 1920×1080.
- Listen to the three new muted stone tones with music on/off, then mute SFX and solve from text
  and visuals alone. Check comfort and relative volume. Existing town/exploration music is reused;
  no new recording or music delivery is required. Human listening approval remains open.

Report the save slot, fresh/older journey, controls, display size, action/sequence, expected vs
observed result and a screenshot if useful. Gameplay, controller, art and listening acceptance
remain open until this test; automation and captured fixtures are separate evidence.
