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

# The PlayerStats resource for the player in this run.
var selected_character: PlayerStats = null

# The list of resource paths for the packs chosen for this specific run.
var selected_pack_paths: Array[String] = []

# The biome selected for this run (affects enemy spawning).
var selected_biome: BiomeDefinition = null

# The encounter config for this run (affects enemy spawn weighting).
var selected_encounter_config: EncounterConfig = null

# --- Difficulty Settings (2D grid) ---
# Spawn intensity (Y-axis): How many enemies spawn.
var spawn_intensity: SpawnIntensity = SpawnIntensity.NORMAL
# Counter mode (X-axis): Which enemies spawn based on build.
var counter_mode: CounterMode = CounterMode.NORMAL

# --- Cross-deck combo state (see systems/combos/) ---
## Cards drafted from each deck this run, keyed by Deck.id. Feeds combo power gates.
var deck_draft_counts: Dictionary = {}
## True once the player has taken a cross-deck combo this run (one per run).
var combo_taken: bool = false

## Returns the budget multiplier for the current spawn intensity.
func get_intensity_multiplier() -> float:
	return INTENSITY_MULTIPLIERS.get(spawn_intensity, 1.0)
