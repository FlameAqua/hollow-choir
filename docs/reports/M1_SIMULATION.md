# M1 Simulation Results

Generated from `tools/simulate.gd` runs at the end of M1 (SMART autopilot, Adventurer, STANDARD assist
unless stated). Cells are *win % / mean rounds / mean damage taken by the party*. Reproduce with the
commands below; same seed and data give the same numbers.

```sh
godot --headless --path . --script res://tools/simulate.gd -- --encounter=all --exec=MISS,GOOD,PERFECT,MIXED --runs=50 --seed=7
godot --headless --path . --script res://tools/simulate.gd -- --encounter=bramble_den,mirebell_cantor,rot_grove --exec=MISS,MIXED --difficulty=STORY,ADVENTURER,TACTICIAN --runs=60 --seed=11
godot --headless --path . --script res://tools/simulate.gd -- --encounter=fen_patrol,mire_shrine,bramble_den,mirebell_cantor --exec=MIXED --assist=STANDARD,ASSISTED --runs=60 --seed=13
```

## 1. Execution profiles (50 battles per cell)

| Encounter | Loadout | MISS | GOOD | PERFECT | MIXED |
|---|---|---|---|---|---|
| Training Yard (toy) | Sword | 100 / 7.0 / 21 | 100 / 5.9 / 9 | 100 / 5.0 / 0 | 100 / 5.9 / 11 |
|  | Hammer | 100 / 6.1 / 34 | 100 / 5.4 / 6 | 100 / 4.8 / 0 | 100 / 5.6 / 8 |
|  | Bow | 100 / 7.7 / 34 | 100 / 6.0 / 9 | 100 / 5.0 / 1 | 100 / 6.0 / 12 |
| Fen Patrol | Sword | 100 / 7.0 / 166 | 100 / 5.2 / 43 | 100 / 5.0 / 7 | 100 / 5.4 / 58 |
|  | Hammer | 100 / 5.4 / 168 | 100 / 3.4 / 36 | 100 / 3.0 / 6 | 100 / 3.7 / 52 |
|  | Bow | 100 / 7.1 / 189 | 100 / 5.2 / 46 | 100 / 4.3 / 7 | 100 / 5.4 / 63 |
| Rot Grove | Sword | 100 / 5.3 / 135 | 100 / 4.4 / 15 | 100 / 4.0 / 2 | 100 / 4.4 / 27 |
|  | Hammer | 100 / 7.3 / 152 | 100 / 5.4 / 19 | 100 / 4.6 / 4 | 100 / 5.5 / 33 |
|  | Bow | 100 / 8.0 / 189 | 100 / 5.5 / 40 | 100 / 4.2 / 2 | 100 / 5.6 / 58 |
| Mire Shrine | Sword | 100 / 6.9 / 128 | 100 / 5.2 / 36 | 100 / 5.0 / 4 | 100 / 5.3 / 49 |
|  | Hammer | 100 / 5.0 / 88 | 100 / 3.9 / 31 | 100 / 4.0 / 6 | 100 / 3.9 / 44 |
|  | Bow | 100 / 6.8 / 135 | 100 / 5.1 / 37 | 100 / 4.4 / 4 | 100 / 5.2 / 52 |
| Thornhound Pack | Sword | 98 / 5.2 / 196 | 100 / 3.4 / 39 | 100 / 3.0 / 3 | 100 / 3.7 / 58 |
|  | Hammer | 74 / 6.8 / 300 | 100 / 3.2 / 43 | 100 / 3.0 / 4 | 100 / 3.5 / 67 |
|  | Bow | 86 / 6.4 / 266 | 100 / 3.8 / 51 | 100 / 3.0 / 3 | 100 / 3.9 / 66 |
| Bramble Den (elite) | Sword | 94 / 9.0 / 226 | 100 / 6.3 / 56 | 100 / 5.0 / 7 | 100 / 6.3 / 76 |
|  | Hammer | 50 / 8.6 / 284 | 100 / 5.6 / 60 | 100 / 5.0 / 7 | 100 / 5.8 / 86 |
|  | Bow | 54 / 10.5 / 313 | 100 / 6.3 / 62 | 100 / 5.1 / 6 | 100 / 6.4 / 90 |
| Mirebell Cantor (boss) | Sword | 0 / 13.3 / 345 | 100 / 12.0 / 98 | 100 / 9.7 / 15 | 100 / 12.1 / 120 |
|  | Hammer | 40 / 14.5 / 324 | 100 / 10.3 / 78 | 100 / 8.4 / 24 | 100 / 10.8 / 112 |
|  | Bow | 2 / 13.7 / 353 | 100 / 11.0 / 79 | 100 / 8.7 / 16 | 100 / 11.2 / 109 |
| Briarfen Gauntlet (stress) | Sword | 100 / 8.8 / 233 | 100 / 7.0 / 50 | 100 / 6.1 / 7 | 100 / 7.3 / 73 |
|  | Hammer | 100 / 8.1 / 211 | 100 / 6.4 / 42 | 100 / 5.6 / 3 | 100 / 6.3 / 63 |
|  | Bow | 74 / 10.1 / 300 | 100 / 7.8 / 72 | 100 / 6.3 / 6 | 100 / 8.0 / 100 |

