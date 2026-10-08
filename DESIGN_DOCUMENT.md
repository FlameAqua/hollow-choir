# Hollow Choir — Canonical Game Design Document

## Current design authority — 8 October 2026

**Owner:** Game Director (ChatGPT). **Current milestone:** M1 combat foundation implemented;
M1.1 combat clarity and art integration specified, awaiting implementation and human validation.

Protect **READ · REACT · ADAPT · EXPERIMENT · AFFECT THE WORLD**. Do not begin the world slice or
expand enemy/weapon/system counts until the combat clarity gate passes. Keep the existing deterministic
engine, trait composition, two controlled party members and trigger-only familiar.

Canonical requirements comprise this document and the explicitly incorporated
[M1.1 Combat Clarity specification](docs/design/M1_1_COMBAT_CLARITY.md). The dated current decisions
and that specification supersede older illustrative prompts below where they disagree. The original
research brief and collaboration prompts are retained as rationale and long-term direction; their
examples and unreverified external citations are not proof that features exist or work.

Current review: [M1 Director Review](docs/reviews/M1_DIRECTOR_REVIEW.md).
Engineering handoff: [M1.1 Claude Implementation Brief](docs/briefs/M1_1_IMPLEMENTATION.md).
Visual deliverable: [three-state combat study](docs/design/visuals/combat_study.html).
Art deliverable: [Briarfen candidates and import resources](assets/art/briarfen_v01/README.md).
Decisions and original evidence: [Decision Log](docs/DECISION_LOG.md),
[resolved M1 questions](docs/DESIGN_QUESTIONS.md).

Director preparation while engineering is unavailable:
[controlled policy audit](docs/reports/M1_DIRECTOR_POLICY_AUDIT.md),
[human playtest pack](docs/playtests/M1_1_SESSION_PACK.md), and
[Claude return queue](docs/briefs/CLAUDE_RETURN_QUEUE.md).
These provide evidence and a validation protocol, not a passed gate or an implemented UI.
[Expedition resource candidate A](docs/design/EXPEDITION_RESOURCE_CANDIDATE.md) is a **noncanonical
paper proposal**: compare all-reset encounters with potion-only carry before authorizing any trial.
It does not supersede D-024 or expand the current implementation scope.

### Current scope and rules

- **Presentation before expansion:** clarify actor/target/intent, honest preview scope, input ownership,
  condition consequences and first-launch practice. Reuse existing widgets and Resources. New art
  begins with the Fen Patrol cast and a shared Briarfen stage; it does not authorize new encounters.
- **Knowledge:** legality, targets, status threats, condition rules and channel interruptibility are
  always readable. Named enemy moves and exact incoming detail require UNDERSTOOD/Inspect;
  affinities require STUDIED or a revealing hit. Unknown affinity cannot leak through outgoing
  estimates, Focus bonuses, break/kill labels or formulas. See M1.1 F1 for display fallback.
- **Reactions:** binary success/failure. A successful Parry is the familiar/passive trigger; there
  is no separate “Perfect Parry.” First allowed input locks; disallowed keys are inert. AoE uses one
  window. Successful Evade/Parry keep zero incoming hit damage; environment effects may still apply.
- **Slice conditions:** Spore Fog reuses Burn: first actual Burn application each round causes
  8 Fire damage to every other unit on that target's side, once globally per round. No Blight or
  positional targeting system. Flooded Ground retains Evade → Wet, IMPACT splash, nonrecursive Shock
  spread among Wet allies and shorter Burn. All rules must be visible.
- **Balance:** retain loaded M1 numbers while presentation is repaired. Three to five normal rounds
  remains the target. Good simulation win rates do not prove fun, tactics, comprehension or pacing.
  Do not add forced chip damage, enemy HP inflation, hidden feints, or attacks solely to counter skill.
- **World pressure:** expedition persistence remains a later explicit specification; do not assume
  HP, potion charges and Focus all carry together. Normal fights must teach/test a choice even without
  attrition. AFFECT THE WORLD is deferred, not passed by M1.
- **Implementation boundary:** this Director pass supplies design, art candidates, declarative frame
  Resources and acceptance tests. It does not implement production GDScript. Art is staged and the
  HTML study is illustrative; neither is a claim that the running UI has already been replaced.

### Milestone acceptance

M1.1 requires the specification's functional regressions and fresh-player READ/REACT rubric, including
four enemies, keyboard/controller, enlarged text, no sound and reduced effects. Headless tests cannot
pass human comprehension or artistic quality. Full prototype/world acceptance criteria below remain
long-term gates, not a declaration of current completion.

## Original design brief and research rationale

## Design thesis and research synthesis

Your original idea has a strong center: **a pixel-art RPG where turn-based strategy is made physically engaging through skill-based action inputs, while exploration, enemy knowledge, equipment experimentation, corruption events, and a morally ambiguous world continuously feed back into combat**.

The biggest problem is not the idea; it is scope. As written, the concept simultaneously asks for a seamless open world, sophisticated enemy AI, multiple biomes, dynamic world events, procedural quests, crafting, alchemy, equipment sets, pets, NPCs, towns, minigames, home-base simulation, factional narrative, bestiary progression, skill-based turn combat, and large quantities of bespoke content. An indie project can contain many of those ideas, but attempting to implement each as an independent subsystem is a classic route to an unfinished game.

The solution is to make **a relatively small number of systemic components generate the appearance of much greater complexity**.

The design direction I recommend is:

> **A compact open-zone pixel RPG built around fast, reactive turn-based battles in which player knowledge, action-command mastery, equipment interactions, enemy telegraphs, and environmental rules matter considerably more than grinding stats. Each excursion changes the state of the world, creating a repeating loop of exploration → encounter → mastery → salvage → world consequence → build experimentation → exploration.**

I would call the working concept **Hollow Choir**.

### What current and proven designs suggest

Several existing games validate pieces of the concept, but the important lesson is to recombine their principles rather than imitate their content.

