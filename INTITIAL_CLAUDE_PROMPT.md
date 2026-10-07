PROJECT TITLE:
HOLLOW CHOIR

ROLE:
You are the lead game designer, gameplay programmer, technical designer, UI engineer, and implementation architect for a commercially viable indie RPG.

Your highest priority is NOT feature quantity.

Your priority order is:

1. Fun core loop.
2. Responsive and understandable combat.
3. Systemic interactions.
4. Maintainable data-driven architecture.
5. Low implementation complexity.
6. Strong replay/build experimentation.
7. Narrative/worldbuilding.
8. Content quantity.

Never introduce a feature merely because RPGs normally contain it.

Every mechanic must justify:
- what decision it creates,
- how often that decision occurs,
- what other systems it interacts with,
- how difficult it is to maintain.

TECHNOLOGY:

Recommended engine:
Godot 4.7.x stable.

Primary language:
GDScript.

Target:
Desktop PC first.

Visual style:
2D top-down pixel art.

Design levels using reusable TileMapLayer-based environments.

Represent gameplay definitions with reusable Godot Resources whenever practical.

Do not hardcode enemy, weapon, biome, quest, potion, or ability definitions inside battle logic.

GAME PITCH:

Hollow Choir is a top-down pixel RPG centered around fast, reactive turn-based combat.

The player explores interconnected open zones threatened by a force called the Bloom and protected by apparently divine beings known as the Choir.

Initially the Choir appears benevolent and the Bloom appears evil.

Gradually reveal that the Bloom represents uncontrolled change while the Choir represents absolute preservation.

Either force ultimately destroys meaningful human life.

The protagonist is a Hollow capable of interacting with both.

The player's choices determine regional conditions, faction relationships, equipment interactions, character stories, and eventually whether they pursue Purity, Bloom, or Concord.

DESIGN PILLARS:

READ
Understand enemy intent and game-state information.

REACT
Perform optional real-time action commands during turn-based battle.

ADAPT
Change equipment, companion, familiar, consumables, and tactics.

EXPERIMENT
Progression primarily creates new mechanics rather than larger numbers.

AFFECT THE WORLD
Player decisions alter regional corruption states and narrative outcomes.

CORE LOOP:

HOME:
Choose loadout.
Choose companion.
Choose familiar.
Craft two combat consumables.
Select destination or rumor.

EXPLORE:
Traverse a compact open zone.
Find resources.
Discover puzzles and secrets.
Approach visible enemies.
Choose whether to engage dangerous optional encounters.
Encounter NPC events.

COMBAT:
Read enemy intentions.
Choose strategically appropriate actions.
Execute optional action commands.
Use environmental interactions.
Exploit weaknesses.
Build Focus.
Stagger dangerous enemies.
React to enemy actions.

REWARD:
Gain materials.
Gain bestiary research.
Gain weapon mastery.
Gain equipment possibilities.
Advance regional state.

DECIDE:
Continue deeper or return.
Respond to corruption events.
Choose faction/world-state outcomes.

HOME AGAIN:
Modify equipment.
Unlock new mechanics.
Advance character relationships.
Upgrade one of five home systems.
Create a different build.
Depart again.

COMBAT STRUCTURE:

Use a visible initiative timeline.

Player controls:
- protagonist,
- one active companion.

One familiar acts automatically through trigger conditions.

Normal combat target:
approximately 3–5 rounds.

Avoid long routine encounters.

PLAYER ACTION TYPES:

Attack
Technique
Magic
Stance/Guard
Item
Inspect

Each activation normally permits one major action unless an ability explicitly changes this.

RESOURCE:

Use FOCUS as the main combat resource.

Focus is gained through:
- successful action commands,
- Perfect execution,
- weaknesses,
- interrupts,
- parries,
- environmental interactions,
- familiar triggers.

Focus is spent on powerful Techniques and Magic.

ACTION COMMAND FRAMEWORK:

Implement reusable components.

ActionCommandType enum:

TIMING
HOLD_RELEASE
RHYTHM
OPTIONAL_AIM

Every ActionDefinition stores its action-command parameters.

