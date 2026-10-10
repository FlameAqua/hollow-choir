class_name ExplorationKit
extends RefCounted
## V0.5C fixtures. The authored First Footsteps world plus the PROPOSED exploration content for
## Codex's placement brief (not production data: no scene holds these landmarks yet):
##
## - Iron seam (GATHERING, Briarfen outer loop): 1 Bog Iron, once per save.
## - Listening rhythm (RUNE_SEQUENCE, three stones by the Listening stones overlook): low, high, mid.
##   Solving it grants nothing itself; it reveals the drowned niche.
## - Drowned niche (SECRET, revealed by the rhythm): Fenrunner Leathers, once per save.
##
## Plus a second puzzle that exists only to prove the grammar is reusable: Gate chimes in
## Gloamstead, four strikes with a repeated rune, granting 1 Storm Salt when solved. Tiles are
## planning suggestions; scenes, art and copy remain Codex's.

const NODE := &"iron_seam"
const SECRET := &"drowned_niche"
const PUZZLE := &"listening_rhythm"
const LOW := &"rhythm_stone_low"
const MID := &"rhythm_stone_mid"
const HIGH := &"rhythm_stone_high"
const CHIMES := &"gate_chimes"
const CHIME_A := &"gate_chime_a"
const CHIME_B := &"gate_chime_b"
const CHIME_C := &"gate_chime_c"
const NODE_CLAIM := &"first_footsteps.iron_seam"
const SECRET_CLAIM := &"first_footsteps.drowned_niche"
const CHIMES_CLAIM := &"fixture.gate_chimes"
const REEDWAY := &"briarfen_reedway"
const TOWN := &"gloamstead"


## A new WorldDefinition: the authored areas (landmark lists copied, landmarks shared and never
## edited) plus the fixture landmarks and their exploration definitions.
static func world() -> WorldDefinition:
	var source := WorldDefinition.load_default()
	var result := WorldDefinition.new()
	result.tile_size = source.tile_size
	result.start_area = source.start_area
	result.start_anchor = source.start_anchor
	result.portals = source.portals.duplicate()
	result.flags = source.flags.duplicate()
	for area in source.areas:
		var copy := AreaDefinition.new()
		copy.id = area.id
		copy.display_name = area.display_name
		copy.scene_path = area.scene_path
		copy.size_tiles = area.size_tiles
		copy.default_anchor = area.default_anchor
		copy.extra_anchors = area.extra_anchors.duplicate()
		# Keep the reusable test proposal isolated from production placements of these same IDs.
		copy.landmarks.assign(area.landmarks.filter(func(entry: LandmarkDefinition) -> bool:
			return entry.id not in [NODE, SECRET, LOW, MID, HIGH]))
		copy.paths = area.paths.duplicate()
		copy.music_cue = area.music_cue
		result.areas.append(copy)
	var reedway := result.area(REEDWAY)
	reedway.landmarks.append(landmark(NODE, "Iron seam", LandmarkDefinition.Kind.GATHERING, Vector2i(11, 38),
		"Rust-dark iron shows through the peat beside the outer boards."))
	reedway.landmarks.append(landmark(LOW, "Low stone", LandmarkDefinition.Kind.RUNE, Vector2i(81, 44), "A squat stone."))
	reedway.landmarks.append(landmark(MID, "Middle stone", LandmarkDefinition.Kind.RUNE, Vector2i(84, 46), "A worn stone."))
	reedway.landmarks.append(landmark(HIGH, "High stone", LandmarkDefinition.Kind.RUNE, Vector2i(87, 44), "A tall stone."))
	reedway.landmarks.append(landmark(SECRET, "Drowned niche", LandmarkDefinition.Kind.SECRET, Vector2i(89, 38),
		"A hollow under the bank, just above the waterline."))
	var town := result.area(TOWN)
	town.landmarks.append(landmark(CHIME_A, "First chime", LandmarkDefinition.Kind.RUNE, Vector2i(12, 28), "A chime."))
	town.landmarks.append(landmark(CHIME_B, "Second chime", LandmarkDefinition.Kind.RUNE, Vector2i(14, 27), "A chime."))
	town.landmarks.append(landmark(CHIME_C, "Third chime", LandmarkDefinition.Kind.RUNE, Vector2i(16, 28), "A chime."))
	var node := GatheringDefinition.new()
	node.landmark = NODE
	result.gathering.append(node)
	result.puzzles.append(puzzle(PUZZLE, "Listening stones", [LOW, MID, HIGH], [LOW, HIGH, MID]))
	result.puzzles.append(puzzle(CHIMES, "Gate chimes", [CHIME_A, CHIME_B, CHIME_C], [CHIME_A, CHIME_B, CHIME_A, CHIME_C]))
	var secret := SecretDefinition.new()
	secret.landmark = SECRET
	secret.reveal = SecretDefinition.Reveal.PUZZLE_SOLVED
	secret.reveal_key = PUZZLE
	result.secrets.append(secret)
	return result


## A registry whose world is [param fixture] and whose rewards include the fixture rewards.
static func registry(fixture: WorldDefinition) -> DefinitionRegistry:
	var result := DefinitionRegistry.load_default()
	result.world = fixture
	var iron := RewardItem.new()
	iron.material = result.materials[&"bog_iron"]
	iron.count = 1
	_reward(result, NODE_CLAIM, "Iron seam", RewardDefinition.Source.GATHERED, NODE, [iron])
	var leathers := RewardItem.new()
	leathers.kind = RewardItem.Kind.EQUIPMENT
	leathers.equipment = result.armor[&"fenrunner_leathers"]
	_reward(result, SECRET_CLAIM, "Drowned niche", RewardDefinition.Source.SECRET_FOUND, SECRET, [leathers])
	var salt := RewardItem.new()
	salt.material = result.materials[&"storm_salt"]
	salt.count = 1
	_reward(result, CHIMES_CLAIM, "Gate chimes", RewardDefinition.Source.PUZZLE_SOLVED, CHIMES, [salt])
	return result


static func landmark(id: StringName, label: String, kind: LandmarkDefinition.Kind, tile: Vector2i,
		description: String) -> LandmarkDefinition:
	var result := LandmarkDefinition.new()
	result.id = id
	result.display_name = label
	result.kind = kind
	result.tile = tile
	result.description = description
	result.interact_radius = 48.0
	result.discover_radius = 96.0
	return result


static func puzzle(id: StringName, label: String, runes: Array, solution: Array) -> RuneSequenceDefinition:
	var result := RuneSequenceDefinition.new()
	result.id = id
	result.display_name = label
	result.runes.assign(runes)
	result.solution.assign(solution)
	return result


static func _reward(target: DefinitionRegistry, id: StringName, label: String, source: RewardDefinition.Source,
		source_id: StringName, items: Array) -> void:
	var reward := RewardDefinition.new()
	reward.id = id
	reward.display_name = label
	reward.source = source
	reward.source_id = source_id
	reward.items.assign(items)
	target.rewards[id] = reward


## A session on [param fixture] with the fixture registry, writing through [param kit]'s writer.
static func session(kit: WorldKit, fixture: WorldDefinition, rng_seed: int = 7) -> WorldSession:
	var result := WorldSession.new(fixture, kit.writer.write, rng_seed)
	result.registry = registry(fixture)
	return result