| Reference | Relevant lesson for Hollow Choir |
|---|---|
| **Clair Obscur: Expedition 33** | Its combat explicitly mixes a turn-based structure with real-time dodges, parries, counters, attack rhythms, buildcrafting, and weak-point targeting. This is the clearest recent proof that turn-based decision-making and execution skill can coexist successfully. citeturn11search11 |
| **Bug Fables** | Uses action commands to enhance attacks and blocks while keeping conventional turn-based decision-making intact; it also combines overworld abilities, puzzles, cooking, and turn-based encounters without requiring huge mechanical complexity. citeturn2search6 |
| **Into the Breach** | Telegraphs enemy attacks before resolution, turning combat into an information-rich tactical puzzle rather than surprise damage. This is an excellent model for making intelligent enemies difficult without making them feel unfair. citeturn5search2 |
| **Sea of Stars** | Demonstrates how timed attacks/defenses and enemy interruption mechanics can add interaction to classic RPG combat. Its Steam page and player feedback also illustrate a design danger: interruption puzzles become frustrating when the required solution is occasionally impossible because the correct actor or attack type is unavailable. citeturn2search13 |
| **Chained Echoes** | Explicitly pursued fast-paced turn-based encounters without random battles and integrated exploration directly with its RPG systems. That points toward keeping normal battles short rather than treating every encounter as an endurance test. citeturn12search3turn12search6 |
| **Hades** | Its permanent progression, repeated mastery, escalating challenge, and return-to-hub narrative demonstrate how a home base can make repeated excursions feel meaningful rather than merely resetting the player. citeturn5search0turn5search3 |
| **Wildermyth** | Shows the value of recombining authored components: it generates heroes, enemies, maps, and story events from reusable structures rather than relying solely on linear handcrafted content. citeturn5search1 |
| **Moonlighter** | Integrates adventuring, collected resources, town development, equipment, companions, and an economic/home loop so that what happens outside combat feeds directly into the next excursion. citeturn5search9 |

The most important contemporary reference is *Expedition 33*: its official description explicitly frames dodging, parrying, countering, rhythmic attacks, free-aim weak-point targeting, skills, gear, and character synergies as extensions of turn-based combat rather than replacements for it. citeturn11search11 Your game should pursue the **same philosophical combination while implementing it far more cheaply in 2D**.

The other especially valuable reference is *Into the Breach*. Difficulty works well when enemies are dangerous **because the player understands what they intend to do and must solve the situation**, rather than because the AI secretly receives bonuses or the game hides information. Its core design openly telegraphs enemy attacks and asks the player to find the counter. citeturn5search2 That principle should become foundational to Hollow Choir.

### Replace “addictive” with ethical compulsion through mastery

I would deliberately avoid designing around psychological compulsion, artificial scarcity, real-world timers, streak maintenance, or other dark-pattern retention techniques. A much better target is a **“one more expedition / one more build experiment” loop** built through competence, autonomy, discovery, and meaningful progression.

Self-Determination Theory is commonly applied to games through the needs for **competence, autonomy, and relatedness**; games research has repeatedly examined those concepts as useful ways to understand player motivation. citeturn4search0turn4search12turn4search16

For Hollow Choir:

**Competence** comes from learning enemy telegraphs, mastering reaction timing, discovering build synergies, and eventually defeating dangerous enemies using supposedly weak equipment.

**Autonomy** comes from choosing routes, equipment, companions, potions, corruption responses, quest priorities, and whether to support, exploit, or oppose competing factions.

**Relatedness** comes from companion stories, the changing settlement, rescued NPCs, pets, recurring merchants, and visible consequences to communities.

That gives you long-term engagement without manufacturing frustration.

### Your timing mechanic needs an accessibility split

There is one major design correction I strongly recommend.

Do **not** make execution difficulty inseparable from strategic difficulty.

Accessibility guidance specifically recommends alternatives where precise timing would otherwise be essential and recommends allowing players to alter difficulty during play. Microsoft’s Xbox accessibility guidance likewise points developers toward adjustable game difficulty. citeturn13search0turn13search2turn13search22

Therefore Hollow Choir should have two independent controls:

**Tactical Difficulty**
- Story
- Adventurer
- Tactician

**Execution Assist**
- Generous
- Standard
- Precise
- Assisted

A player can therefore fight highly intelligent enemies while using generous action-command timing, or fight simpler enemies while demanding precision from themselves.

That is a much stronger design than equating fast reflexes with “hard mode.”

## Refined game concept

**Working title:** **Hollow Choir**

**Genre:** 2D top-down reactive turn-based RPG.

**Presentation:** Pixel art, approximately 32×32 environmental tiles with larger character and enemy sprites where needed.

**Campaign target:** roughly an 8–12 hour focused main campaign with substantially more optional discovery rather than an enormous 40-hour RPG.

**Party model:** one protagonist + one active companion + one pet/familiar. Additional companions are recruited, but only one accompanies the hero at once. This drastically reduces combat-animation, balance, UI, and writing complexity while preserving party-building.

**World model:** interconnected **open zones**, not one enormous seamless open world.

**Design pillars:**

> **Read. React. Adapt. Experiment. Affect the world.**

The player should repeatedly think:

> “I understand this monster better now.”

> “I could beat that encounter with different gear.”

> “I almost nailed that parry.”

> “That item changes how my build works.”

> “I wonder what happened to that region while I was away.”

### Narrative premise

Centuries ago, humanity survived an event called **The First Bloom**, when the earth began producing impossible organisms, memories, landscapes, and creatures.

The celestial beings known collectively as **the Choir** arrived and taught humanity how to “purify” corrupted land.

Human civilization consequently portrays the conflict simply:

**Choir = order and salvation.**

**Bloom = corruption and evil.**

The truth becomes progressively less comfortable.

The Bloom is not an invading force. It is part of the world's ancient biological and metaphysical repair mechanism. It endlessly mutates anything that becomes too static.

The Choir is not benevolent either. It represents absolute preservation. Its ideal universe contains no disease, suffering, mutation, uncertainty—or meaningful change.

The Bloom would eventually dissolve civilization into uncontrolled possibility.

The Choir would eventually preserve civilization so perfectly that nothing could meaningfully live.

Both factions regard humanity primarily as a useful substrate.

Your protagonist survives contact with both forces and becomes a **Hollow**, capable of carrying incompatible resonance without dying.

The central narrative question therefore evolves from:

> “How do I cleanse the corruption?”

into:

> “Who taught us to call one form of annihilation holy?”

and ultimately:

> “Can a world survive without either perfect order or unlimited change?”

The player can gradually pursue three philosophies:

**Purity:** empower the Choir.

**Bloom:** embrace transformation.

**Concord:** force both systems into unstable coexistence.

None should be a cartoon “good ending.”

### The core game loop

The complete play loop should fit naturally into approximately ten-to-fifteen-minute chunks:

**Prepare → Explore → Discover → Fight → Salvage → Choose → Upgrade → Return**

At the home settlement, the player chooses a weapon configuration, active companion, familiar, potions, and destination.

They enter an open zone.

Within several minutes they encounter some combination of enemies, environmental puzzles, NPC events, resources, secrets, shortcuts, minibosses, or corruption phenomena.

Combat produces materials, bestiary knowledge, mastery, equipment opportunities, and changes to regional pressure.

The player chooses whether to continue deeper or return.

Back at home, resources become **new options** rather than merely larger statistics: alternate weapon actions, additional potion interactions, companion abilities, traversal tools, familiar behaviors, or settlement capabilities.

That new option inspires another expedition.

### The crucial progression principle

The player should get better in three different ways:

**The character becomes broader.**

