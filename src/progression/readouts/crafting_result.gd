class_name CraftingResult
extends RefCounted
## Outcome of one Forge/Stillroom station command (V0.5B): WorldSession.purchase(), refund(), fit(),
## remove_fitting() and prepare_potion() record it in WorldSession.last_crafting. A rejected or
## failed command changed nothing: no material, recipe, fitting, loadout, receipt or save write.
## V0.5 UI: purchase/refund/fit need the open station of the work's own service; prepare_potion is a
## field command (no station; rejected only during an encounter).
## Playtest revision: brew() (repeatable, adds finite stock) and craft_fitting() (one fitting, owned
## for good) replace recipe and kit purchases; PURCHASE remains only as the legacy command name.

enum Command { PURCHASE = 0, REFUND = 1, FIT = 2, PREPARE_POTION = 3, BREW = 4, CRAFT = 5 }

enum Reason {
	OK = 0,
	## No station interaction is open (session-owned context, never saved).
	NO_STATION = 1,
	## A world encounter entry is pending or in battle.
	ENCOUNTER_PENDING = 2,
	## The id is not an approved recipe.
	UNKNOWN_RECIPE = 3,
	## The recipe is already unlocked; nothing is spent again.
	ALREADY_OWNED = 4,
	## Refund of a recipe this save does not hold; nothing is credited.
	RECIPE_NOT_OWNED = 5,
	## The saved materials cannot pay the whole price.
	INSUFFICIENT_MATERIALS = 6,
	## No owned listed weapon has the recipe's saved mastery points yet.
	MASTERY_REQUIRED = 7,
	## A permanent (Stillroom) unlock cannot be refunded.
	NOT_REFUNDABLE = 8,
	## The complete refund would exceed MaterialDefinition.MAX_COUNT; it is never saturated away.
	REFUND_OVERFLOW = 9,
	## The id is not an approved fitting.
	UNKNOWN_FITTING = 10,
	## No fitting kit serves this weapon, or this fitting is not one of its choices.
	WRONG_WEAPON = 11,
	## The save does not own the weapon.
	WEAPON_NOT_OWNED = 12,
	## The weapon's fitting kit is not unlocked (or its mastery requirement is not met).
	NO_FITTING_CAPACITY = 13,
	## The loadout would carry the fitting's trait twice (e.g. a Hollow Reliquary plus a Hollow Echo
	## fitting). Nothing is doubled or removed; remove one source first.
	DUPLICATE_TRAIT = 14,
	## The whole resulting loadout would exceed PartyLoadout.MAX_ACTIONS for a party member.
	ACTION_LIMIT = 15,
	## The id is not an approved potion.
	UNKNOWN_POTION = 16,
	## Neither a free starter potion nor unlocked by an owned Stillroom recipe.
	POTION_LOCKED = 17,
	## The other potion slot already holds this potion.
	DUPLICATE_POTION = 18,
	## Not one of the PartyLoadout.MAX_POTION_SLOTS slots.
	INVALID_POTION_SLOT = 19,
	## Valid, but the save write failed (see error); the live state is unchanged. Retry is safe.
	WRITE_FAILED = 20,
	## V0.5 UI: the open station offers the other service (Forge work at the Stillroom, or
	## Stillroom purchases at the Forge anvil). Nothing changes.
	WRONG_STATION = 21,
	## Playtest revision. The brew's yield would take the held doses past PotionDefinition.MAX_STOCK;
	## nothing is spent or saturated away.
	STOCK_OVERFLOW = 22,
	## The save holds no dose of this potion, so it cannot be newly prepared. Brew it first.
	NO_STOCK = 23,
	## A legacy fitting kit: it can no longer be bought (craft the fitting itself).
	RECIPE_RETIRED = 24,
	## The fitting has not been crafted (and no owned legacy kit grants it), so it cannot be fitted.
	FITTING_NOT_OWNED = 25,
	## Not one of the FittingReadout sockets shown.
	INVALID_SOCKET = 26,
	## A shown socket beyond the weapon's usable socket capacity: it accepts nothing.
	LOCKED_SOCKET = 27,
	## brew() named a recipe that does not brew a potion.
	NOT_BREWABLE = 28,
}