Round targets: normal 3–5, elite 4–7, boss 7–13. The Briarfen Gauntlet is a stress test (four roles at
once), not a designed fight.

## 2. Tactical difficulty (60 battles per cell)

| Encounter | Loadout | Execution | Story | Adventurer | Tactician |
|---|---|---|---|---|---|
| Rot Grove | Sword | MISS | 100 / 5.2 / 126 | 100 / 5.2 / 145 | 100 / 6.0 / 169 |
|  |  | MIXED | 100 / 4.2 / 23 | 100 / 4.4 / 22 | 100 / 4.3 / 36 |
|  | Hammer | MISS | 100 / 6.1 / 82 | 100 / 7.3 / 161 | 100 / 7.0 / 165 |
|  |  | MIXED | 100 / 4.7 / 20 | 100 / 5.3 / 34 | 100 / 4.8 / 40 |
|  | Bow | MISS | 100 / 7.1 / 115 | 100 / 7.9 / 187 | 100 / 8.0 / 190 |
|  |  | MIXED | 100 / 5.1 / 38 | 100 / 5.5 / 50 | 100 / 5.0 / 47 |
| Bramble Den (elite) | Sword | MISS | 95 / 8.6 / 236 | 97 / 9.2 / 235 | 90 / 10.0 / 249 |
|  |  | MIXED | 100 / 6.3 / 78 | 100 / 6.4 / 76 | 100 / 6.4 / 67 |
|  | Hammer | MISS | 30 / 9.1 / 326 | 25 / 8.7 / 310 | 17 / 8.2 / 309 |
|  |  | MIXED | 100 / 5.8 / 78 | 100 / 5.8 / 84 | 100 / 5.9 / 78 |
|  | Bow | MISS | 67 / 10.3 / 314 | 63 / 10.6 / 315 | 38 / 11.1 / 330 |
|  |  | MIXED | 100 / 6.5 / 84 | 100 / 6.5 / 85 | 100 / 6.5 / 78 |
| Mirebell Cantor (boss) | Sword | MISS | 43 / 15.2 / 324 | 0 / 13.3 / 345 | 0 / 12.6 / 348 |
|  |  | MIXED | 100 / 12.1 / 109 | 98 / 12.1 / 129 | 100 / 12.2 / 118 |
|  | Hammer | MISS | 73 / 14.8 / 300 | 32 / 14.5 / 327 | 40 / 14.9 / 326 |
|  |  | MIXED | 100 / 10.7 / 104 | 100 / 10.8 / 111 | 100 / 10.4 / 94 |
|  | Bow | MISS | 47 / 14.9 / 313 | 3 / 13.6 / 351 | 0 / 13.7 / 360 |
|  |  | MIXED | 100 / 11.1 / 78 | 100 / 11.3 / 114 | 100 / 11.1 / 103 |

Enemy stats are identical across tiers (GDD: smarter, not inflated).

## 3. Execution assist (MIXED execution, 60 battles per cell)