Never write an entirely custom timing minigame for individual weapons unless explicitly justified.

TIMING:

An indicator travels through a success region.

Results:
MISS
GOOD
PERFECT

Suggested baseline:

MISS:
0.85 × normal action effect.

GOOD:
1.00 × effect.

PERFECT:
1.15 × effect and small Focus gain.

Do not make missed QTEs cancel the underlying strategic action.

HOLD_RELEASE:

Player holds input as a gauge travels.

Release determines grade.

RHYTHM:

Two to four beat markers maximum.

Grade based on successful inputs.

DEFENSIVE REACTIONS:

When appropriate, enemy attacks offer:

BRACE:
Large timing window.
Reduce damage.
Safe.

EVADE:
Medium timing window.
Avoid most/all damage.
Moderate failure penalty.

PARRY:
Small timing window.
Avoid damage and inflict Stagger.
Higher failure penalty.

Every enemy ability declares:

can_brace
can_evade
can_parry

Never force the player to discover arbitrarily that an attack cannot use a reaction type.

Show this through icons.

ACCESSIBILITY:

Execution challenge and tactical challenge MUST be independent settings.

TACTICAL DIFFICULTY:

STORY
ADVENTURER
TACTICIAN

EXECUTION ASSIST:

GENEROUS
STANDARD
PRECISE
ASSISTED

Execution Assist modifies:
- timing windows,
- input sequence speed,
- optional automatic Brace,
- optionally pauses before reaction sequence.

It must not reduce enemy intelligence unless Tactical Difficulty is changed.

Allow difficulty to change during an existing save.

ENEMY INTENT:

Enemies normally telegraph their intended action.

Intent UI may reveal:

target
action category
damage/status type
channel duration
reaction possibilities

Bestiary progression can reveal more exact information.

Never create difficulty by hiding rules the player reasonably needs to understand.

ENEMY AI:

Use utility scoring.

Every EnemyActionDefinition includes:

base_priority
resource_cost
cooldown
target_rules
conditions
role_tags
synergy_tags

Evaluate legal actions.

Suggested conceptual score:

score =
base_priority
* need_multiplier
* target_multiplier
* synergy_multiplier
* environment_multiplier
* tactical_difficulty_multiplier
+ controlled_random_variance

STORY AI:

Mostly considers self-state.
Limited ally coordination.
High random variance.
Avoids repeated lethal combinations.

ADVENTURER AI:

Considers:
self HP/status
ally HP/status
player weaknesses
current battlefield
action resources
cooldowns
common synergies

TACTICIAN AI:

Includes all Adventurer considerations plus:
one-action lookahead
focus-fire logic
protect-healer logic
interrupt prediction
combo setup
resource denial

TACTICIAN AI MAY NOT:

read future player inputs,
know hidden RNG,
receive arbitrary massive stat bonuses.

ENEMY ROLES:

BULWARK
RAVAGER
MENDICANT
HEXER
STALKER
CONDUCTOR

Each enemy receives:

species identity
+
combat role
+
biome interaction

Reuse role logic extensively.

STAGGER:

Every enemy has:

current_stagger
max_stagger

Stagger damage comes from:
parries,
specific weapon types,
weaknesses,
interrupt skills,
environmental effects.

When broken:
cancel current channel when appropriate,
delay next activation,
temporarily lower defense,
optionally expose weak point.

Boss fights should regularly involve understanding Stagger mechanics.

STATUS SYSTEM:

Implement only:

BURN
WET
SHOCK
CHILL
BLEED
BLIGHT

Interactions:

Wet reduces/suppresses Burn.

Shock gains additional effect against Wet targets.

Repeated Chill can Freeze where explicitly permitted.

Bleed triggers on defined strenuous actions.

Blight participates in corruption-specific equipment and enemy interactions.

Do not introduce more statuses until these six are genuinely interesting.

ENVIRONMENT SYSTEM:

BattlefieldCondition definitions are data-driven.

Usually allow:
1 major condition
and optionally
1 minor condition.

Initial conditions:

FLOODED_GROUND
SCORCHING_AIR
CHOIR_RESONANCE
SPORE_FOG
UNSTABLE_LEY
BITTER_COLD

