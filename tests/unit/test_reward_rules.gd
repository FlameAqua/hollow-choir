extends TestCase
## V0.5A reward rules and data, without a world session: the shipped reward table, catalog
## validation (ids, sources, references, kinds, counts, totals), saturating grants that never
## duplicate equipment, deterministic order, receipts and previews as plain public data, and saved
## data parsed without trusting it.

## Species and encounter names: reward readouts carry item facts only.
const FORBIDDEN := ["fen_patrol", "rot_grove", "Fen Patrol", "Rot Grove", "Bogshell", "Thornhound", "Fen Wisp",
	"Rotcap", "Sporecaller", "affinit", "weakness", "resist"]

var registry: DefinitionRegistry


func before_each() -> void:
	registry = DefinitionRegistry.load_default()


func _reward(id: StringName) -> RewardDefinition:
	return registry.rewards[id]


## {material or equipment id: count} for [param reward].
static func _grants(reward: RewardDefinition) -> Dictionary:
	var result := {}
	for item in reward.items:
		result[item.item_id()] = item.count
	return result


static func _material_item(material: MaterialDefinition, count: int) -> RewardItem:
	var item := RewardItem.new()
	item.material = material
	item.count = count
	return item


static func _equipment_item(equipment: Resource, count: int = 1) -> RewardItem:
	var item := RewardItem.new()
	item.kind = RewardItem.Kind.EQUIPMENT
	item.equipment = equipment
	item.count = count
	return item


static func _make(id: StringName, source: RewardDefinition.Source, source_id: StringName,
		items: Array[RewardItem]) -> RewardDefinition:
	var reward := RewardDefinition.new()
	reward.id = id
	reward.display_name = "Test salvage"
	reward.source = source
	reward.source_id = source_id
	reward.items = items
	return reward


## A save dictionary as canonical JSON (numbers and key order as on disk).
static func _canonical(data: Dictionary) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(data)), "", true)


## Problems for the shipped catalog plus [param reward] (removed again afterwards).
func _problems_with(reward: RewardDefinition) -> PackedStringArray:
	registry.rewards[reward.id] = reward
	var problems := reward.validate()
	problems.append_array(RewardRules.validate_catalog(registry))
	registry.rewards.erase(reward.id)
	return problems


func test_shipped_rewards_follow_the_v05a_table() -> void:
	assert_eq(registry.sorted_ids(registry.rewards),
		[&"first_footsteps.drowned_niche", &"first_footsteps.guard", &"first_footsteps.iron_seam",
		&"first_footsteps.patrol", &"first_footsteps.restoration"] as Array[StringName])
	assert_eq(registry.sorted_ids(registry.materials), [&"bog_iron", &"storm_salt"] as Array[StringName])
	var patrol := _reward(&"first_footsteps.patrol")
	assert_eq([patrol.source, patrol.source_id], [RewardDefinition.Source.SITE_VICTORY, &"reedway_patrol"])
	assert_eq(_grants(patrol), {&"bog_iron": 2})
	var guard := _reward(&"first_footsteps.guard")
	assert_eq([guard.source, guard.source_id], [RewardDefinition.Source.SITE_VICTORY, &"bell_guard"])
	assert_eq(_grants(guard), {&"bog_iron": 2, &"storm_salt": 1})
	var restoration := _reward(&"first_footsteps.restoration")
	assert_eq([restoration.source, restoration.source_id], [RewardDefinition.Source.WORLD_FLAG, WorldDefinition.FLAG_BELL])
	assert_eq(restoration.items.size(), 1)
	assert_eq(restoration.items[0].kind, RewardItem.Kind.EQUIPMENT)
	assert_eq(restoration.items[0].equipment, registry.armor[&"storm_salt_charm"], "the existing charm, not a copy")
	var seam := _reward(&"first_footsteps.iron_seam")
	assert_eq([seam.source, seam.source_id], [RewardDefinition.Source.GATHERED, &"iron_seam"])
	assert_eq(_grants(seam), {&"bog_iron": 1})
	var niche := _reward(&"first_footsteps.drowned_niche")
	assert_eq([niche.source, niche.source_id], [RewardDefinition.Source.SECRET_FOUND, &"drowned_niche"])
	assert_eq(niche.items.size(), 1)
	assert_eq(niche.items[0].equipment, registry.armor[&"fenrunner_leathers"])
	for reward: RewardDefinition in registry.rewards.values():
		assert_empty(reward.validate(), String(reward.id))
	assert_empty(RewardRules.validate_catalog(registry))
	# The reward is the existing charm with its authored Grounding trait; no balance change.
	var charm: ArmorDefinition = registry.armor[&"storm_salt_charm"]
	assert_eq(charm.slot, Enums.EquipSlot.CHARM)
	assert_eq(charm.traits[0].id, &"grounding")
	assert_true(charm.granted_actions.is_empty(), "no new action fills the eighth slot")


