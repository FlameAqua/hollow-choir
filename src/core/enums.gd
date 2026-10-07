class_name Enums
extends RefCounted
## Closed vocabularies shared by data and logic.
##
## APPEND-ONLY: values are stored as integers in .tres files and save files.
## Never reorder, renumber or reuse a value (DECISION_LOG D-005). Open-ended content
## (weapons, enemies, items…) is identified by StringName ids on Resources instead.

enum Side { PLAYER = 0, ENEMY = 1 }

## The six player action types from the GDD.
enum ActionCategory { ATTACK = 0, TECHNIQUE = 1, MAGIC = 2, GUARD = 3, ITEM = 4, INSPECT = 5 }

enum ActionCommandType { NONE = 0, TIMING = 1, HOLD_RELEASE = 2, RHYTHM = 3, OPTIONAL_AIM = 4 }

enum ExecutionGrade { MISS = 0, GOOD = 1, PERFECT = 2 }

enum ReactionType { NONE = 0, BRACE = 1, EVADE = 2, PARRY = 3 }

## Max six statuses for the whole game (GDD). CHILL and BLIGHT are reserved, not yet authored.
enum StatusId { NONE = 0, BURN = 1, WET = 2, SHOCK = 3, CHILL = 4, BLEED = 5, BLIGHT = 6 }

## PURE ignores Guard and weakness (used by status damage).
enum DamageType { NONE = 0, SLASH = 1, BLUNT = 2, PIERCE = 3, FIRE = 4, STORM = 5, BLIGHT = 6, PURE = 7 }

enum WeaponFamily { NONE = 0, SWORD = 1, HAMMER = 2, BOW = 3, DAGGERS = 4, STAFF = 5, CHAINBLADE = 6 }

enum Rarity { COMMON = 0, UNCOMMON = 1, RARE = 2, RELIC = 3 }

enum EquipSlot { WEAPON = 0, GARB = 1, CHARM = 2, RELIC = 3 }

enum ResonanceTag { NONE = 0, STORM = 1, BLOOM = 2, CHOIR = 3, HUNTER = 4, HOLLOW = 5, EMBER = 6 }

enum EnemyRole { BULWARK = 0, RAVAGER = 1, MENDICANT = 2, HEXER = 3, STALKER = 4, CONDUCTOR = 5 }

enum EnemyTier { NORMAL = 0, ELITE = 1, BOSS = 2 }

enum TacticalDifficulty { STORY = 0, ADVENTURER = 1, TACTICIAN = 2 }

enum ExecutionAssist { GENEROUS = 0, STANDARD = 1, PRECISE = 2, ASSISTED = 3 }

## Simulated human execution for automated battles.
enum SimulatedExecution { MISS = 0, GOOD = 1, PERFECT = 2, MIXED = 3 }

## Who an action may target, relative to the acting unit.
enum TargetRule {
	NONE = 0,          ## No unit target (battlefield actions).
	SELF = 1,
	SINGLE_ENEMY = 2,  ## One unit of the opposing side.
	ALL_ENEMIES = 3,
	SINGLE_ALLY = 4,   ## One unit of the actor's side, including itself.
	ALL_ALLIES = 5,
	OTHER_ALLY = 6,    ## One unit of the actor's side, excluding itself.
}

enum ActionTag {
	STRENUOUS = 0,   ## Triggers Bleed on the actor.
	IMPACT = 1,      ## Heavy blow (e.g. splashes Wet in Flooded Ground).
	RANGED = 2,      ## Fired from range.
	PRECISION = 3,   ## Weak-point specialist: extra weak-point multiplier applies.
	INTERRUPT = 4,   ## Bonus Stagger against channeling targets.
	OPENING = 5,     ## A risky move: parrying it opens a large window (traits key off this).
}

enum ConditionSeverity { MAJOR = 0, MINOR = 1 }

enum ResearchLevel { UNKNOWN = 0, OBSERVED = 1, STUDIED = 2, UNDERSTOOD = 3, MASTERED = 4 }

enum ResearchSource {
	ENCOUNTER = 0, INSPECT = 1, DEFEAT = 2, WEAKNESS = 3,
	SIGNATURE_PARRY = 4, RARE_ABILITY = 5, LORE = 6, QUEST = 7,
}

enum BattlePhase {
	BATTLE_START = 0, ROUND_START = 1, UNIT_START = 2, PLAYER_SELECT = 3,
	ACTION_COMMAND = 4, ACTION_RESOLVE = 5, ENEMY_DECIDE = 6, ENEMY_TELEGRAPH = 7,
	REACTION_WINDOW = 8, REACTION_RESOLVE = 9, UNIT_END = 10, ROUND_END = 11,
	VICTORY = 12, DEFEAT = 13,
}

enum BattleOutcome { NONE = 0, VICTORY = 1, DEFEAT = 2, TIMEOUT = 3 }