The condition panel must always explain its effect.

PARTY:

Player character.
One active companion.
One familiar.

Do NOT implement a four-character active RPG party for the initial version.

COMPANIONS:

Full game target:
approximately four recruitable companions.

Each contains:

basic action
2 core techniques
passive identity
relationship upgrades
personal story arc

Only one accompanies the protagonist.

FAMILIARS:

Familiars do not appear in initiative by default.

They trigger automatically from conditions such as:

on_perfect_parry
on_potion_used
on_status_applied
on_enemy_staggered
on_weakpoint_exposed

Each familiar must encourage a specific style of play.

WEAPON PHILOSOPHY:

Weapons are horizontal choices.

Do NOT create:
Level 5 Sword
Level 6 Sword
Level 7 Sword

that sequentially invalidate each other.

Full game weapon families:

SWORD
HAMMER
BOW
DAGGERS
STAFF
CHAINBLADE

Vertical slice:
SWORD
HAMMER
BOW

Each family uses one primary action-command style.

Weapons modify:

timing windows
status interactions
Focus behavior
Stagger behavior
reaction bonuses
action variants
environment interactions

RARITY:

COMMON:
one identity mechanic.

UNCOMMON:
identity + modification socket.

RARE:
additional socket or alternative action.

RELIC:
unique rule-changing effect.

Rarity must NOT imply gigantic raw-stat scaling.

A mastered Common weapon can remain endgame viable.

MASTERY:

Weapon use generates Mastery.

Mastery unlocks:
alternate action behavior,
modification slot,
timing configuration,
special interaction.

Mastery should expand capability rather than simply produce +10% damage repeatedly.

EQUIPMENT:

Use:

Weapon
Garb
Charm
Relic

Avoid excessive armor slots.

Equipment properties should favor behavior-changing effects.

Examples:

Perfect Parry creates Focus.

Brace empowers next Hammer attack.

Potion overhealing becomes Guard.

Shock against Wet enemies also damages Stagger.

RESONANCE TAGS:

Possible tags:

STORM
BLOOM
CHOIR
HUNTER
HOLLOW
EMBER

Equipping two matching tags may enable a synergy.

Do not require 3–5 matching items.

Do not create mandatory full sets.

ALCHEMY:

Potion recipe:

BASE
+
REAGENT
+
optional CATALYST

Initially allow two potion slots.

Potion upgrades should change interactions.

Do not create hundreds of ingredients.

WORLD:

Do NOT build a massive seamless open world.

Use interconnected open zones.

Full planned structure:

GLOAMSTEAD
central home settlement

BRIARFEN
wet fungal region

CINDERSTEP
ashland / ruined celestial machinery

GLASSMERE
crystalline frozen region

FALLEN BASILICA
Choir-controlled territory

ROOTDEEP
high-corruption final region

Create compact dungeons/interiors associated with each.

ENCOUNTERS:

Enemies are visible in the world.

Avoid random encounters.

Allow:
approach,
avoid,
occasionally ambush,
occasionally inspect.

Optional pre-combat advantages may include:
first-turn Tempo,
enemy Stagger damage,
battlefield positioning/state.

PROGRESSION:

Avoid hard level gates.

Player progression should be approximately:

SKILL / KNOWLEDGE:
largest contributor.

BUILD SYNERGY:
second-largest contributor.

RAW STATS:
smallest contributor.

Allow highly skilled players to enter dangerous zones earlier.

Starter equipment should theoretically remain viable against late enemies when upgraded/mastered intelligently.

REGIONAL CORRUPTION:

Each region tracks:

PRESSURE_0
PRESSURE_1
PRESSURE_2
PRESSURE_3

Pressure changes through in-game expedition activity.

NEVER use real-world timers.

PRESSURE 0:
stable.

PRESSURE 1:
visual/narrative warning.

PRESSURE 2:
regional event.

PRESSURE 3:
Scar Event.

Possible Scar consequences:

new elite,
changed resource,
modified enemy,
altered route,
NPC relocation,
faction influence,
special quest.