func test_catalog_validation_rejects_malformed_rewards() -> void:
	var bog: MaterialDefinition = registry.materials[&"bog_iron"]
	var charm: ArmorDefinition = registry.armor[&"storm_salt_charm"]
	var site := RewardDefinition.Source.SITE_VICTORY
	var flag := RewardDefinition.Source.WORLD_FLAG
	var stray := MaterialDefinition.new()
	stray.id = &"bog_iron"
	stray.display_name = "Bog Iron"
	stray.description = "An unregistered copy."
	var cases := {
		"lowercase dotted words": _make(&"First Footsteps!", site, &"reedway_patrol", [_material_item(bog, 1)]),
		"grants nothing": _make(&"test.empty", site, &"reedway_patrol", []),
		"null item": _make(&"test.null", site, &"reedway_patrol", [null]),
		"outside 1-99": _make(&"test.zero", site, &"reedway_patrol", [_material_item(bog, 0)]),
		"outside 1-99 ": _make(&"test.huge", site, &"reedway_patrol", [_material_item(bog, 100)]),
		"count must be 1": _make(&"test.two_charms", flag, WorldDefinition.FLAG_BELL, [_equipment_item(charm, 2)]),
		"weapon or armor definition": _make(&"test.potion", flag, WorldDefinition.FLAG_BELL,
			[_equipment_item(registry.potions[&"mending_draught"])]),
		"needs a material": _make(&"test.no_material", site, &"reedway_patrol", [_material_item(null, 1)]),
		"twice": _make(&"test.twice", site, &"reedway_patrol", [_material_item(bog, 1), _material_item(bog, 1)]),
		"not an encounter site": _make(&"test.bell_site", site, &"wayside_bell", [_material_item(bog, 1)]),
		"not an encounter site ": _make(&"test.boss", site, &"mirebell_cantor", [_material_item(bog, 1)]),
		"not a world flag": _make(&"test.flag", flag, &"mirebell_defeated", [_material_item(bog, 1)]),
		"not a registered data/ definition": _make(&"test.stray", site, &"reedway_patrol", [_material_item(stray, 1)]),
		"not a registered data/ definition ": _make(&"test.copy", flag, WorldDefinition.FLAG_BELL,
			[_equipment_item(charm.duplicate())]),
	}
	for expected: String in cases:
		var problems := _problems_with(cases[expected])
		assert_true(Array(problems).any(func(problem: String) -> bool: return problem.contains(expected.strip_edges())),
			"'%s' reported for %s: %s" % [expected.strip_edges(), cases[expected].id, problems])
	# Totals: authored grants of one material must stay below the stack limit (no overflow).
	var flood: Array[RewardItem] = [_material_item(bog, RewardItem.MAX_COUNT)]
	for index in ceili(float(MaterialDefinition.MAX_COUNT) / RewardItem.MAX_COUNT):
		registry.rewards[StringName("test.flood_%d" % index)] = _make(StringName("test.flood_%d" % index), site,
			&"reedway_patrol", flood)
	var totals := RewardRules.validate_catalog(registry)
	assert_true(Array(totals).any(func(problem: String) -> bool: return problem.contains("above the %d stack limit" % MaterialDefinition.MAX_COUNT)),
		"over-limit totals are reported: %s" % totals)
	# Duplicate claim ids are a load problem, as for every other definition type.
	registry._register(_make(&"first_footsteps.patrol", site, &"reedway_patrol", [_material_item(bog, 1)]), "res://test_duplicate.tres")
	assert_true(Array(registry.load_problems).any(func(problem: String) -> bool: return problem.contains("duplicate id 'first_footsteps.patrol'")))


