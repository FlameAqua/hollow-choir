class_name RecipeReadout
extends RefCounted
## One Forge or Stillroom recipe for the live save (V0.5B): its public facts, price against held
## materials, mastery requirement, ownership and the result a purchase or refund would return now.
## Plain data copied from the approved definitions and the save; changing it changes nothing.
## Widgets present these facts; they never compute affordability, mastery or eligibility.

var id: StringName = &""
var station: RecipeDefinition.Station = RecipeDefinition.Station.FORGE
## "Forge" / "Stillroom".
var station_label: String = ""
var kind: RecipeDefinition.Kind = RecipeDefinition.Kind.FITTING_KIT
var name: String = ""
var description: String = ""
## [{id: StringName, name: String, icon_path: String, count: int (price), held: int,
##   enough: bool (held >= count)}], in authored order.
var costs: Array[Dictionary] = []
## Stillroom vocabulary: the public Base (a reusable home supply, never a saved stack or hidden
## cost), the Reagent (the costs' materials, by name) and the Catalyst ("" = none).
var base_name: String = ""
var base_description: String = ""
var reagents: PackedStringArray = PackedStringArray()
var catalyst: String = ""
## Saved mastery points needed on any one listed owned weapon (0 = none), the best current value
## among them and their public names.
var mastery_required: int = 0
var mastery_current: int = 0
var mastery_weapons: PackedStringArray = PackedStringArray()
var mastery_met := true
## Unlocked by this save.
var owned := false
var refundable := false
## What a refund would return now: [{id, name, icon_path, count, held, total (held after)}].
## Empty for permanent recipes.
var refund: Array[Dictionary] = []
## purchase(id) / refund(id) would be accepted now (station open, no pending encounter, rules met).
var can_purchase := false
var purchase_reason: CraftingResult.Reason = CraftingResult.Reason.OK
var purchase_reason_text: String = ""
var can_refund := false
var refund_reason: CraftingResult.Reason = CraftingResult.Reason.OK
var refund_reason_text: String = ""
## FITTING_KIT: the weapon and its fitting choices [{id, name, description, trait: {id, name,
## description, details}, source: String (the authoring item's name)}].
var weapon_id: StringName = &""
var weapon_name: String = ""
var fittings: Array[Dictionary] = []
## POTION: the unlocked potion's public facts (effects and charges are the authored ones).
var potion_id: StringName = &""
var potion_name: String = ""
var potion_description: String = ""
var potion_charges: int = 0
## Playtest revision. POTION: doses one brew adds, the doses held now and after a brew, the
## per-encounter cap (= potion_charges), and what brew(id) would return now. can_purchase mirrors
## can_brew for a potion recipe. repeatable = it can be brewed again and again; retired = a legacy
## fitting kit that can no longer be bought. For a FITTING recipe owned = the fitting is owned.
var potion_icon_path: String = ""
var yield_count: int = 0
var potion_held: int = 0
var potion_cap: int = 0
var potion_total_after: int = 0
var can_brew := false
var brew_reason: CraftingResult.Reason = CraftingResult.Reason.OK
var brew_reason_text: String = ""
var repeatable := false
var retired := false


func plain_text() -> String:
	var prices := PackedStringArray()
	for cost in costs:
		prices.append("%d %s (held %d)" % [cost.count, cost.name, cost.held])
	var state := "unlocked" if owned else ("available" if can_purchase else purchase_reason_text)
	return "%s · %s · %s · %s" % [station_label, name, ", ".join(prices), state]