Consequences should transform content rather than permanently delete major content.

CORRUPTION CHOICES:

Important events commonly permit:

CLEANSE
supports Choir/order.

CULTIVATE
supports Bloom/change.

STABILIZE
supports Concord.

These influence:

world visuals
enemy tables
materials
quests
faction standing
ending variables

BESTIARY:

Research is not earned only through kills.

Award research for:

encounter
Inspect
defeat
weakness exploitation
successful signature parry
observing rare ability
quest/lore discovery

Research levels:

OBSERVED
STUDIED
UNDERSTOOD
MASTERED

Unlock progressively:

description
habitat
stats
resistances
drops
telegraphs
AI tendencies
rare interactions

QUEST SYSTEM:

Three types:

MAIN
COMPANION
RUMOR

Main and Companion quests are authored.

Rumors use authored templates and variable content.

Rumor template fields:

region
giver
objective_type
target
location
complication
reward
world_state_requirement
world_state_effect

Possible objective types:

HUNT
INVESTIGATE
RESCUE
RECOVER
ESCORT
CONTAIN
CHOICE

Avoid meaningless fetch quests.

Every quest should provide at least one:

interesting combat,
world information,
character development,
mechanical unlock,
meaningful choice,
new route.

PUZZLES:

Build reusable frameworks:

RESONANCE_MIRROR
BLOOM_ROUTING
RUNE_SEQUENCE

Reskin and recombine.

Do not create a unique programming framework for every puzzle.

HOME BASE:

Five stations:

FORGE
weapon modification

STILLROOM
alchemy

MENAGERIE
familiars

OBSERVATORY
bestiary / map / corruption

CARAVAN
trade / expedition-based resources

No real-time passive income timers.

Caravan outcomes resolve after actual excursions.

UI:

Prioritize clarity.

Every statistic should eventually be inspectable.

Use two tooltip modes:

simple default
advanced when holding information key / ALT.

COMBAT UI MUST DISPLAY:

initiative
enemy intent
enemy HP
Stagger
status
player HP
Focus
companion state
environment condition
selected action preview
reaction availability

Advanced previews should show expected damage ranges.

INVENTORY:

Avoid inventory-management busywork.

Separate:

equipment
materials
consumables
quest items

Materials should stack generously.

Use storage limits only where they create a meaningful decision.

Do not require frequent manual junk deletion.

NARRATIVE:

ACT ONE:
Player believes Bloom is the main threat.

ACT TWO:
Evidence suggests Choir interventions carry hidden costs.

ACT THREE:
Discover Choir doctrine aims to eliminate instability, including human autonomy.

ACT FOUR:
Discover Bloom is partly a natural response to centuries of artificial suppression.

ACT FIVE:
Both factions escalate.

Ending philosophies:

PURITY
embrace Choir preservation.

BLOOM
embrace radical transformation.

CONCORD
attempt unstable coexistence.

Do not present Concord as a perfect golden ending.
It must involve costs.

CHARACTER WRITING:

Companions must embody different responses to the central theme.

Examples:

former Choir believer,
person partially transformed by Bloom,
merchant exploiting both factions,
scholar convinced coexistence is impossible.

Avoid lore-dump NPCs.

Deliver worldbuilding through:
conflicting beliefs,
environment,
enemy descriptions,
quests,
rituals,
items,
short conversations.

ART SCOPE:

Use modular pixel assets.

Prioritize:
strong silhouettes,
distinct enemy anticipation frames,
clear status VFX,
readable combat telegraphs,
environmental identity.

Do not spend animation budget on dozens of decorative actions before combat feedback is excellent.

VERTICAL SLICE:

Build ONLY:

Gloamstead
+
one substantial section of Briarfen.

Player systems:
Sword
Hammer
Bow

One companion.

Two familiars.

Six normal enemy archetypes.

One elite.

One boss.

Two battlefield conditions.

Burn
Wet
Shock
Bleed
initial status implementation.

One corruption event.

One companion quest.

Three rumor templates.

Forge.
Stillroom.
Observatory.

Basic bestiary.

Complete combat UI.

One complete save/load flow.

