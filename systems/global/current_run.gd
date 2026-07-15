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

## The decks whose cards can appear this run: the core deck (always), then the themed decks -- the
## character's linked primary first, then whatever the player chose -- clamped to max_themed_decks.
## The primary is added first on purpose: it's the character's identity, so it must never be the deck
## the cap clips.
func get_active_deck_paths() -> Array[String]:
	var themed: Array[String] = []

	if selected_character and selected_character.primary_deck:
		themed.append(selected_character.primary_deck.resource_path)

	for path in selected_pack_paths:
		if themed.size() >= max_themed_decks:
			break
		if path == CORE_DECK_PATH or path in themed:
			continue
		themed.append(path)

	var paths: Array[String] = [CORE_DECK_PATH]
	paths.append_array(themed)
	return paths

## How many themed decks a character still leaves the player to choose, given their primary is
## granted for free. Drives the pre-run deck picker's selection limit. Takes the character as an
## argument because the picker asks about a character the player hasn't committed to yet.
func get_secondary_deck_slots_for(character: PlayerStats) -> int:
	var granted := 1 if (character and character.primary_deck) else 0
	return max(0, max_themed_decks - granted)