## Optional pre-combat advantage from overworld approach.
enum Advantage { NONE = 0, PARTY_AMBUSH = 1, ENEMY_AMBUSH = 2 }

## What an enemy intent icon communicates (GDD "Enemy telegraphs").
enum IntentCategory {
	ATTACK = 0, HEAVY_ATTACK = 1, AREA_ATTACK = 2, HEX = 3, ARMOR_BREAK = 4,
	HEAL = 5, BUFF = 6, PROTECT = 7, BATTLEFIELD = 8, WAIT = 9,
}

# --- Rules engine vocabulary (Traits / Effects / Conditions / Modifiers) -----------------

## Battle moments that triggered effects can react to. Each event has an ACTOR and/or TARGET
## role (see docs/DATA_CONTRACTS.md "Trigger roles").
enum TriggerType {
	BATTLE_START = 0,
	ROUND_START = 1,
	ROUND_END = 2,
	TURN_START = 3,         ## actor = unit whose activation begins
	TURN_END = 4,           ## actor = unit whose activation ends
	ACTION_RESOLVED = 5,    ## actor = user, target = primary target
	HIT_LANDED = 6,         ## actor = attacker, target = defender (once per target hit)
	DAMAGE_TAKEN = 7,       ## actor = attacker (may be null), target = damaged unit
	REACTION = 8,           ## actor = attacker, target = reacting unit
	STATUS_APPLIED = 9,     ## actor = source (may be null), target = bearer
	STATUS_REMOVED = 10,    ## target = former bearer
	STAGGER_BREAK = 11,     ## actor = breaker, target = broken unit
	WEAKPOINT_EXPOSED = 12, ## actor = cause, target = exposed unit
	ITEM_USED = 13,         ## actor = user, target = item target
	HEALED = 14,            ## actor = healer, target = healed unit
	UNIT_DEFEATED = 15,     ## actor = killer (may be null), target = defeated unit
}

## Which event role a trigger watches.
enum TriggerWatch { ACTOR = 0, TARGET = 1, NONE = 2 }

## Required relation between the watched unit and the trait owner.
enum TriggerRelation { OWNER = 0, OWNER_ALLY = 1, OWNER_ALLY_OTHER = 2, OWNER_ENEMY = 3, ANY = 4 }

enum EffectType {
	DAMAGE = 0,
	HEAL = 1,
	GAIN_FOCUS = 2,
	LOSE_FOCUS = 3,
	STAGGER_DAMAGE = 4,
	APPLY_STATUS = 5,
	REMOVE_STATUS = 6,
	EXTEND_STATUS = 7,      ## +turns (TURNS mode) or +charges (CHARGES mode)
	GRANT_BUFF = 8,
	EXPOSE_WEAK_POINT = 9,
	DELAY_TURN = 10,        ## Move the unit's pending activation to the end of the round.
	INTERCEPT = 11,         ## OWNER covers the effect target until OWNER's next turn.
	CHAIN_STATUS = 12,      ## Apply `status` to every unit matching `filter_status`, flagged as chain.
	CLEANSE = 13,           ## Remove every status from the unit.
	RESTORE_STAGGER = 14,
	ADD_CONDITION = 15,
	REMOVE_CONDITION = 16,
	REMOVE_BUFF = 17,
}

## Recipients of an effect. In an action, OWNER = ACTOR = the user and TARGET = each target.
enum EffectTarget {
	OWNER = 0,
	ACTOR = 1,
	TARGET = 2,
	OWNER_ALLIES = 3,          ## Owner's side including owner.
	OWNER_ALLIES_OTHER = 4,
	OWNER_ENEMIES = 5,
	TARGET_ALLIES_OTHER = 6,   ## Other units on the target's side.
	ALL = 7,
	NONE = 8,                  ## Battlefield-level effects (conditions).
}

enum AmountScaling {
	FLAT = 0,
	EVENT_AMOUNT = 1,       ## × damage/heal amount of the event
	EVENT_STAGGER = 2,      ## × stagger dealt in the event
	EVENT_OVERHEAL = 3,     ## × overheal of a HEALED event
	RECIPIENT_MAX_HP = 4,   ## × recipient max HP
	OWNER_FORCE = 5,        ## × (1 + owner Force/100)
	RECIPIENT_STACKS = 6,   ## × stacks of `status` on the recipient
}