**The build becomes more synergistic.**

**The player becomes more skilled.**

Only the first should be conventional RPG progression.

A talented player using starter equipment should eventually be capable of defeating late-game enemies.

That single principle aligns almost every subsystem.

## Systems specification

The following is the design I would actually build.

### Reactive turn-based combat

Combat takes place on a dedicated battle screen.

The screen displays:

**Upper area:** enemies, environmental objects, visible intentions.

**Left or top edge:** initiative timeline.

**Bottom-left:** protagonist and companion status.

**Bottom-center:** actions.

**Bottom-right:** familiar, consumables, battlefield information.

Mouse-hovering or holding an information key opens increasingly detailed numbers and formulas.

Normal encounters should generally last **three to five rounds**.

Trash fights should not exist solely to consume resources.

Every encounter should teach, test, reveal, reward, or complicate something.

### Player actions

Each controlled character normally receives **one major action per activation**.

Possible categories:

**Attack**

**Technique**

**Magic**

**Guard/Stance**

**Item**

**Inspect**

This keeps the decision tree understandable.

More complexity comes from interactions rather than a giant command list.

### Focus resource

Successful tactical and execution decisions build **Focus**.

Focus is generated by:

- exploiting weaknesses;
- perfect action commands;
- interrupting dangerous skills;
- parrying;
- triggering environmental interactions;
- completing familiar conditions.

Focus powers stronger techniques.

That creates a positive mastery loop without making mistakes immediately fatal.

### Action commands

Do not develop twenty bespoke minigames.

Create **three reusable action-command components** and parameterize them.

**Timing Strike**

A moving indicator enters one or more success zones.

Used for swords, axes, simple spells.

**Hold / Release**

Hold the button while a gauge moves; release within a target region.

Used for bows, hammers, charged magic.

**Rhythm Sequence**

Two to four clearly telegraphed beats.

Used for daggers, musical/ritual abilities, multihit attacks.

A later optional fourth component can use mouse targeting:

**Weak-Point Aim**

The player targets an exposed enemy area.

Only elite monsters and bosses require it.

This is enough variation to make weapons feel mechanically distinct without creating an implementation nightmare.

### Execution grades

Missing an input should never turn the selected tactical action into nothing.

A useful baseline:

| Result | Effect |
|---|---|
| Miss / no input | 85% base effect |
| Good | 100% effect |
| Perfect | 115% effect + small Focus reward |

That means **strategy determines whether the action was sensible; execution makes it excellent**.

The game remains an RPG rather than becoming a disguised rhythm game.

### Defensive reactions

Enemy attacks create a second layer.

The player may attempt one of three responses:

**Brace**

Large timing window.

Reduces damage approximately 35–45%.

Low risk.

**Evade**

Medium window.

Successful execution avoids most or all damage.

Failure increases vulnerability slightly.

**Parry**

Small window.

Cancels most damage and deals Stagger damage.

Failure is more punishing.

Some enemy moves cannot be parried. Others cannot be dodged normally. This is clearly marked.

That produces a genuine decision:

> “Do I take the safe block, or am I confident enough in this attack animation to parry?”

### Enemy telegraphs

Enemies should usually display intent before acting.

Examples:

**Sword icon → protagonist**  
direct attack.

**Broken shield → companion**  
armor break.

**Green cross → ally**  
healing.

**Spiral → battlefield**  
environmental manipulation.

**Hourglass 2 → large spell**  
two-action channel.

The bestiary progressively reveals more precision.

Initially:

> “Preparing a heavy strike.”

Later:

> “Heavy strike. Physical. 22–27 expected damage. Parries easily after the second flash.”

This turns knowledge into progression.

*Into the Breach* is particularly relevant here because its combat is explicitly structured around telegraphed enemy actions and solving the resulting tactical situation. citeturn5search2

### Enemy intelligence

Do not build machine-learning AI.

Implement **utility-scored actions**.

For every available enemy action:

```text
ActionScore =
BasePriority
× CurrentNeed
× TargetValue
× SynergyValue
× EnvironmentValue
× DifficultyAwareness
+ SmallRandomVariance
```

Example healer:

```text
Heal ally:
Base = 1.0

ally under 30% HP:
Need multiplier = 3.0

ally is group's damage dealer:
Synergy = 1.3

player applied healing reduction:
Effectiveness = 0.5
```

The AI compares legal actions and selects from the highest-valued candidates.

That produces intelligent-looking behavior cheaply.

### Tactical difficulty

Difficulty changes **decision quality**, not primarily numbers.

**Story**

Enemies assess themselves but barely coordinate.

More random variation.

Rarely focus-fire weakened characters.

Channel dangerous skills longer.

**Adventurer**

Enemies consider their HP, allies, player vulnerabilities, statuses, cooldowns, and environment.

Moderate coordination.

**Tactician**

Enemies consider combo sequencing and approximately one activation of lookahead.

Healers protect dangerous allies.

Tanks cover exposed casters.

Controllers create conditions for damage dealers.

Enemies interrupt obvious player setups.

Crucially:

**Tactician does not read hidden player inputs.**

**Tactician does not receive arbitrary double-health bars.**

**Tactician does not conceal combat rules.**

The intelligence gets better.

### Enemy roles

Keep six reusable archetypes.

| Role | Purpose |
|---|---|
| Bulwark | Guards allies, redirects attacks, disrupts focus fire |
| Ravager | High immediate damage |
| Mendicant | Healing, cleansing, protection |
| Hexer | Status and battlefield manipulation |
| Stalker | Exploits weakened targets |
| Conductor | Improves enemy combinations and enables special interactions |

Enemy identity comes from combining **role + species mechanic + biome rule**.

A Briarfen Bulwark and Basilica Bulwark use the same AI framework but play very differently.

### Stagger

Enemies possess a visible **Stagger meter**.

Specific actions damage it.

Interrupts, weaknesses, parries, and certain weapon techniques accelerate it.

At zero:

- current channel is interrupted;
- enemy loses or delays an activation;
- armor temporarily weakens;
- weak point may become exposed.

Bosses should frequently be easier to defeat through understanding Stagger behavior rather than simply maximizing damage.

### Stats

Keep the stat list small.

**Heart**  
maximum HP.

**Force**  
attack potency.

**Guard**  
damage mitigation.

**Tempo**  
initiative.

**Focus**  
special-resource capacity/generation modifiers.

Optional derived values can exist but should not overwhelm the player.

A transparent mitigation formula could be:

```text
Final Damage =
Raw Damage × (100 / (100 + Guard))
```

Hovering the damage preview should show:

```text
Sword Arc
Base damage: 24
Force modifier: +4.8
Enemy vulnerability: ×1.25
Estimated result: 29–31
Perfect timing: 34–36
```

That directly fulfills your requirement for transparent statistics.

