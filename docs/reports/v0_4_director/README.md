# First Footsteps — Director capture fixtures

9 October 2026. Native Godot 4.7.2 renders from the integrated working tree. The capture runner
seeds in-memory progress, places Hollow and opens views directly. Synthetic outcome captures
apply authored fixture results over the world without launching a live battle, not played victories/defeats.
The separate battle image shows the embedded presenter. Saves/settings are isolated and
audio uses the dummy driver. These are visual evidence only; all human gates remain open.

| Files (1280×720 unless stated) | Review purpose |
|---|---|
| [town](town.png), [restored town](town-restored.png) | Same camera/player position; stable frame, bell/clapper, lit lamp and objective |
| [dialogue](dialogue.png) | Lower dialogue frame, readable paragraphs, fixed Close |
| [sword](bench.png), [hammer](bench-hammer.png), [bow](bench-bow.png) | Every owned starter weapon's full text and selected state |
| [patrol card](encounter.png), [guard card](guard.png) | Filtered count/species, authored conditions, reset/free-leave copy |
| [partial map](map.png), [full discovered map](map-full.png), [restored map](map-restored.png) | Numbered markers, focus-scrolling list, selected description, independent shortcut flag |
| [paused menu](menu.png) | Vertical actions and safe-place resume explanation |
| [route](route.png), [patrol](patrol.png), [guard junction](guard-approach.png) | World layers and visible encounter approaches |
| [gate](gate.png), [collision debug](collision.png), [facade](facades.png) | East–west clearance, independent physics and roof join |
| [far-side latch](latch.png) | Contextual opening prompt |
| [battle](battle.png) | Existing battle presenter embedded in the world |
| [victory](victory.png), [defeat](defeat.png), [save failure](save-failed.png) | Synthetic outcome/transaction notices and fixed choices |
| [1366 preset](map-1366x768.png) | Game-content texture 1365×768 in the aspect-constrained 1366×768 window |
| [1600 preset](map-1600x900.png), [1920 preset](map-1920x1080.png) | Actual output at those resolutions |
| [requested 2560 fallback](map-requested-2560-fallback-1920.png) | Actual 1920×1080; existing usable-screen fallback. Does **not** qualify 1440p |

Reproduce from the repository with the isolated launcher and the local Godot executable:

```powershell
python tools/qa_godot.py --godot <Godot-console.exe> --home .godot/qa/director-capture --hidden --rendering-method gl_compatibility --audio-driver Dummy --script res://tools/capture_world.gd -- --state=bench-bow --out=res://docs/reports/v0_4_director/bench-bow.png
```

States and supported-size options are listed in `tools/capture_world.gd`. View the
[Director report](../V0_4_DIRECTOR_ACCEPTANCE.md) for decisions, automated results and open sessions.
