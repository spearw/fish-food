## current_run.gd
## A Singleton that holds the configuration for the currently active game session.
## This data is NOT saved. It is reset at the start of each run.
extends Node

## Spawn intensity - affects how many enemies spawn (budget multiplier).
enum SpawnIntensity {
	LOW,     # 0.7x budget - fewer enemies
	NORMAL,  # 1.0x budget - standard spawning
	HIGH,    # 1.5x budget - more enemies
}

## Counter mode - affects which enemies spawn based on player's build.
enum CounterMode {
	EASY,    # Spawns more enemies player is strong against
	NORMAL,  # No counter-spawning adjustments
	HARD,    # Spawns more enemies that counter the player
}

## Intensity multipliers for budget scaling.
const INTENSITY_MULTIPLIERS = {
	SpawnIntensity.LOW: 0.7,
	SpawnIntensity.NORMAL: 1.0,
	SpawnIntensity.HIGH: 1.5,
}

## The core deck is granted every run regardless of selection -- it holds the base-stat upgrades, so
## without it a run has almost nothing to draft.
const CORE_DECK_PATH := "res://systems/upgrades/packs/core_pack.tres"

# The PlayerStats resource for the player in this run.
var selected_character: PlayerStats = null

# The list of resource paths for the packs chosen for this specific run.
var selected_pack_paths: Array[String] = []

## How many THEMED decks (core excluded) this run may hold. Two is the design: the combo gate rewards
## depth, and a run's ~20-30 picks only fund about two decks deep enough to reach their payoffs. A
## third is a rare in-run reward (it's what a second combo needs). Never four.
## See docs/deck_and_synergy_design.md section 2.
var max_themed_decks: int = 2

## How many loadout slots a run has. Weapons and artifacts SHARE this pool, so every pick spends the
## same currency: another weapon, or another rule.
##
## The cap is the whole point. Without it a new weapon costs nothing, so nothing is ever foregone and
## a level-up is a queue ("what order do I collect everything in?") rather than a choice. Sharing the
## pool with artifacts is what keeps that choice self-balancing: a weapon's marginal value falls off as
## +1/N while an artifact's stays flat, so neither category can dominate forever.
## See docs/deck_and_synergy_design.md section 3.
var max_loadout_slots: int = 5

# The biome selected for this run (affects enemy spawning).
var selected_biome: BiomeDefinition = null

# The encounter config for this run (affects enemy spawn weighting).
var selected_encounter_config: EncounterConfig = null

# --- Difficulty Settings (2D grid) ---
# Spawn intensity (Y-axis): How many enemies spawn.
var spawn_intensity: SpawnIntensity = SpawnIntensity.NORMAL
# Counter mode (X-axis): Which enemies spawn based on build.
var counter_mode: CounterMode = CounterMode.NORMAL

# True once upgrade 0 (the starting-weapon roll) has been offered this run -- it fires exactly once.
var starting_weapon_chosen: bool = false

# --- Cross-deck combo state (see systems/combos/) ---
## Cards drafted from each deck this run, keyed by Deck.id. Feeds combo power gates.
var deck_draft_counts: Dictionary = {}
## True once the player has taken a cross-deck combo this run (one per run).
var combo_taken: bool = false

## Returns the budget multiplier for the current spawn intensity.
func get_intensity_multiplier() -> float:
	return INTENSITY_MULTIPLIERS.get(spawn_intensity, 1.0)

## The decks whose cards can appear this run: the core deck (always) plus the player's picks,
## clamped to max_themed_decks. Characters are NOT linked to decks -- identity lives in the granted
## identity artifact, and any character can run any pair (design doc section 3).
func get_active_deck_paths() -> Array[String]:
	var themed: Array[String] = []
	for path in selected_pack_paths:
		if themed.size() >= max_themed_decks:
			break
		if path == CORE_DECK_PATH or path in themed:
			continue
		themed.append(path)

	var paths: Array[String] = [CORE_DECK_PATH]
	paths.append_array(themed)
	return paths