### Status effects

Resist the temptation to create twenty.

Use six highly interactive statuses.

**Burn**

Damage when acting.

Removed/reduced by Wet.

**Wet**

Enables stronger Shock interactions.

Suppresses Burn.

**Shock**

Bonus Stagger; can jump to Wet enemies.

**Chill**

Slows Tempo.

Repeated Chill can Freeze.

**Bleed**

Triggers damage when the target uses strenuous actions.

**Blight**

Corruption status with context-dependent interactions.

Every biome primarily emphasizes two or three.

### Battlefield conditions

Only one major and optionally one minor environment rule should normally be active.

Examples:

**Flooded Ground**

Wet is applied more easily.

Shock chains.

**Scorching Air**

Burn lasts longer.

Ice effects weaken.

**Choir Resonance**

Healing is stronger, but repeated healing causes Exposure.

**Spore Fog**

Slice rule (M1.1): the first actual Burn applied each round ignites the spores, dealing 8 Fire
damage to every other unit on that target's side. One shared trigger per round. Blight accumulation
is a deferred world/corruption idea, not an implemented or approved slice requirement.

**Unstable Ley**

Magic generates extra Focus but occasionally produces backlash.

The condition is always visible.

The player should never wonder why a mechanic changed.

### Weapons

Use approximately **six weapon families** in the eventual full game.

A vertical slice only needs three.

Potential families:

**Sword**

Balanced.

Timing Strike.

Parry-oriented.

**Hammer**

Slow.

Hold/release.

High Stagger.

**Bow**

Hold/release.

Weak-point specialist.

**Daggers**

Rhythm sequence.

Status and Focus generation.

**Focus Staff**

Spell conversion and battlefield interaction.

**Chainblade**

Multi-target and positional/status mechanics.

Weapon family defines the action-command language.

Individual weapons then modify that language.

Examples:

> *Pilgrim's Edge*  
> Perfect sword timing converts 20% Stagger damage into Focus.

> *Rustwake Blade*  
> Good timing applies Bleed; Perfect timing extends existing Bleed instead.

> *Merciful Iron*  
> Much larger timing window, lower maximum damage, Parry restores Heart.

All three could remain viable for the entire game.

### Rarity

Rarity should mean **mechanical complexity**, not “strictly better sword.”

**Common**

One identity property.

Cheap upgrades.

Usually forgiving action command.

**Uncommon**

Identity + one modification socket.

**Rare**

Two sockets or an alternate action.

**Relic**

Unique rules-changing behavior.

Raw base-power difference between comparable weapons should remain relatively small.

A mastered Common weapon can eventually receive additional modification capacity.

Therefore discovering a Relic produces:

> “What build could I make with this?”

rather than:

> “My old weapon is garbage now.”

### Equipment upgrades

Upgrades unlock behaviors.

Examples:

**Sharpened Timing**

Perfect zone shrinks slightly but bonus increases.

**Balanced Grip**

Good zone becomes wider.

**Echo Edge**

Perfect strike repeats 25% damage against a Marked target.

**Hollow Channel**

Spend Focus to convert physical damage into Blight.

**Counterweight**

Successful Brace increases next Hammer charge speed.

Equipment progression therefore becomes experimentation.

### Armor

Use three slots only:

**Garb**

**Charm**

**Relic**

Avoid six pieces of armor generating endless inventory garbage.

Armor mostly supplies rules such as:

> Brace generates Focus.

> Wet no longer reduces Burn damage dealt by you.

> Familiar triggers can occur twice before cooldown.

> Healing an ally gives both characters temporary Guard.

### Set bonuses

Do not make conventional five-piece armor sets.

Use **Resonance Tags**.

Example:

```text
Storm
Bloom
Choir
Hunter
Hollow
Ember
```

Having two matching tags activates a modest interaction.

No benefit requires more than two items.

This prevents equipment builds from becoming predetermined.

### Companions

Recruit approximately four major companions in the full game.

Only one active companion joins the protagonist.

Each companion has:

- one basic action;
- two techniques;
- one passive identity;
- one relationship upgrade tree;
- one personal quest arc.

Example:

**Mara — former Choir Inquisitor**

Basic: Spear thrust.

Technique: Intercept an incoming attack.

Technique: Condemn an enemy action, increasing its Stagger vulnerability.

Passive: successful protagonist Parries grant Mara 2 Focus (binary reactions; no Perfect tier).

Her story questions whether morality exists when obedience has been engineered into an entire civilization.

### Familiars

Familiars do not require full turns.

They respond to triggers.

Examples:

**Mossling**

After potion use, restore minor Heart.

**Bell Crow**

After a successful party Parry, deal 12 Stagger to the attacker, once per round.

**Cinder Pup**

When Burn is applied, extend it once per round.

**Glass Moth**

First exposed weak point each battle grants Focus.

This keeps pets interesting while requiring very little additional interface complexity.

### Potions and alchemy

Avoid a giant recipe book.

Potions use:

**Base + Reagent + optional Catalyst**

Example:

```text
Healing Base
+ Emberleaf
= restorative tonic

Healing Base
+ Emberleaf
+ Storm Salt
= heal + apply Shock immunity
```

Only two potion slots are available during battle initially.

Later upgrades increase flexibility rather than simply inventory volume.

Potion equipment can create builds:

> potion use counts as a Technique;

> excess healing becomes Guard;

> drinking a Blight potion empowers familiar;

> potion effects apply partly to companion.

### World structure

Do not create a seamless open world.

Create:

**One central settlement**

**Five open zones**

**Two smaller satellite settlements**

**Several compact interiors/dungeons per zone**

Each zone should contain loops, shortcuts, optional routes, dangerous early paths, hidden encounters, and landmarks.

Godot's current stable branch is 4.7.2, and its dedicated 2D tooling and `TileMapLayer` workflow are well suited to constructing reusable tile-based areas; Godot's documentation specifically notes that tilemaps allow large layouts to be painted rapidly and can incorporate collision and navigation information. citeturn9search0turn9search3turn9search6

Suggested zones:

**Gloamstead**

Home settlement.

**Briarfen**

Waterlogged forest consumed by fungal Bloom.

**Cinderstep**

Ashland built around a ruined celestial engine.

**Glassmere**

Frozen crystalline lake where memories appear physically.

**The Fallen Basilica**

Choir territory.

Beautiful, orderly, deeply unsettling.

**Rootdeep**

Source region of the First Bloom.

### Skill-based sequence breaking

Regions have an intended progression but not hard level requirements.

A dangerous route might be blocked by:

- a guardian enemy;
- harsh environmental condition;
- traversal hazard;
- puzzle requiring an optional tool.

A skilled player can sometimes overcome the guardian early.

That produces meaningful mastery.

Do not place invisible walls saying:

> “Requires Level 20.”

