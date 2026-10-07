class_name BattleLaunch
extends RefCounted
## Payload for the battle scene: what to fight and where to go afterwards.

var setup: BattleSetup
## Scene to return to when the battle is over.
var return_scene: String = ""
## Record research/mastery into GameState (off for sandbox experiments unless chosen).
var record_progress: bool = true
## Sandbox options.
var autoplay: bool = false
var simulated_execution: int = -1
var show_ai_reasoning: bool = false


static func make(p_setup: BattleSetup, p_return_scene: String) -> BattleLaunch:
	var launch := BattleLaunch.new()
	launch.setup = p_setup
	launch.return_scene = p_return_scene
	return launch
