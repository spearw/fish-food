# Fish Food - Design Roadmap

## Core Design Philosophy

Fish Food is an underwater bullet-heaven roguelike emphasizing **thematic cohesion** through deck-character linking while maintaining mechanical depth via multiplicative scaling and intelligent encounter generation.

### Technical Pillars
1. **Data-Driven Content**: All weapons, enemies, artifacts, and upgrades must be creatable via .tres resources and scene inheritance WITHOUT writing new GDScript code.
2. **Scalable Performance**: Architecture must handle 200+ enemies and projectiles simultaneously. See CLAUDE.md for optimization patterns.

---

## Upgrade & Deck System

### Deck Structure (~15 cards each)
| Type | Count | Purpose |
|------|-------|---------|
| Weapons | 3 | Unique weapons per deck |
| Weapon Upgrades | 6 | 2 per weapon, enabling transformations |
| Artifacts | 3 | Unique passive effects (require custom code) |
| Synergy Upgrades | 3 | Deck-specific mechanical synergies |

### Core Deck (Universal)
Available every run regardless of deck selection:
- Damage
- Move Speed
- Projectile Speed
- Critical Chance
- Critical Damage
- Luck

**Note**: Core deck contains NO weapons - only stat upgrades.

### Weapon Upgrade Philosophy
- **One weapon upgrade per weapon per run** (prevents stacking on same weapon)
- Upgrades are **multiplicative modifiers on player stats**, not individual weapons
- Ensures consistency across different weapon attack speeds

---

## Character System

### Character-Deck Linking
- Each character thematically tied to a specific deck
- Characters receive **exclusive starting weapon** from their deck
- Player can select a **secondary deck** for build variety

### Example
> "Fire Mage" starts with Fire Staff and has access to the Fire deck. Player can pick a secondary deck (e.g., Melee) for hybrid builds.

---

## Encounter Director

### Tag-Based Enemy System
Instead of predefined enemy sets, use **dynamic tagging**:

```
Enemy Tags: [freshwater, fish, small, fast]
Level Tags: [freshwater, cave] → weights freshwater enemies higher
```

### Benefits
- Thematic cohesion per level/biome
- Runtime pool generation for variety
- Future-proof for new mechanics

### Tag-Based Mechanics (Future)
- **Weapon bonuses**: "Salt" weapon deals bonus damage to "freshwater" or "slug" tagged enemies
- **Difficulty-based counter-spawning**: See Difficulty System section below

### Encounter Configs
Encounter configs are randomly selected at run start and shown to the player via a banner. They weight enemy spawns without changing which enemies CAN spawn (that's the biome's job).

**Architecture:**
- **Biome** = hard filter (which enemies CAN spawn)
- **EncounterConfig** = soft weights (which enemies are MORE LIKELY)
- **Points curve** = difficulty scaling over time
- **Randomness** = variety within weighted selection

**Current Configs:**
- `swarm_tiny_small_config` → "Swarm Infestation" - Large groups of small enemies
- `armored_large_config` → "Armored Assault" - Heavily armored foes
- `ranged_evasive_config` → "Ranged Barrage" - Enemies attack from distance
- `large_slow_config` → "Slow Horrors" - Slow but deadly creatures

---

## Difficulty System (Future)

### Overview
Difficulty modes that dynamically adjust encounter weights based on the player's build.

### EASY Mode
- Analyzes player's selected upgrades, weapons, and artifacts
- Identifies tags the player is strong against
- **Increases** spawn weight for enemies the player counters well
- Makes runs feel powerful and rewarding for new players

### HARD Mode
- Analyzes player's selected upgrades, weapons, and artifacts
- Identifies tags the player is weak against
- **Increases** spawn weight for enemies that counter the player's build
- Prevents repetitive "solved" strategies
- Forces adaptation and build variety

### Implementation (Foundation Complete)

**Effect Tags on Items:**
- `Weapon.effects: Array[WeaponTags.Effect]` - weapon behaviors (AOE, HOMING, etc.)
- `Upgrade.effects: Array[WeaponTags.Effect]` - upgrade contributions
- `ArtifactBase.effects: Array[WeaponTags.Effect]` - artifact contributions

**Counter Matrix** (`WeaponTags.COUNTER_MATRIX`):
Maps player effects → enemy behaviors → effectiveness multiplier.
```
Effect.AOE → { SWARM: 1.5, HORDE: 1.4, ARMORED: 0.7 }
Effect.HOMING → { EVASIVE: 1.8, FAST: 1.5 }
Effect.ARMOR_PEN → { ARMORED: 1.8 }
...
```

**Build Analyzer** (`BuildAnalyzer`):
- Gathers all effect tags from player's weapons/upgrades/artifacts
- Calculates actual metrics (DPS, area coverage) for hybrid scaling
- `get_effectiveness_vs_behavior(behavior)` → effectiveness multiplier
- `get_strongest_against()` / `get_weakest_against()` → for difficulty logic

**Remaining Work:**
- [ ] Add `get_weapons()` and `get_artifacts()` methods to Player
- [ ] Wire BuildAnalyzer into EncounterDirector
- [ ] Add difficulty mode selection (EASY/NORMAL/HARD)
- [ ] Apply effectiveness multipliers to spawn weights
- [ ] Populate effects on existing weapons/upgrades/artifacts

---

## Armor System

### Formula
```
damage_taken = max(0, damage - armor)
```

### Trade-offs
- **Speed penalty**: ~1% move speed reduction per armor point
- Heavy armor = slower but tankier