### Corruption pressure

Each region has:

```text
Pressure 0
Pressure 1
Pressure 2
Pressure 3
```

Pressure advances through player activity, **not real-world time**.

For example, after several meaningful expeditions while a regional crisis remains ignored.

At Pressure 1:

visual foreshadowing.

At Pressure 2:

an event activates.

At Pressure 3:

a **Scar Event** changes the region.

Possible consequences:

- merchant temporarily relocates;
- specific enemy mutates;
- a resource changes;
- route becomes hazardous;
- miniboss appears;
- NPC relationship changes;
- faction gains influence.

Important rule:

> Consequences should change content, not delete it.

The player should think:

> “The world responded to me.”

not:

> “I missed content because I wasn't following a checklist.”

### Corruption decisions

Major events present three common responses.

**Cleanse**

Reduces Bloom.

Increases Choir influence.

**Cultivate**

Allows controlled corruption.

Creates unusual resources and mutations.

**Stabilize**

More difficult.

Attempts coexistence.

These choices simultaneously affect:

- regional mechanics;
- faction standing;
- quests;
- visuals;
- loot tables;
- ending conditions.

One system therefore powers gameplay and narrative.

### Quests

Use three categories.

**Main quests**

Fully authored.

**Companion stories**

Fully authored.

**Rumors**

Template-based.

A Rumor template contains:

```text
Trigger
NPC/Location
Objective type
Enemy/resource target
Complication
Reward category
World-state consequence
Dialogue shell
```

Possible objective families:

- Hunt
- Investigate
- Rescue
- Escort
- Recover
- Contain corruption
- Choose between NPC interests

Do not procedurally generate important dialogue using an LLM at runtime.

Author reusable structures instead.

Wildermyth is a useful design reference because it gets substantial variety from procedural combinations of heroes, enemies, story events, and maps rather than treating every piece of replayability as bespoke content. citeturn5search1

### Puzzles

Build only three reusable puzzle grammars:

**Resonance Mirrors**

Rotate beams/sound/light.

**Bloom Routing**

Grow or suppress organic paths.

**Pressure / Rune mechanisms**

Interact with switches in a spatial sequence.

Biome variations change appearance and parameters.

This produces dozens of apparent puzzles from a small technical vocabulary.

### Bestiary

The bestiary becomes part of progression.

Instead of simply:

> Kill 10 monsters to reveal information.

Award **Research** from different behaviors:

- encounter enemy;
- inspect;
- defeat;
- exploit weakness;
- parry signature attack;
- observe rare ability;
- discover lore;
- complete related quest.

Research tiers might unlock:

**Observed**

Description + habitat.

**Studied**

Basic resistances and drops.

**Understood**

Moveset and telegraphs.

**Mastered**

AI tendencies, exact ranges, rare resources, hidden interactions.

Knowledge is therefore earned through understanding rather than grinding.

### Home base

The base should have approximately five functional stations.

**Forge**

Weapon modification.

**Stillroom**

Alchemy.

**Menagerie**

Familiars.

**Observatory**

Bestiary, map research, corruption tracking.

**Caravan Board**

Trade and resource acquisition.

Upgrades unlock choices.

Avoid passive real-time mobile-game income.

Instead, the Caravan produces one selected resource outcome **after an expedition**, tying the economy to actual play.

### Interface philosophy

Every screen should have two informational levels.

**Immediate layer**

Simple and readable.

**Analysis layer**

Detailed formulas.

Example item tooltip:

```text
RUSTWAKE

Sword
Power 24
Timing: Forgiving

Trait:
Good attacks apply Bleed.

[Hold ALT for details]
```

Detailed:

```text
Base damage: 24
Timing zones:
Good: 420 ms
Perfect: 115 ms

Bleed:
2 damage × 3 strenuous actions

Current build interactions:
Bell Crow: no interaction
Hunter Resonance: +1 Bleed duration
```

That is the correct answer to your “simple but fully transparent” UI requirement.

## Master development prompt

The following is the prompt I would actually use as the shared project specification for Claude or another coding agent.

```text
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

Successful Parry creates Focus (binary reaction; no separate Perfect grade).

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
```

## Music and audio prompt pack

The soundtrack should reinforce the core narrative dichotomy:

**Choir music = mathematically beautiful, controlled, clean, increasingly suffocating.**

**Bloom music = organic, unstable, asymmetrical, initially frightening but increasingly alive.**

**Human music = imperfect combination of both.**

Do not simply make “angels = choir” and “corruption = horror drones.” That would undermine the moral ambiguity.

For implementation, an adaptive system can remain simple. Modern middleware such as FMOD allows game code to drive music behavior using continuous, discrete, or labeled parameters, while Wwise supports music states, transitions, stingers, and changes aligned to musical boundaries such as beats and bars. citeturn7search19turn7search7turn7search12

You do not actually need either middleware for the first prototype. Three synchronized stems controlled by the game state are sufficient.

Use:

```text
MusicIntensity = 0–1
CorruptionLevel = 0–1
ChoirInfluence = 0–1
CombatState = exploration / tension / battle / victory
```

A track can contain:

**Stem A:** harmony / atmosphere.

**Stem B:** rhythmic pulse.

**Stem C:** danger / percussion / dissonance.

The engine changes their volume rather than restarting songs.

### Main theme — “A Bell Beneath the Soil”

**Purpose:** title screen and recurring melodic identity.

**Prompt:**

```text
Compose an original instrumental dark-fantasy RPG main theme for a pixel-art world caught between divine preservation and organic corruption.

Mood:
melancholic wonder, ancient mystery, restrained hope, moral ambiguity.

Begin intimately with felt piano or delicate plucked strings introducing a simple 5–7 note leitmotif.

Gradually introduce:
low cello,
soft frame drum,
glass harmonics,
distant human vowel choir,
subtle wooden percussion,
faint detuned bells,
organic rustling textures.

The choir must initially sound beautiful rather than sinister.

As the piece develops, introduce small harmonic disagreements between the perfectly tuned choir and slightly unstable acoustic instruments.

The final section should briefly reconcile both musical worlds without completely resolving the harmony.

Tempo:
approximately 72–82 BPM.

Meter:
primarily 4/4 with occasional subtle 3/4 or 6/8 displacement.

Length:
2–3 minutes.

Must loop or resolve naturally.

No vocals with lyrics.
No bombastic Hollywood trailer percussion.
No imitation of an existing composer or game soundtrack.
Memorable but economical melody.
```

### Home theme — “Gloamstead at Dusk”