func test_grants_saturate_record_claims_and_never_duplicate_equipment() -> void:
	var progress := ProgressState.new()
	progress.materials[&"bog_iron"] = MaterialDefinition.MAX_COUNT - 1
	var guard := _reward(&"first_footsteps.guard")
	var receipts := RewardRules.grant(progress, [guard])
	assert_eq(receipts.size(), 1)
	assert_eq(progress.material_count(&"bog_iron"), MaterialDefinition.MAX_COUNT, "saturates, never wraps")
	assert_eq([receipts[0].items[0].added, receipts[0].items[0].total], [1, MaterialDefinition.MAX_COUNT])
	assert_eq(progress.material_count(&"storm_salt"), 1)
	assert_eq(receipts[0].status, RewardReadout.Status.GRANTED)
	assert_true(progress.has_claim(&"first_footsteps.guard"))
	assert_empty(RewardRules.grant(progress, [guard]), "a claimed reward grants nothing")
	assert_eq(progress.material_count(&"storm_salt"), 1)
	# Already owned equipment (e.g. a grandfathered legacy loadout) is never duplicated.
	progress.owned_equipment.append(&"storm_salt_charm")
	var charm_receipt := RewardRules.grant(progress, [_reward(&"first_footsteps.restoration")])[0]
	assert_eq(progress.owned_equipment.count(&"storm_salt_charm"), 1)
	assert_true(charm_receipt.items[0].owned)
	assert_eq(charm_receipt.items[0].added, 0)
	assert_eq(charm_receipt.summary(), "5 equipment slots", "the permanent expansion is still new when the charm was already owned")
	assert_eq(charm_receipt.status_text(), WorldCopy.REWARD_RECEIVED % "5 equipment slots")
	assert_true(progress.has_claim(&"first_footsteps.restoration"), "the claim is still recorded")
	# Claim-id order, whatever order the caller passes.
	var fresh := ProgressState.new()
	var granted := RewardRules.grant(fresh, [_reward(&"first_footsteps.restoration"), _reward(&"first_footsteps.patrol"), guard])
	assert_eq(granted.map(func(receipt: RewardReadout) -> StringName: return receipt.claim_id),
		[&"first_footsteps.guard", &"first_footsteps.patrol", &"first_footsteps.restoration"])
	assert_eq(fresh.reward_claims, [&"first_footsteps.guard", &"first_footsteps.patrol", &"first_footsteps.restoration"] as Array[StringName])
	assert_eq(fresh.material_count(&"bog_iron"), 4)
	assert_eq(fresh.owned_equipment.count(&"storm_salt_charm"), 1)


func test_previews_and_receipts_are_plain_public_data() -> void:
	var progress := ProgressState.new()
	var guard := _reward(&"first_footsteps.guard")
	var preview := RewardRules.preview(progress, guard)
	assert_eq(preview.status, RewardReadout.Status.AVAILABLE)
	assert_eq(preview.status_text(), WorldCopy.REWARD_AVAILABLE)
	assert_eq(preview.label, "Bell-approach salvage")
	assert_eq(preview.summary(), "2 Bog Iron, 1 Storm Salt")
	assert_eq(preview.items[0].description, registry.materials[&"bog_iron"].description)
	for text in [preview.plain_text(), preview.summary(), preview.label]:
		for word: String in FORBIDDEN:
			assert_false(text.contains(word), "no creature or encounter facts: %s" % word)
	for entry in preview.items:
		for value: Variant in entry.values():
			assert_false(value is Object, "readouts hold plain data, never shared Resources")
	preview.items[0].count = 50
	preview.items.clear()
	assert_eq(guard.items[0].count, 2, "changing a readout never changes the definition")
	var receipt := RewardRules.grant(progress, [guard])[0]
	assert_eq(receipt.status_text(), WorldCopy.REWARD_RECEIVED % "2 Bog Iron, 1 Storm Salt")
	receipt.items[0].total = 0
	receipt.items[0].added = 99
	assert_eq(progress.material_count(&"bog_iron"), 2, "nor the saved counts")
	assert_eq(RewardRules.preview(progress, guard).status, RewardReadout.Status.CLAIMED)
	assert_eq(RewardRules.preview(progress, guard).status_text(), WorldCopy.REWARD_CLAIMED)
	assert_eq(RewardRules.preview(progress, guard).items[0].total, 2, "previews report current holdings")
	var charm_preview := RewardRules.preview(progress, _reward(&"first_footsteps.restoration"))
	assert_eq(charm_preview.summary(), "Storm Salt Charm, 5 equipment slots")
	assert_false(charm_preview.items[0].owned)


