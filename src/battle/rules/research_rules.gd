class_name ResearchRules
extends RefCounted
## Emits bestiary research awards. Each (species, source) pair is awarded at most once per battle,
## so knowledge comes from varied understanding rather than repetition (anti-grind).


static func award(ctx: BattleContext, enemy: BattleUnit, source: Enums.ResearchSource) -> void:
	if enemy == null or not enemy.is_enemy():
		return
	var enemy_id := enemy.definition.id
	var key := "%s:%d" % [enemy_id, source]
	if ctx.research_awarded.has(key):
		return
	ctx.research_awarded[key] = true
	var event := BattleEvent.new(BattleEvent.Type.RESEARCH, enemy.uid)
	event.text = String(enemy_id)
	event.amount = source
	ctx.emit(event)


## Knowledge level the HUD may use for this enemy right now.
static func detail_level(ctx: BattleContext, enemy: BattleUnit) -> Enums.ResearchLevel:
	var level := enemy.research_level
	if enemy.inspected:
		level = maxi(level, ctx.library.research.inspect_reveal_level) as Enums.ResearchLevel
	return level