```text
Create a warm but slightly melancholy looping settlement theme for a small pixel-art RPG village recovering from supernatural catastrophe.

Instrumentation:
nylon-string guitar or lute,
soft piano,
clarinet or wooden flute,
light hand percussion,
upright bass,
very subtle distant bells.

Mood:
safe, human, imperfect, communal.

The music should feel like ordinary people making a life in the shadow of something enormous.

Include a quiet variation of the game's central 5–7 note leitmotif.

Around the midpoint, introduce a slightly unstable chord that hints that the town's apparent safety is temporary.

Tempo:
80–95 BPM.

Loop length:
90–150 seconds.

Avoid:
overly cheerful tavern clichés,
epic orchestra,
busy percussion.
```

### Exploration theme — “Road Through Briar”

```text
Create an adaptive exploration track for a flooded fungal forest in a dark pixel-art fantasy RPG.

The forest is dangerous but beautiful rather than conventionally evil.

Instrumentation:
muted marimba,
hand percussion,
wooden clicks,
breathy flute,
low cello pizzicato,
processed water droplets,
soft synth texture,
occasional distant vocal tones.

Tempo:
95–105 BPM.

Create three compatible synchronized layers:

STEM A:
ambient harmony and melody.

STEM B:
gentle rhythmic pulse for active exploration.

STEM C:
low percussion, dissonant cello, and organic texture for nearby danger.

All stems must share the same tempo, meter, length, and harmonic structure so they can be mixed dynamically.

Loop:
approximately 90 seconds.

The theme should communicate curiosity first and danger second.
```

### Standard battle — “Measured Violence”

```text
Compose an original turn-based RPG battle theme designed for frequent encounters.

The music must create urgency without becoming exhausting after repeated listening.

Style:
hybrid acoustic fantasy rhythm with restrained electronic pulse.

Instrumentation:
tight frame drums,
low toms,
plucked strings,
aggressive cello ostinato,
short brass accents,
processed bell percussion,
subtle synth bass.

Tempo:
125–140 BPM.

Use a clear rhythmic pulse that helps players subconsciously read timed action commands without turning the track into a rhythm-game metronome.

Structure:
short 4–8 bar introduction,
loopable central combat body,
optional victory transition.

Avoid:
constant maximum intensity,
huge trailer drums,
long melodic passages that become repetitive.

Provide stems:

HARMONY
RHYTHM
DANGER

The danger layer should add syncopated percussion and harmonic tension without changing tempo.
```

### Choir faction — “Perfect Mercy”

```text
Compose sacred music for seemingly benevolent celestial beings whose concept of salvation is absolute preservation.

At first listen:
serene,
beautiful,
transcendent,
ordered.

Instrumentation:
small chamber choir singing wordless vowels,
glass harmonica,
organ,
bowed vibraphone,
soft strings,
precise bell tones.

Harmony should begin extremely consonant.

Gradually make the music unnerving through excessive repetition, mathematical symmetry, and notes that refuse to resolve.

The listener should eventually feel that the music is too perfect.

Tempo:
slow, approximately 60–75 BPM.

Avoid obvious horror devices.

Do not use demonic effects.

The discomfort must arise from perfection rather than ugliness.
```

### Bloom theme — “Everything Wants to Become”

```text
Compose music representing a supernatural force of uncontrolled biological and metaphysical change.

The Bloom is frightening but not evil.

The track should feel alive.

Instrumentation:
bowed strings,
wood percussion,
breathing textures,
granular plant-like noises,
detuned dulcimer,
low hand drums,
irregular plucked patterns.

Use asymmetrical phrasing but maintain enough rhythmic coherence for gameplay.

Begin alien and threatening.

Gradually reveal warmth and vitality beneath the instability.

Avoid generic horror drones.

Tempo:
approximately 90–110 BPM.

Use occasional 5/4 or 7/8 phrases inside a larger understandable structure.

Produce exploration and danger stems that can be crossfaded.
```

### Boss theme — “Scarbreaker”

```text
Compose a high-intensity boss battle theme for a reactive turn-based RPG.

The fight should feel like a duel of understanding rather than a chaotic action scene.

Tempo:
145–155 BPM.

Instrumentation:
aggressive strings,
low brass used sparingly,
frame drums,
metallic percussion,
distorted bell,
wordless vocal pulses,
sub-bass.

Create clearly identifiable rhythmic phrases that support learning enemy attack patterns.

Include short moments of reduced instrumentation before major musical impacts.

The music should reinforce:
anticipation,
recognition,
execution,
release.

Three phases:

PHASE A:
threat and observation.

PHASE B:
stronger rhythmic complexity and dissonance.

PHASE C:
combine the human, Choir, and Bloom musical languages.

Must transition cleanly at bar boundaries.
```

### Final theme — “Neither Heaven Nor Rot”

```text
Compose a final confrontation theme that combines the musical identities of humanity, the Choir, and the Bloom.

Humanity:
warm imperfect acoustic instruments and the main leitmotif.

Choir:
precise voices, organ, bells, symmetry.

Bloom:
organic percussion, microtonal instability, uneven phrasing.

Rather than alternating between them, gradually force all three musical languages to coexist.

The first half should sound almost impossible to reconcile.

The final section should find a fragile common pulse without giving the listener a perfectly resolved major-key victory.

Mood:
defiance,
grief,
wonder,
uncertain hope.

Tempo:
approximately 120–135 BPM.

Length:
3–5 minutes with defined transition points for multiple combat phases.

Original instrumental composition.
Wordless vocals only.
No imitation of an existing soundtrack.
```

### Sound-design prompt

```text
Design a cohesive retro-modern sound palette for a 2D pixel RPG.

Avoid simplistic 8-bit-only sound effects.

Combine short synthesized transients with organic recordings.

Every combat action must communicate:

ANTICIPATION
IMPACT
RESULT

Examples:

Parry:
short rising metallic anticipation cue,
sharp glass-metal impact,
distinct resonant confirmation tone.

Perfect attack:
brief transient stronger than normal hit,
high-frequency sparkle,
very short tonal confirmation.

Stagger break:
deep low-frequency crack,
layered ceramic/glass break,
short silence,
heavy impact tail.

Choir magic:
clean bells,
reversed breath,
perfect harmonic interval,
precise attack.

Bloom magic:
wood,
wet organic movement,
detuned string,
granular flutter.

UI:
soft tactile clicks using wood, glass, and muted bells.

Avoid excessively loud reward sounds.
Avoid casino-like ascending reward jingles.
```

## Production scope and implementation architecture

The most important production decision is to treat the first version as **a combat game with an RPG wrapped around it**, not as an RPG whose combat is merely one subsystem.

Until combat is compelling, the open world, thirty quests, potion collection, dialogue, and crafting systems are liabilities.

### The vertical slice

Build this and nothing larger at first:

