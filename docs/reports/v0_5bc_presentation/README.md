# V0.5B/C rendered evidence

10 October 2026 · Godot 4.7.2 · Compatibility renderer / Dummy audio · isolated QA homes.
Actual viewport captures, opened and visually inspected. Seeded fixture states and in-memory
writers demonstrate presentation; they do not certify human gameplay, controller or listening.
See [the integration report](../V0_5BC_PRESENTATION.md) and [human checklist](../../playtests/V0_5_INTEGRATED_TEST.md).

| Capture | Check |
|---|---|
| [Forge](forge.png) | Cost, mastery, kit preview and separate Purchase |
| [Locked Forge](forge-locked.png) | Exact zero-mastery reason; disabled purchase |
| [Installed grip](forge-fitted.png) | Trait facts and unchanged combat values |
| [Grip details end](forge-fitted-scroll.png) | Pilgrim's Patience retained; fixed action outside scroll |
| [Refund](forge-refund.png) | Two-iron preview, resulting stock and installed state |
| [Receipt](forge-receipt.png) | Saved spend and stock; selection retained |
| [Stillroom](stillroom.png) | Base/Reagent/Catalyst and free reusable supplies |
| [Locked potion](stillroom-locked.png) | Recipe source, charges and exact unlock reason |
| [Prepared tincture](stillroom-potion.png) | Slot 2, distinct potion choices and refill policy |
| [Written clue](explore-clue.png) | Full sequence and mistake/restart instruction |
| [Unsolved stones](explore-runes.png) | Three unlit incision counts; niche hidden |
| [Saved first strike](explore-progress.png) | Lit incision and progress feedback |
| [Mistake](explore-mistake.png) | Static readable explanation and cleared lights |
| [Solved](explore-solved.png) | Revealed-place copy, no direct item grant |
| [Niche dialogue](explore-niche.png) | Explicit Search/Leave |
| [Searched niche](explore-searched.png) | Opening remains; wrapping gone |
| [Niche receipt](explore-reward.png) | Saved Fenrunner Leathers reward and new icon |
| [Iron seam](explore-iron.png) | Reachable outer-path prop |
| [Gathered seam](explore-gathered.png) | Static dimmed state |
| [Reset](reset.png) | Exact keep/reset/no-repeat policy |
| [1080p Forge](forge-fitted-1920.png) | Actual 1920×1080 output |
| [1080p Stillroom](stillroom-potion-1920.png) | Actual 1920×1080 output |

The other twenty PNGs are 1280×720. Use the corresponding filename as `--state` with
`tools/capture_world.gd`; `forge-fitted-scroll` uses `--state=forge-fitted --scroll-end` and the
1080p variants use `--size=1920x1080`. Dialogue captures use `--revealed` to finish typewriter
text before saving. All capture runs go through `tools/qa_godot.py`; the player's save is unused.