### Armor Penetration
- Percentage-based armor reduction
- Example: 75% penetration → enemy armor is 25% effective
- 100% penetration = full armor bypass (counter to tank builds)

---

## Implementation Status

### Completed
- [x] Core gameplay loop (move, shoot, level up)
- [x] Upgrade/rarity system with packs
- [x] Budget-based enemy spawning
- [x] Meta-progression (souls, unlocks)
- [x] Meta shop with tabs (Stats, Characters, Packs)
- [x] Multiple characters and weapons
- [x] Status effects and projectile variants
- [x] Enemy tag system (biome, type, size, behavior tags)
- [x] Biome-based enemy pool filtering
- [x] Encounter config system with random selection at run start
- [x] Encounter config banner UI (show selected config to player)
- [x] Counter-spawning foundation (effect tags, counter matrix, BuildAnalyzer)

### In Progress
- [ ] Character-deck exclusive linking
- [ ] Secondary deck selection UI
- [ ] Difficulty mode integration (wire BuildAnalyzer into EncounterDirector)

### Planned
- [ ] Difficulty mode selection UI (EASY/NORMAL/HARD)
- [ ] Weapon bonuses vs enemy type tags
- [ ] Armor/penetration stat implementation
- [ ] Weapon transformation system (upgrade paths)
- [ ] More artifacts with unique effects
- [ ] World events system

---

## Content Roadmap

### Decks to Build
1. **Fire Deck** - DoT, explosions, area damage
2. **Melee Deck** - Close range, armor, lifesteal
3. **Projectile Deck** - Pierce, multishot, homing
4. **Desiccation/Salt Deck** - Anti-freshwater, area denial
5. **Explosive Deck** - AoE, knockback
6. **Mage Deck** - Varied magical effects
7. **Spawn Deck** - Companions, summons
8. **Nature Deck** - TBD

### Characters (Linked to Decks)
- Edgerunner → Melee
- Magic Man → Fire
- Shotgunner → Projectile
- Samurai → Melee (variant)
- *(More to come)*

---

## Brainstormed Content (From Spreadsheets)

### Weapon Ideas

| Weapon | Type | Effect |
|--------|------|--------|
| Salt the Earth | Trail | Leave damaging salt trail, bonus vs freshwater |
| Pillar of Salt | Burst | Instant salt pillar on nearest enemy |
| Silica Gel | Rapid Fire | Desiccates targets |
| Flamethrower | Pierce DoT | Fast low damage with burn |
| Charge | Melee | High damage, brief immunity, knockback, moves player |
| Spawn Companion | Summon | Ranged attack companion |
| Spawn Bomb Guy | Summon | Companion moves to enemies and explodes |
| Laser | Beam | Infinite range, piercing, slow fire |
| Spike Launcher | Radial | Spikes in all directions |
| Bomb | Drop | Explosives behind player |
| Aura | Passive | Constant damage in player area |
| Turrets | Deployable | Plant auto-firing turrets |
| Aggro Turret | Deployable | Turret that distracts enemies |
| Hologram | Decoy | Copy that moves/runs away |
| Chain Lightning | Chain | Chains to multiple enemies |

### Artifact Ideas

| Artifact | Effect |
|----------|--------|
| Overwhelming Critical | Crits roll again for bonus crit damage (repeating) |
| Exploding Critical | Overkill damage explodes, dealing max HP to nearby |
| Responsive Armor | Taking damage increases damage negation temporarily |
| Headshot Only | Non-crits deal 0, but crit damage x2 |
| Bounce | Projectiles bounce to nearest target |
| Ebb and Flow | Damage oscillates 50-200%, attack speed 200-50% |
| Fight or Flight | Move speed increases per nearby enemy |
| Goliath | Size/damage increase per HP, move speed decrease |
| Phase | Taking damage teleports randomly |
| Glass Mirror | Spawn mirrored copy (100% damage, 1 HP) |
| No Critical?! | No crits, gain aphid pet that attacks and heals |
| Second Life | Respawn once on death |
| Absorb | Absorb projectiles, release as pulse wave |
| Chaos | Swap owned pack for two random packs |

### World Event Ideas
- **Area Capture**: Stand in zone long enough → Big XP / Item reward

### Enemy Ideas
- **Tiktaalik**: Slow moving, quick turning, hard hitting "Merger" type

---

## External Resources

- [Design + Roadmap Notes](https://docs.google.com/document/d/1Zn1orb1vK2y6ZFQxL_FTZxS_300K9Vh8d6maMsqSsMo)
- [Deck Brainstorming](https://docs.google.com/spreadsheets/d/1_euxhAlVdj3-Ip8m-4hSVRnrXFWi6f1xH6D03QZsoZk)
- [Weapons Sheet](https://docs.google.com/spreadsheets/d/1iuHw8eomGoKt--LrINJexoRdV_7b8zFJfaw7EjeViQ8)
- [Enemies Sheet](https://docs.google.com/spreadsheets/d/1gebOmIuPgAofTkWf-AffJkI8Z1A1ZKUgVES8QWVWjIE)
- [World Events Sheet](https://docs.google.com/spreadsheets/d/1fUTuTXFYKqxuJUYE6Er5ozM_5cx6jKsBKPQwsyRXJXo)
- [Artifacts Sheet](https://docs.google.com/spreadsheets/d/1Igdi28AW_8ZRTYxZlm2UKjtF6cponQQH2MilSfkAfYU)
- [Google Drive Folder](https://drive.google.com/drive/folders/1hEQWpwWELo_fGMfKqRfqkWw_I7nQ8IQw)