| Category | Slice |
|---|---|
| Settlement | Gloamstead |
| World | One Briarfen zone |
| Weapons | Sword, Hammer, Bow |
| Companion | One |
| Familiars | Two |
| Basic enemies | Six |
| Elite | One |
| Boss | One |
| Statuses | Burn, Wet, Shock, Bleed |
| Environments | Flooded Ground, Spore Fog |
| Potions | Six recipes maximum |
| Major quest | One |
| Companion quest | One |
| Rumor templates | Three |
| Corruption | One event chain |
| Stations | Forge, Stillroom, Observatory |
| Puzzle families | Two |
| Bestiary | Full basic implementation |

The slice should demonstrate the complete game loop:

```text
home
→ choose build
→ enter biome
→ explore
→ find secret/puzzle
→ encounter enemy
→ reactive battle
→ loot/research
→ corruption choice
→ boss
→ return home
→ unlock genuinely different build option
→ want to leave again
```

Only after that loop is demonstrably enjoyable should the remaining biomes exist.

### Why Godot is a sensible default

As of October 2026, Godot's public site identifies **4.7.2** as the latest stable release. Its dedicated 2D stack includes tilemaps, sprite animation, 2D lighting, particles, physics, shaders, and GUI tooling. citeturn9search0turn9search6

For this particular design, two parts are especially useful.

`TileMapLayer` is optimized for large numbers of tiles, supports reusable TileSets, collisions, navigation-related information, terrain painting, patterns, and randomized/scattered tile placement. That substantially lowers the labor of building several top-down biomes. citeturn9search3

Godot's `Resource` system is designed around reusable data containers, making it well suited to definitions such as enemies, abilities, weapons, familiar behaviors, biome rules, and quests instead of hardcoding all of those into gameplay nodes. citeturn8search1

I would therefore structure the game around **data-driven definitions + relatively generic execution systems**.

For example:

```text
WeaponDefinition
    id
    display_name
    family
    base_power
    action_command_type
    action_command_parameters
    tags[]
    passive_effects[]
    mastery_unlocks[]

EnemyDefinition
    id
    role
    hp
    guard
    tempo
    stagger
    weaknesses[]
    resistances[]
    actions[]
    biome_tags[]
    research_entries[]

EnemyActionDefinition
    id
    target_rule
    base_priority
    damage
    statuses[]
    utility_conditions[]
    can_brace
    can_evade
    can_parry
    channel_time
    telegraph_data
```

Then adding an enemy is primarily **data + graphics + animation**, not new combat code.

### The anti-scope list matters as much as the feature list

The following features should be treated as explicit exclusions until the game is already excellent:

No seamless procedural world.

No four-character party.

No farming simulator.

No weapon durability.

No hunger or survival meters.

No equipment drops with +2.1% versus +2.4% statistics.

No dynamically generated LLM dialogue.

No giant crafting tree.

No 30 elemental damage types.

No real-time faction simulation.

No dozens of home-base buildings.

No day/night NPC scheduling.

No online systems.

No multiplayer.

No random encounters.

No real-world corruption timer.

No “daily rewards.”

No battle pass, streak system, or retention dark patterns.

No mechanic that exists merely to create grind.

### Acceptance criteria for the combat prototype

Before proceeding beyond the vertical slice, the prototype should satisfy these tests:

**Starter viability test**

A skilled tester can defeat the slice boss using the original sword.

**Information test**

After dying, the tester can explain what killed them.

**AI test**

A healer heals when healing is strategically justified, but does not mechanically heal whenever somebody takes one point of damage.

**Intent test**

Players understand dangerous enemy actions before resolution.

**Timing test**

Turning action commands to Assisted does not trivialize tactical decisions.

**Hard-mode test**

Tactician enemies appear smarter without dramatically inflated HP.

**Build test**

Sword, Hammer, and Bow produce meaningfully different battle decisions.

**Loot test**

A Rare weapon does not automatically replace every Common weapon.

**Environment test**

Flooded Ground causes the player to change at least one decision.

**Bestiary test**

Research information produces an actual tactical advantage.

**Corruption test**

Ignoring the regional event creates interesting changed content rather than merely taking something away.

**Return-loop test**

Coming back to Gloamstead regularly gives the player a genuinely interesting reason to alter their next expedition.

### The most important balance metric

Do not primarily measure:

> DPS.

Measure:

> **decision diversity**.

For every weapon or ability, ask:

> In what situation is this the best choice?

> In what situation is it the wrong choice?

> What other mechanic does it encourage me to use?

A good item has three answers.

A bad item says:

> “It deals 12% more damage.”

## ChatGPT and Claude collaboration roadmap

The strongest division of labor is not “both AIs write random parts of the game.”

It should resemble a small studio with **clear ownership, review, and handoff contracts**.

I recommend the following arrangement.

| Responsibility | ChatGPT | Claude |
|---|---|---|
| Creative/game direction | **Owner** | Reviewer |
| System specifications | **Owner** | Implementation reviewer |
| Balance models | **Owner** | Simulation/tool implementation |
| Narrative architecture | **Owner** | Continuity reviewer |
| Quest/system templates | **Owner** | Data implementation |
| UX specifications | **Owner** | UI implementation |
| Technical architecture | Reviewer | **Owner** |
| Godot scene architecture | Reviewer | **Owner** |
| GDScript implementation | QA/specification | **Owner** |
| Refactoring | Reviewer | **Owner** |
| Automated tests | Acceptance criteria | **Owner** |
| Combat simulation | Analysis | **Tool implementation** |
| Bug reproduction | Diagnosis/spec | **Code fix** |
| Content audit | **Owner** | Consistency pass |
| Scope control | **Owner** | Technical feasibility check |

### ChatGPT role prompt

Use this at the beginning of a design session with me:

```text
You are the Game Director and Systems Designer for Hollow Choir.

Your job is to protect:

fun,
clarity,
scope,
player agency,
mechanical depth,
systemic reuse,
balance,
narrative cohesion.

Do not write production code unless specifically requested.

For every proposed feature:

1. State its player-facing purpose.
2. State what decision it creates.
3. Identify systems it interacts with.
4. Identify implementation cost.
5. Identify likely exploits or failure cases.
6. Determine whether the existing systems can produce the same experience more cheaply.

Maintain the canonical Game Design Document.

When creating mechanics, provide:

DESIGN INTENT
PLAYER EXPERIENCE
RULES
UI REQUIREMENTS
DATA REQUIREMENTS
BALANCE PARAMETERS
EDGE CASES
ACCESSIBILITY REQUIREMENTS
ACCEPTANCE TESTS

When reviewing implemented mechanics, judge them against the project's design pillars:

READ
REACT
ADAPT
EXPERIMENT
AFFECT THE WORLD

Aggressively reject unnecessary scope.

Prefer one reusable system capable of producing ten encounters over ten bespoke encounter systems.

When handing work to Claude, output:

IMPLEMENTATION BRIEF
DATA CONTRACT
STATE FLOW
ACCEPTANCE TESTS
KNOWN EDGE CASES
NON-GOALS
```

