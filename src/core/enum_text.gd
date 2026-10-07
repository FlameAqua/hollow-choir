class_name EnumText
extends RefCounted
## Player-facing names for enum values (one place to localise later via tr()).


static func grade(value: Enums.ExecutionGrade) -> String:
	match value:
		Enums.ExecutionGrade.MISS:
			return "Miss"
		Enums.ExecutionGrade.PERFECT:
			return "Perfect"
	return "Good"


static func reaction(value: Enums.ReactionType) -> String:
	match value:
		Enums.ReactionType.BRACE:
			return "Brace"
		Enums.ReactionType.EVADE:
			return "Evade"
		Enums.ReactionType.PARRY:
			return "Parry"
	return "No reaction"


static func damage_type(value: Enums.DamageType) -> String:
	match value:
		Enums.DamageType.SLASH:
			return "Slash"
		Enums.DamageType.BLUNT:
			return "Blunt"
		Enums.DamageType.PIERCE:
			return "Pierce"
		Enums.DamageType.FIRE:
			return "Fire"
		Enums.DamageType.STORM:
			return "Storm"
		Enums.DamageType.BLIGHT:
			return "Blight"
		Enums.DamageType.PURE:
			return "Pure"
	return "None"


static func status(value: Enums.StatusId) -> String:
	match value:
		Enums.StatusId.BURN:
			return "Burn"
		Enums.StatusId.WET:
			return "Wet"
		Enums.StatusId.SHOCK:
			return "Shock"
		Enums.StatusId.CHILL:
			return "Chill"
		Enums.StatusId.BLEED:
			return "Bleed"
		Enums.StatusId.BLIGHT:
			return "Blight"
	return "None"


static func category(value: Enums.ActionCategory) -> String:
	match value:
		Enums.ActionCategory.ATTACK:
			return "Attack"
		Enums.ActionCategory.TECHNIQUE:
			return "Technique"
		Enums.ActionCategory.MAGIC:
			return "Magic"
		Enums.ActionCategory.GUARD:
			return "Guard"
		Enums.ActionCategory.ITEM:
			return "Item"
		Enums.ActionCategory.INSPECT:
			return "Inspect"
	return "?"


static func command_type(value: Enums.ActionCommandType) -> String:
	match value:
		Enums.ActionCommandType.TIMING:
			return "Timing"
		Enums.ActionCommandType.HOLD_RELEASE:
			return "Hold & release"
		Enums.ActionCommandType.RHYTHM:
			return "Rhythm"
		Enums.ActionCommandType.OPTIONAL_AIM:
			return "Aim"
	return "None"


static func family(value: Enums.WeaponFamily) -> String:
	match value:
		Enums.WeaponFamily.SWORD:
			return "Sword"
		Enums.WeaponFamily.HAMMER:
			return "Hammer"
		Enums.WeaponFamily.BOW:
			return "Bow"
		Enums.WeaponFamily.DAGGERS:
			return "Daggers"
		Enums.WeaponFamily.STAFF:
			return "Staff"
		Enums.WeaponFamily.CHAINBLADE:
			return "Chainblade"
	return "—"


static func rarity(value: Enums.Rarity) -> String:
	match value:
		Enums.Rarity.UNCOMMON:
			return "Uncommon"
		Enums.Rarity.RARE:
			return "Rare"
		Enums.Rarity.RELIC:
			return "Relic"
	return "Common"


static func role(value: Enums.EnemyRole) -> String:
	match value:
		Enums.EnemyRole.BULWARK:
			return "Bulwark"
		Enums.EnemyRole.RAVAGER:
			return "Ravager"
		Enums.EnemyRole.MENDICANT:
			return "Mendicant"
		Enums.EnemyRole.HEXER:
			return "Hexer"
		Enums.EnemyRole.STALKER:
			return "Stalker"
		Enums.EnemyRole.CONDUCTOR:
			return "Conductor"
	return "?"


static func difficulty(value: Enums.TacticalDifficulty) -> String:
	match value:
		Enums.TacticalDifficulty.STORY:
			return "Story"
		Enums.TacticalDifficulty.TACTICIAN:
			return "Tactician"
	return "Adventurer"


static func assist(value: Enums.ExecutionAssist) -> String:
	match value:
		Enums.ExecutionAssist.GENEROUS:
			return "Generous"
		Enums.ExecutionAssist.PRECISE:
			return "Precise"
		Enums.ExecutionAssist.ASSISTED:
			return "Assisted"
	return "Standard"


static func research_level(value: Enums.ResearchLevel) -> String:
	match value:
		Enums.ResearchLevel.OBSERVED:
			return "Observed"
		Enums.ResearchLevel.STUDIED:
			return "Studied"
		Enums.ResearchLevel.UNDERSTOOD:
			return "Understood"
		Enums.ResearchLevel.MASTERED:
			return "Mastered"
	return "Unknown"


static func research_source(value: Enums.ResearchSource) -> String:
	match value:
		Enums.ResearchSource.ENCOUNTER:
			return "Encountered"
		Enums.ResearchSource.INSPECT:
			return "Inspected"
		Enums.ResearchSource.DEFEAT:
			return "Defeated"
		Enums.ResearchSource.WEAKNESS:
			return "Exploited weakness"
		Enums.ResearchSource.SIGNATURE_PARRY:
			return "Parried signature move"
		Enums.ResearchSource.RARE_ABILITY:
			return "Observed rare ability"
		Enums.ResearchSource.LORE:
			return "Lore"
	return "Quest"


static func intent_category(value: Enums.IntentCategory) -> String:
	match value:
		Enums.IntentCategory.ATTACK:
			return "Attack"
		Enums.IntentCategory.HEAVY_ATTACK:
			return "Heavy attack"
		Enums.IntentCategory.AREA_ATTACK:
			return "Area attack"
		Enums.IntentCategory.HEX:
			return "Hex"
		Enums.IntentCategory.ARMOR_BREAK:
			return "Armor break"
		Enums.IntentCategory.HEAL:
			return "Heal"
		Enums.IntentCategory.BUFF:
			return "Empower"
		Enums.IntentCategory.PROTECT:
			return "Protect"
		Enums.IntentCategory.BATTLEFIELD:
			return "Alter battlefield"
	return "Wait"


static func outcome(value: Enums.BattleOutcome) -> String:
	match value:
		Enums.BattleOutcome.VICTORY:
			return "Victory"
		Enums.BattleOutcome.DEFEAT:
			return "Defeat"
		Enums.BattleOutcome.TIMEOUT:
			return "Timeout"
	return "—"


static func simulated_execution(value: Enums.SimulatedExecution) -> String:
	match value:
		Enums.SimulatedExecution.MISS:
			return "Miss"
		Enums.SimulatedExecution.PERFECT:
			return "Perfect"
		Enums.SimulatedExecution.MIXED:
			return "Mixed"
	return "Good"