func test_saved_reward_and_inventory_data_is_parsed_without_trusting_it() -> void:
	var data := ProgressState.new().to_dict()
	data.rewards = {"claims": [1, null, "", {"a": 1}, "first_footsteps.guard", "first_footsteps.guard", "future.reward"]}
	data.inventory.materials = {"bog_iron": -5, "storm_salt": "lots", "glass_beads": 2.5, "ember_dust": 1e12, "": 3,
		"fen_reed": 4.0, "mist": NAN, "ash": true}
	data.inventory.equipment = ["pilgrims_edge", 7, null, "pilgrims_edge", "storm_salt_charm", ""]
	var state := ProgressState.from_dict(data)
	assert_eq(state.reward_claims, [&"first_footsteps.guard", &"future.reward"] as Array[StringName],
		"strings only, unique, sorted; an unknown claim is kept (it can only block a grant that does not exist)")
	assert_eq(state.materials.size(), 2, "negative, fractional, non-numeric, boolean and NaN counts dropped")
	assert_eq(state.materials[&"ember_dust"], MaterialDefinition.MAX_COUNT, "huge counts capped")
	assert_eq(state.materials[&"fen_reed"], 4)
	assert_eq(state.owned_equipment, [&"pilgrims_edge", &"storm_salt_charm"] as Array[StringName])
	var inventory := PreparationRules.inventory(state, registry)
	assert_true(inventory.materials.is_empty(), "unknown materials stay in the save but never reach a readout")
	assert_false(inventory.owns(&"ember_dust"))
	var round_trip := ProgressState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_eq(_canonical(round_trip.to_dict()), _canonical(state.to_dict()), "sanitized data round-trips through JSON")
	# Wrong-typed sections fall back to defaults instead of failing the load.
	var broken := ProgressState.from_dict({"rewards": 5, "inventory": "x", "loadout": [],
		"world": {"cleared": "bell_guard", "flags": {"wayside_bell_restored": "yes"}}})
	assert_empty(broken.reward_claims)
	assert_true(broken.materials.is_empty())
	assert_eq(broken.owned_equipment, ProgressState.new().owned_equipment, "starter equipment kept")
	assert_eq(broken.loadout_weapon, &"pilgrims_edge")
	assert_true(RewardRules.catch_up(broken, registry).is_empty(), "malformed journey data proves nothing")
	var odd_loadout := ProgressState.from_dict({"loadout": {"weapon": 5, "garb": null, "charm": ["x"], "relic": "lost_relic",
		"potions": "all"}, "rewards": {"claims": {"first_footsteps.guard": true}}})
	assert_eq([odd_loadout.loadout_weapon, odd_loadout.loadout_garb, odd_loadout.loadout_charm, odd_loadout.loadout_relic],
		[&"pilgrims_edge", &"pilgrims_coat", &"", &"lost_relic"], "wrong types become defaults; strings wait for repair")
	assert_eq(odd_loadout.loadout_potions, ProgressState.new().loadout_potions)
	assert_empty(odd_loadout.reward_claims, "a claims dictionary is not a claim list")