### Claude role prompt

Use this for Claude:

```text
You are the Lead Gameplay Engineer and Technical Designer for Hollow Choir.

Engine:
Godot 4.7.x stable.

Language:
GDScript.

Your responsibilities:

technical architecture,
implementation,
data structures,
scene architecture,
tools,
test harnesses,
performance,
save compatibility,
refactoring,
debugging.

Treat the Game Design Document and ChatGPT implementation briefs as product requirements, but challenge any design whose implementation complexity is disproportionately high.

Before coding a feature:

1. Restate the requirements.
2. Identify reusable existing systems.
3. Propose architecture.
4. Identify data structures.
5. Identify edge cases.
6. Identify dependencies.
7. Confirm non-goals.

Prefer:

composition over deep inheritance,
data-driven Resources,
small reusable components,
signals/event buses where appropriate,
explicit state machines,
deterministic combat logic,
testable pure functions for calculations.

Avoid:

giant manager classes,
hardcoded item/enemy IDs,
duplicated combat code,
untyped Dictionaries where a defined structure is practical,
runtime magic strings,
systems coupled directly to UI,
saving arbitrary node state,
bespoke code for individual weapons unless absolutely necessary.

Every delivered feature should include:

FILES CREATED/MODIFIED
ARCHITECTURE SUMMARY
DATA CONTRACT
PUBLIC API
SAVE IMPACT
TEST PROCEDURE
KNOWN LIMITATIONS
FUTURE EXTENSION POINTS

Build tooling when it saves repeated manual work.

For combat systems, maintain a CombatSandbox scene.

For new content definitions, expose designer-editable Resources rather than requiring code changes.

Never silently expand scope beyond the implementation brief.
```

### The handoff format

Every major feature should move through the same loop:

```text
CHATGPT
↓
design specification

CLAUDE
↓
technical proposal

CHATGPT
↓
design / UX / exploit review

CLAUDE
↓
implementation

CHATGPT
↓
playtest rubric + balance review

CLAUDE
↓
bug fixes / refactor

BOTH
↓
canonical specification updated
```

Do not let either AI casually redefine existing mechanics.

Create a shared **Decision Log**.

Every irreversible design decision gets a record such as:

```text
DECISION:
Active party size limited to protagonist + one companion + familiar.

WHY:
Reduces animation, UI, AI, balance, and content complexity while preserving party synergy.

REJECTED:
Four-character party.

CONSEQUENCES:
Companion selection becomes strategically important.
Only one companion relationship contributes directly during combat.
Enemy group sizes can remain 1–4.
```

That prevents the project from gradually mutating because a coding assistant decided it would be “cool” to add another mechanic.

### Development roadmap

**Foundation**

Lock:

core design pillars;

world premise;

combat terminology;

main stats;

statuses;

three prototype weapons;

enemy roles;

coding conventions;

data contracts.

Claude creates the project skeleton, resource definitions, input abstraction, save foundation, battle state machine, and sandbox.

ChatGPT maintains the canonical specification and acceptance tests.

**Combat toy**

Ignore the overworld temporarily.

Implement:

one protagonist;

one dummy enemy;

initiative;

Attack;

Timing action command;

Brace;

Evade;

Parry;

Focus;

Stagger;

damage previews.

The goal is not content.

The goal is discovering whether pressing buttons inside this turn-based system feels satisfying.

**Combat ecosystem**

Add:

Sword;

Hammer;

Bow;

six enemies;

AI utility;

intent system;

statuses;

environment conditions;

companion;

familiars;

three difficulties;

execution assists.

At this point run automated combat simulations in which human execution is approximated as distributions of Miss/Good/Perfect outcomes.

ChatGPT should audit whether any choice becomes mathematically dominant.

**World slice**

Build Gloamstead and Briarfen.

Implement:

visible overworld enemies;

one shortcut loop;

resource gathering;

two puzzle frameworks;

one NPC event;

one secret;

battle transitions.

Do not add more zones.

**Progression slice**

Implement:

weapon mastery;

modification;

loot;

bestiarity research;

alchemy;

Forge;

Stillroom;

Observatory.

Test whether the player naturally forms plans such as:

> “Now that I found this Shock charm, I want to go back to Flooded Ground and try the Bow.”

That sentence is an important success metric.

**World-state slice**

Add Pressure.

Implement one full event chain:

```text
Pressure warning
→ event
→ ignored consequence
→ Scar Event
→ Cleanse / Cultivate / Stabilize resolution
→ changed biome state
```

This establishes the entire world-simulation vocabulary.

**Narrative slice**

Write one excellent companion arc and one moral choice.

Do not write the whole script.

Prove that the thematic conflict functions emotionally before generating hundreds of dialogue lines.

**Vertical-slice boss**

The boss should test every important system, but not simultaneously.

A strong structure:

```text
Phase A:
learn telegraphs.

Phase B:
environment changes.

Phase C:
player must deliberately Stagger a channel.

Phase D:
boss combines two previously learned attacks.

Final:
clear high-risk parry opportunity producing enormous advantage but not required.
```

A player who dies should think:

> “I know what I did wrong.”

Then immediately want another attempt.

**Content expansion**

Only once that experience works should you add:

remaining regions;

remaining companions;

additional weapon families;

additional familiars;

faction arcs;

more Scar Events;

final bosses.

Most new content should use established systems rather than creating new code.

**Polish**

Then address:

animation timing;

impact frames;

sound;

music layering;

controller support;

accessibility;

combat speed options;

save migration;

tutorial pacing;

UI clarity;

performance;

achievement design;

localization preparation.

### The final design north star

The project succeeds when a player can tell this story:

> “The first time I encountered that monster, it destroyed me.”

> “Then I learned what the animation meant.”

> “I discovered that Wet made its Shock attack more dangerous, changed my potion loadout, equipped an old Common sword because its wider parry window worked better for that enemy, brought the Crow because it rewards parries, and came back.”

> “The fight became easy—not because I ground ten levels, but because I understood the game.”

That is the identity worth protecting.

It combines the active turn-based philosophy demonstrated by modern games such as *Clair Obscur: Expedition 33*, the readable tactical information model exemplified by *Into the Breach*, action-command ideas seen in *Bug Fables* and *Sea of Stars*, compact encounter pacing associated with *Chained Echoes*, the repeated-return usefulness of hub progression seen in *Hades* and *Moonlighter*, and the value of recombining authored systemic content demonstrated by *Wildermyth*. citeturn11search11turn5search2turn2search6turn2search13turn12search3turn5search3turn5search9turn5search1

The important creative leap is that Hollow Choir should **not** try to be all of those games.

Its own hook should be simpler and clearer:

> **A turn-based RPG where understanding an enemy is more powerful than out-leveling it, and where every expedition teaches both the player and the world something new.**