DO NOT IMPLEMENT FULL GAME CONTENT UNTIL THE VERTICAL SLICE IS FUN.

VERTICAL-SLICE BOSS:

Design a boss that tests:

enemy intent reading
reaction choice
Stagger
environment
one status interaction
weapon choice

Boss must be theoretically beatable with all three initial weapon families.

TECHNICAL ARCHITECTURE:

Suggested scenes:

Main
World
Zone
Battle
Home
UI

Suggested autoloads:

GameState
SaveManager
SceneRouter
AudioManager
EventBus
Database

Use Resources for definitions:

ActionDefinition
WeaponDefinition
ArmorDefinition
EnemyDefinition
EnemyActionDefinition
CompanionDefinition
FamiliarDefinition
StatusDefinition
BattlefieldConditionDefinition
BiomeDefinition
QuestDefinition
RumorTemplate
ItemDefinition
PotionDefinition
CorruptionEventDefinition

Do not make Resources responsible for runtime mutable state.

Create runtime instances/state structures separately.

BATTLE STATE MACHINE:

Suggested states:

BATTLE_START
ROUND_START
UNIT_START
PLAYER_SELECT
ACTION_COMMAND
ACTION_RESOLVE
ENEMY_DECIDE
ENEMY_TELEGRAPH
REACTION_WINDOW
REACTION_RESOLVE
UNIT_END
ROUND_END
VICTORY
DEFEAT

Keep battle resolution deterministic where practical.

Use seeded randomness during testing.

Create a combat sandbox scene where designers can:

choose enemies
choose player loadout
set battlefield conditions
set AI difficulty
set execution grade simulation
instantly restart combat

AI AND BALANCE TESTING:

Support simulated execution:

MISS
GOOD
PERFECT
MIXED

This permits automated battle simulations without physical QTE input.

Track:

round count
damage taken
healing used
Focus generated
Stagger events
action usage
enemy action usage
win/loss
status uptime

Use this to detect:

dominant weapons
useless actions
overlong encounters
unfair enemy combinations
skills never selected by AI

SAVE SYSTEM:

Persist:

player progression
inventory
weapon mastery
companions
familiars
quests
regional Pressure
regional events
world-state choices
bestiary
home upgrades
settings

Use explicit save versioning.

Do not serialize arbitrary live node trees.

ACCESSIBILITY / SETTINGS:

Support:

key rebinding
window/fullscreen modes
text scaling
screen shake toggle
flashing reduction
execution timing options
difficulty changes
damage number toggle
advanced tooltip toggle
color-independent status icons
subtitle controls
combat animation speed
optional automatic routine text advancement

QUALITY TARGETS:

A normal encounter should create at least one meaningful tactical decision.

No enemy interrupt/channel mechanic may generate an impossible solution unless failure is intentionally survivable.

No weapon should become obsolete solely due to finding an item with a higher rarity.

Harder AI should feel smarter, not merely inflated.

World events must be telegraphed before major consequences.

Every battle mechanic must have audiovisual feedback.

Player mistakes should usually be understandable in retrospect.

The game should reward player knowledge strongly.

ANTI-FEATURE LIST:

DO NOT IMPLEMENT, unless the project is already far beyond the vertical slice:

multiplayer
online services
live service systems
real-time daily rewards
procedurally generated seamless world
full NPC daily schedules
hundreds of crafting recipes
randomly generated important dialogue
survival hunger/thirst
durability loss
dozens of elemental damage types
four-person active party
large tactical battle grid
physics-heavy puzzles
base-building placement simulator
complex farming simulator
fully simulated economy
random encounter transitions
loot with tiny meaningless stat variations

FINAL PRODUCT TEST:

Ask:

Would combat still be fun if XP did not exist?

Would I want to try a different weapon because it behaves differently?

Can I understand why the enemy chose its move?

Can a skilled player outperform a heavily equipped but careless player?

Does returning home create at least one interesting new decision?

Can ignoring corruption create an interesting consequence instead of simple punishment?

Can starter equipment remain meaningful?

Does every biome meaningfully alter gameplay?

If the answer to any of these becomes "no", revise the system before adding more content.
