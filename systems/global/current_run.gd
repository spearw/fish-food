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
## Enum names describe what the director DOES; the player-facing labels are the difficulty tiers:
## FAVORING = "Normal" (the default experience -- the genre is built on feeling powerful),
## NEUTRAL = "Hard" (the ocean is indifferent), ADVERSARIAL = "Abyssal" (the depths hunt your build).
enum CounterMode {
	FAVORING,     # "Normal" -- spawns more enemies the player is strong against
	NEUTRAL,      # "Hard" -- no counter-spawning adjustments
	ADVERSARIAL,  # "Abyssal" -- spawns more enemies that counter the player
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
# FAVORING is the default: "Normal" difficulty IS the player-favoring experience.
var counter_mode: CounterMode = CounterMode.FAVORING

# True once upgrade 0 (the starting-weapon roll) has been offered this run -- it fires exactly once.
var starting_weapon_chosen: bool = false

# --- Card manipulation (design doc section 7 item 6) ---
# PRE-commitment only: these act on the OFFER, never on owned slots -- the principle that keeps them
# from colliding with merge (the one post-commitment lever). Flat per-run charges for now; a meta
# unlock can feed these later (VS gates its charges behind meta progression the same way).
const REROLLS_PER_RUN := 2
const BANISHES_PER_RUN := 2

## Charges left this run. Reroll = redraw all current choices; banish = remove a card from this
## run's pool permanently, refilling its slot.
var rerolls_remaining: int = REROLLS_PER_RUN
var banishes_remaining: int = BANISHES_PER_RUN
## Cards banished this run -- excluded from every draw until the next run.
var banished_upgrades: Array[Upgrade] = []

## Resets all per-run state. Called when a run starts (the character-select start button).
## Without this, a second run in the same session inherits the first run's flags -- no starter roll,
## no combo offer, stale draft counts.
func reset_run_state() -> void:
	deck_draft_counts = {}
	combo_taken = false
	starting_weapon_chosen = false
	rerolls_remaining = REROLLS_PER_RUN
	banishes_remaining = BANISHES_PER_RUN
	banished_upgrades.clear()
	damage_by_source.clear()
	herald_scheduled = false
	herald_spawned_at = -1.0
	herald_killed_at = -1.0
	herald_left = false
	herald_flawless = true
	leviathan_stats = null
	herald_slain_name = ""
	leviathan_killed = false

# --- Per-source damage attribution (UX: the genre's most build-relevant readout) ---
## Post-armor damage dealt this run, keyed by source ("Daggers", "Static Discharge", "Other").
## Weapons use their weapon_type name; everything a weapon causes (sparks, explosions, zones,
## DoT ticks) inherits its key, so the report answers "what's carrying" at weapon granularity.
var damage_by_source: Dictionary = {}

func credit_damage(key: String, amount: int) -> void:
	if amount <= 0:
		return
	damage_by_source[key] = damage_by_source.get(key, 0) + amount

# --- Cross-deck combo state (see systems/combos/) ---
## Cards drafted from each deck this run, keyed by Deck.id. Feeds combo power gates.
var deck_draft_counts: Dictionary = {}
## True once the player has taken a cross-deck combo this run (one per run).
var combo_taken: bool = false

# --- Herald state (the mini-boss that carries the combo trigger; see EncounterDirector) ---
## True when the run's director has herald candidates configured. When false (benches, test worlds),
## the combo trigger stays on the legacy level check.
var herald_scheduled: bool = false
## Run-timer stamps, -1 until they happen. killed - spawned is the speed proof for the secret lure.
var herald_spawned_at: float = -1.0
var herald_killed_at: float = -1.0
## True if the herald left unkilled (its leave timer ran out).
var herald_left: bool = false
## True while no player hit has landed during a live herald fight -- the flawless proof.
var herald_flawless: bool = true

func herald_active() -> bool:
	return herald_spawned_at >= 0.0 and herald_killed_at < 0.0 and not herald_left

# --- Leviathan state (the final boss that gates the 20:00 win; see EncounterDirector) ---
## The run's drawn final boss, revealed in the build summary from the first level-up. Drawn once
## the starting weapon exists (so the counter-mode weighting has a build to read), null until then
## and in worlds with no leviathan candidates.
var leviathan_stats: EnemyStats = null
## Which herald died this run ("" if none) -- feeds the leviathan's rider.
var herald_slain_name: String = ""
var leviathan_killed: bool = false

## The rider the slain herald passes down the food chain: a small thematic twist on the final boss.
const LEVIATHAN_RIDERS := {
	"The Bloom": "Spined",        # phase transitions release a spine burst
	"The Warden": "Restless",     # telegraphs run faster
	"The Quillmother": "Quilled", # attacks leave drifting spines
}

func leviathan_rider() -> String:
	return LEVIATHAN_RIDERS.get(herald_slain_name, "")

func _ready() -> void:
	# The flawless proof listens run-wide: any hit taken while the herald lives breaks it.
	Events.player_was_hit.connect(_on_player_was_hit)

func _on_player_was_hit(_source) -> void:
	if herald_active():
		herald_flawless = false

## Returns the budget multiplier for the current spawn intensity.
func get_intensity_multiplier() -> float:
	return INTENSITY_MULTIPLIERS.get(spawn_intensity, 1.0)

## The decks whose cards can appear this run: the player's picks, deduped, clamped to
## max_themed_decks. There is NO core deck -- generic stat cards live inside the themed decks with
## deliberate overlap (Monster Train model, design doc section 1b), so picking decks IS picking a
## stat economy. Characters are NOT linked to decks -- identity lives in the granted identity
## artifact, and any character can run any pair (design doc section 3).
func get_active_deck_paths() -> Array[String]:
	var themed: Array[String] = []
	for path in selected_pack_paths:
		if themed.size() >= max_themed_decks:
			break
		if path in themed:
			continue
		themed.append(path)
	return themed
