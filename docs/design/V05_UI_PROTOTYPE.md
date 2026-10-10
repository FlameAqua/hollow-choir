# V0.5 — Journey and station UI prototype

Adrian's requested iteration · 10 October 2026 · application 0.5.0 / save 1.

This supersedes the public preparation-bench flow and separate character Actions/Magic/Skills
tabs. It is a reviewable frontend prototype. Existing equipment, crafting, reward and exploration
transactions remain authoritative. New journey creation, field equipment permissions and saved
combat arrangements are assigned to Claude in [the backend handoff](../briefs/V0_5_UI_BACKEND_HANDOFF.md).

| Change | Purpose and player decision | Interactions / cost | Failure case / reuse |
|---|---|---|---|
| Five-choice title | Resume a chosen journey or select a fresh starter and difficulty | Existing three save slots and modal; small frontend, medium backend | Never overwrite from browsing; reuse atomic save manager |
| Circular map labels | Read discovered places and connections at a glance | Filtered map readout and existing atlas rings; small | Long names and dense landmarks; labels displace without discovering anything |
| Dedicated Forge / Stillroom | Recognize the correct station and compare modifications or supplies | Existing crafting readouts and commands; two backgrounds, two props | Service restrictions still need backend IDs; reuse recipes and costs |
| Equipment / Inventory / Combat | Separate changing gear, examining possessions and arranging combat choices | Shared inspector and typed slots; medium UI/backend | Stale choices, invalid capacity, passive skills; preview cannot alter actual combat |
| Notices | See successful saves and pickups without menu movement | Existing success/receipt hooks; one reusable queue | Failed writes, duplicate feedback, bursts; no timers that grant items |

## Layout and interaction

- Title: Continue Journey, New Journey, Settings, Credits, Quit. Continue is disabled without
  readable save summaries. The picker sorts newest first, ties by slot number. Dates explicitly
  say UTC. New Journey offers Story/Adventurer/Tactician and three starter weapon preset icons;
  Start stays disabled until a backend listener connects to `new_journey_requested(options)`.
  Credits holds a Beta placeholder and V0.5 updates. F10 exposes development tools in debug builds.
- Map: circular ring atlas frames contain short multiline place names. Selected/focused nodes
  tint the same rim. Worn board/pebble SVG stamps texture known paths. Nearby labels spread out;
  path endpoints follow published landmark positions. No side list, legend, below-map explainer
  or fast travel. The parchment remains a prototype; a simplified environment map is later art.
- Forge: anvil station at the old stable `preparation_bench` ID. Generated backdrop, anvil corner
  icon and Help. A central weapon and triangular three-socket ring occupy the left; owned weapon
  icons sit below. Only the existing fitting socket works. Two sockets are visibly locked.
  Candidates and the shared information box occupy the right. Costs are ingredient icon/quantity.
- Stillroom: separate `stillroom_table` marker at (592, 784), generated prop and backdrop. Two
  potion slots, two future locks, recipe/potion candidates right, information box below, Help.
  Selecting a slot changes which typed potion index is prepared; recipes remain permanent unlocks.
- Equipment: existing full Hollow character artwork, Weapon/Garb/Charm/Relic icons beside it,
  supplies below. Clicking a slot filters owned candidates on the right. Explicit Equip/Remove/
  Prepare commands use backend eligibility. The current station restriction is shown in facts.
- Inventory: compact 64 px equipment cells left, ingredient icon/quantities below, inspection
  bottom right. Upper right is reserved and empty. No salvage instructions or slot-unlock prose.
- Combat: eight displayed positions, six preview choices and two locked future positions. Select
  a position, then an Action/Magic candidate to replace or swap. Skills are inspectable passives.
  This arrangement is local, discarded when the view closes, and does not remove battle actions.
  The preview label and Help explicitly state that limit. Real editing/persistence is Claude's work.
- Character is the leftmost exploration tool icon. Field Guide opens from Character and returns
  to its tab/filter. Pause offers Resume, Settings, Help, Save, Save and return to title, Save and
  Quit. Public Reset/Inventory/Field Guide actions are removed; debug reset implementation remains.
- Bottom-right cards slide in over 280 ms, remain about 3.4 seconds, stack upwards with an 8 px gap,
  show at most four, and queue excess notices. Repeated save notices coalesce. Reduced Motion
  places them immediately. Save success and positive reward receipts are the only input facts;
  the notice layer never writes, grants rewards or moves the menu.

## Rules, data and balance boundaries

No new combat, economy, reward, difficulty or save-schema rules are implemented by this prototype.
The eight-action engine ceiling remains intact. Six initial Combat positions and two future potion/
modification positions are visual requirements pending typed progression. No extra active trait,
potion charge, ingredient cost or new recipe is implied by a socket. Existing successful saved
area arrivals, victories and rune strikes now show notices; global save-event ownership goes to
Claude. The old landmark ID stays valid for existing saves.

Hover and keyboard focus feed the reusable HoverInspector. Alt details, pinning, wheel ownership,
fixed footer and modal focus trapping remain shared behavior. Names, descriptions, costs, locks
and rejection reasons remain inspectable. Map label text uses a compact 12 px exception inside
88 px medallions; other body copy follows the fixed 1280x720 / 22 px contract. Controller, map-name
readability, human art acceptance and listening remain human review gates.

## Acceptance

Automated UI tests cover exact public title choices, disabled empty Continue, chronological ties,
safe preview setup, filtered owned gear, station guard, Field Guide return, six-plus-two Combat
preview swapping without a write, readable keyboard-scrollable Help, save-failure retry, stable menu bounds, queued non-overlapping
notices and station reachability. Existing crafting/reward/collision/route tests remain required.
See [rendered evidence](../reports/V0_5_UI_PROTOTYPE.md) and
[the A/B/C human checklist](../playtests/V0_5_INTEGRATED_TEST.md).