| Encounter | Loadout | STANDARD | ASSISTED | Breaks (STD → AST) |
|---|---|---|---|---|
| Fen Patrol | Sword | 100 / 5.5 / 65 | 100 / 5.1 / 28 | 0.9 → 1.0 |
| Fen Patrol | Hammer | 100 / 3.7 / 58 | 100 / 3.1 / 26 | 0.5 → 0.1 |
| Fen Patrol | Bow | 100 / 5.4 / 67 | 100 / 5.0 / 30 | 0.7 → 0.8 |
| Mire Shrine | Sword | 100 / 5.5 / 51 | 100 / 5.0 / 17 | 0.9 → 1.0 |
| Mire Shrine | Hammer | 100 / 4.0 / 48 | 100 / 4.0 / 22 | 1.0 → 1.0 |
| Mire Shrine | Bow | 100 / 5.2 / 51 | 100 / 5.0 / 17 | 0.8 → 0.9 |
| Bramble Den (elite) | Sword | 100 / 6.4 / 69 | 100 / 5.8 / 28 | 0.7 → 0.8 |
| Bramble Den (elite) | Hammer | 100 / 5.9 / 73 | 100 / 5.1 / 26 | 1.0 → 1.0 |
| Bramble Den (elite) | Bow | 100 / 6.5 / 85 | 100 / 5.7 / 32 | 0.6 → 0.5 |
| Mirebell Cantor (boss) | Sword | 100 / 12.1 / 116 | 100 / 10.7 / 54 | 2.0 → 2.0 |
| Mirebell Cantor (boss) | Hammer | 100 / 10.8 / 118 | 100 / 9.7 / 50 | 2.0 → 2.0 |
| Mirebell Cantor (boss) | Bow | 100 / 11.2 / 107 | 100 / 9.8 / 31 | 1.5 → 1.6 |

Assisted widens windows, slows indicators, auto-Braces and floors commands at GOOD; it never changes
enemy decisions or numbers. It roughly halves damage taken while the number of Stagger breaks a fight
needs is unchanged — the tactical structure survives.

## 4. Bestiary knowledge

Running the Fen Patrol, Mire Shrine and boss batches with `--research=MASTERED` reproduces the STANDARD
rows of section 3 exactly. That is expected: research gates *information* (exact numbers, weaknesses,
move names, AI reasons), never stats, and the autopilot reads exact numbers regardless of research. The
Bestiary acceptance test therefore needs human playtests, or a future knowledge-limited autopilot
policy that only sees what the HUD shows at a given research level.

## 5. Never-used content (section 1 runs)

Enemy moves the AI never chose, by encounter (batches out of 12):

- Training Yard (toy): slow_overhead (1)
- Fen Patrol: arc_storm (12)
- Rot Grove: needle_hum (12), sporeburst (11), harrying_lunge (5), overgrowth_smash (1)
- Mire Shrine: cleansing_mire (12), arc_storm (12), moss_mend (9), shell_ward (9)
- Bramble Den (elite): harrying_lunge (7), hunts_end (5)
- Mirebell Cantor (boss): requiem (2), drowning_toll (1), final_knell (1)
- Briarfen Gauntlet (stress): cleansing_mire (12), arc_storm (12), moss_mend (4), overgrowth_smash (1)

Party actions the autopilot never chose, by loadout (batches out of 32):

- Sword: spark (32), riposte_stance (32), use_fen_water_flask (32), kindle (25), intercept (25), guard (25), arc_cleave (24), condemn (12), use_mending_draught (8)
- Hammer: use_clotting_salve (32), spark (31), kindle (30), anchor_stance (28), intercept (24), guard (24), shockwave (19), use_mending_draught (5), condemn (4), earthsplitter (1)
- Bow: spark (32), use_focus_tincture (32), intercept (24), steady_aim (23), guard (23), kindle (22), use_mending_draught (9), spotters_mark (7), condemn (6), heartseeker (4)

The autopilot values damage, Stagger, Focus, kills and healing; it under-values setup moves (stances,
Intercept, elemental magic) that players use deliberately, so party-side flags are prompts for
playtests rather than proof that an option is dead. See `docs/DESIGN_QUESTIONS.md` (Q3–Q7).