enum ConditionType {
	ALWAYS = 0,
	GRADE_AT_LEAST = 1,
	GRADE_IS = 2,
	REACTION_SUCCEEDED = 3,   ## event reaction == reaction and it succeeded
	REACTION_ATTEMPTED = 4,   ## event reaction == reaction (any result)
	REACTION_FAILED = 5,      ## event reaction == reaction and it failed
	HAS_STATUS = 6,           ## unit (see `on`) has status
	EVENT_STATUS_IS = 7,
	ACTION_CATEGORY_IS = 8,
	ACTION_HAS_TAG = 9,
	WEAPON_FAMILY_IS = 10,    ## unit (see `on`) wields family
	DAMAGE_TYPE_IS = 11,
	IS_WEAKNESS_HIT = 12,
	HP_BELOW = 13,            ## unit hp fraction < threshold
	HP_ABOVE = 14,
	IS_BROKEN = 15,
	WEAK_POINT_EXPOSED = 16,
	IS_CHANNELING = 17,
	BATTLEFIELD_HAS = 18,     ## `battlefield_condition` is active
	FROM_CHAIN = 19,
	HAS_BUFF = 20,            ## unit has buff `buff`
	ROUND_AT_LEAST = 21,
	IS_OWNER = 22,            ## unit (see `on`) is the trait owner
	SIDE_IS = 23,             ## unit (see `on`) is on side `side`
}

## Which unit a unit-based condition inspects.
enum ConditionOn { OWNER = 0, ACTOR = 1, TARGET = 2 }

enum ModifierStat {
	MAX_HP = 0, FORCE = 1, GUARD = 2, TEMPO = 3, MAX_FOCUS = 4,
	DAMAGE_DEALT = 5, DAMAGE_TAKEN = 6,
	STAGGER_DEALT = 7, STAGGER_TAKEN = 8,
	HEALING_DEALT = 9, HEALING_TAKEN = 10,
	FOCUS_GAIN = 11,
	GOOD_WINDOW = 12, PERFECT_WINDOW = 13, COMMAND_SPEED = 14,
	PERFECT_MULTIPLIER = 15, MISS_MULTIPLIER = 16,
	BRACE_WINDOW = 17, EVADE_WINDOW = 18, PARRY_WINDOW = 19,
	BRACE_REDUCTION = 20,
	STATUS_DURATION_DEALT = 21, STATUS_DURATION_TAKEN = 22,
	STATUS_STACKS_DEALT = 23,
	PARRY_STAGGER = 24,
	WEAK_POINT_MULTIPLIER = 25,
}

enum ModifierOp { ADD = 0, MULTIPLY = 1 }

## How a status counts down.
enum DurationMode {
	TURNS = 0,     ## Decrements at the end of each of the bearer's activations.
	CHARGES = 1,   ## Decrements when the status fires (e.g. Bleed on strenuous actions).
}

enum TickTiming { NONE = 0, TURN_START = 1, TURN_END = 2 }

## When a temporary buff ends.
enum BuffExpiry {
	OWNER_TURN_START = 0,  ## Typical stance: lasts until the owner acts again.
	OWNER_TURN_END = 1,
	ROUND_END = 2,
	NEXT_ACTION = 3,       ## Consumed by the owner's next qualifying action.
	BATTLE_END = 4,
}

# --- AI vocabulary ---------------------------------------------------------------------------

enum ConsiderationType {
	SELF_HP_BELOW = 0,
	TARGET_HP_BELOW = 1,
	ANY_ALLY_HP_BELOW = 2,        ## Any living ally (excluding self) below threshold.
	TARGET_HAS_STATUS = 3,
	TARGET_LACKS_STATUS = 4,
	SELF_HAS_STATUS = 5,
	TARGET_IS_GUARDING = 6,
	TARGET_HIGH_FOCUS = 7,        ## Target Focus >= threshold.
	BATTLEFIELD_HAS = 8,
	ALLY_ROLE_PRESENT = 9,
	TARGET_ROLE_IS = 10,
	ALLY_SYNERGY_FOLLOWUP = 11,   ## An ally acting later this round can pay off this setup.
	TARGET_ALREADY_TARGETED = 12, ## Another enemy already intends to hit this target.
	CAN_KILL_TARGET = 13,         ## Expected damage >= target HP.
	CHANNEL_AT_RISK = 14,         ## Party can probably break me before this channel releases.
	PARTY_THREAT_HIGH = 15,       ## Some party unit has Focus >= threshold.
	TARGET_IS_CHANNELING = 16,
	RECENTLY_USED = 17,           ## I used this action on my previous activation.
	ROUND_AT_LEAST = 18,
	TARGET_WAS_DAMAGED = 19,      ## Target took damage since its last activation.
	SELF_IS_PROTECTED = 20,       ## Someone is intercepting for me.
	PARTY_COUNTERS_THIS = 21,     ## The party already succeeded >= threshold times this battle with a
	                              ## reaction this action allows (observed, never predicted).
}

enum SynergyTag { NONE = 0, WET = 1, BURN = 2, SHOCK = 3, BLEED = 4, GUARD_BREAK = 5, EMPOWER = 6 }

# --- Presentation helpers ----------------------------------------------------------------------

## Placeholder silhouette used until real sprites exist.
enum VisualShape { HUMANOID = 0, BEAST = 1, BLOB = 2, TALL = 3, FLYER = 4, SHELL = 5, COLOSSUS = 6, DUMMY = 7 }