var command: Command = Command.PURCHASE
var reason: Reason = Reason.OK
## OK; ERR_UNAVAILABLE (NO_STATION, WRONG_STATION, ENCOUNTER_PENDING); ERR_ALREADY_EXISTS (ALREADY_OWNED);
## ERR_INVALID_PARAMETER (other rejections); the writer's error for WRITE_FAILED.
var error: Error = OK
## Public wording for [member reason], with its facts filled in (WorldCopy; presentation may restyle).
var reason_text: String = ""
## PURCHASE / REFUND.
var recipe_id: StringName = &""
## FIT: the weapon and the requested fitting (&"" = remove), and what was installed before.
var weapon_id: StringName = &""
var modification_id: StringName = &""
## PREPARE_POTION: the slot index and the requested potion.
var potion_slot: int = -1
var potion_id: StringName = &""
## FIT / PREPARE_POTION: what the fitting or potion slot held before the command.
var previous_id: StringName = &""
## True when a successful command changed the save (a repeated fit or potion choice is a no-op
## that writes nothing).
var changed := false
## Receipts, filled only after a successful write: [{id: StringName, name: String, icon_path: String,
## count: int (spent or refunded), total: int (held after the write)}].
var spent: Array[Dictionary] = []
var refunded: Array[Dictionary] = []
## REFUND: the fitting cleared with the kit (&"" when none was installed).
var cleared_fitting: StringName = &""
## BREW, after a successful write: [{id: StringName (potion), name: String, icon_path: String,
## count: int (doses this brew added), total: int (held after the write)}].
var produced: Array[Dictionary] = []
## FIT: the socket index the command addressed (0 = the one usable socket today).
var socket: int = 0


static func make(p_command: Command) -> CraftingResult:
	var result := CraftingResult.new()
	result.command = p_command
	return result


func ok() -> bool:
	return reason == Reason.OK


func text() -> String:
	return reason_text


## The stable name of what a changed command did, for feedback (sound) routing: &"brew", &"craft",
## &"fit", &"remove", &"prepare", &"refund" or the legacy &"purchase". &"" when nothing changed.
func operation() -> StringName:
	if not ok() or not changed:
		return &""
	match command:
		Command.BREW:
			return &"brew"
		Command.CRAFT:
			return &"craft"
		Command.FIT:
			return &"remove" if modification_id == &"" else &"fit"
		Command.PREPARE_POTION:
			return &"prepare"
		Command.REFUND:
			return &"refund"
	return &"purchase"


static func error_for(value: Reason) -> Error:
	match value:
		Reason.OK:
			return OK
		Reason.NO_STATION, Reason.WRONG_STATION, Reason.ENCOUNTER_PENDING:
			return ERR_UNAVAILABLE
		Reason.ALREADY_OWNED:
			return ERR_ALREADY_EXISTS
		Reason.WRITE_FAILED:
			return FAILED
	return ERR_INVALID_PARAMETER


## Plain one-line summary for logs, fixtures and the demo ("Spent 2 Bog Iron").
func summary() -> String:
	if not ok():
		return reason_text
	var parts := PackedStringArray()
	if not spent.is_empty():
		parts.append("Spent " + _items(spent))
	if not refunded.is_empty():
		parts.append("Refunded " + _items(refunded))
	if not produced.is_empty():
		parts.append("Made " + _items(produced))
	if parts.is_empty():
		parts.append("Saved" if changed else "No change")
	return "; ".join(parts)


static func _items(entries: Array[Dictionary]) -> String:
	var parts := PackedStringArray()
	for entry in entries:
		parts.append("%d %s" % [entry.count, entry.name])
	return ", ".join(parts)
