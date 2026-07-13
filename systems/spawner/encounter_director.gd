## encounter_director.gd
## A budget-based spawner. Acts as an "Encounter Director".
class_name EncounterDirector
extends Node

# --- CONFIGURATION ---
@export var enemy_scene: PackedScene
@export var difficulty_curve: Curve
@export var encounter_sets: Array[EncounterSet]
@export var spawn_radius: float = 1200.0
@export var encounter_config: EncounterConfig  ## Tag-based weighting (overrides biome config)

@onready var spawn_pulse_timer: Timer = $Timer

# --- RUNTIME STATE ---
var run_timer: float = 0.0
var budget_accumulator: float = 0.0
var player_node: Node2D
var active_biome: BiomeDefinition  ## Set from CurrentRun at start


# --- THREAT TRACKING ---
# Key: EnemyTags.Behavior enum value, Value: Total Challenge Rating on screen (float)
var current_threat: Dictionary = {}
# A list of all encounter sets, which will shrink as they are processed.
var pending_encounter_sets: Array[EncounterSet]

# --- METAPROGRESSION ---
var threat_level: float = 1.0 # This will later be fetched from GameData as a player unlocks/increases difficulty

# --- BUILD ANALYSIS (for counter-spawning) ---
var build_analyzer: BuildAnalyzer = null

func _ready():
	# Validate that we have everything we need to function.
	if not enemy_scene or not difficulty_curve or encounter_sets.is_empty():
		printerr("DynamicSpawner is not fully configured! Disabling.")
		set_physics_process(false)
		return

	player_node = get_tree().get_first_node_in_group("player")

	# Get biome from CurrentRun (if set)
	active_biome = CurrentRun.selected_biome

	# Get encounter config - priority: CurrentRun > @export override > biome default
	if CurrentRun.selected_encounter_config:
		encounter_config = CurrentRun.selected_encounter_config
	elif not encounter_config and active_biome and active_biome.encounter_config:
		encounter_config = active_biome.encounter_config

	if encounter_config:
		Logs.add_message("Encounter Config: %s" % encounter_config.display_name)

	# In the future, get this from GameData:
	# threat_level = GameData.data["permanent_stats"].get("threat_level", 1.0)
	spawn_pulse_timer.timeout.connect(_on_spawn_pulse_timer_timeout)
	# Sort the master list by time and create pending list.
	encounter_sets.sort_custom(func(a, b): return a.time_start < b.time_start)
	pending_encounter_sets = encounter_sets.duplicate()

	# Initialize build analysis for counter-spawning (only if not NORMAL mode)
	if CurrentRun.counter_mode != CurrentRun.CounterMode.NORMAL:
		_update_build_analysis()
		# Re-analyze when player's build changes (weapons/upgrades/artifacts)
		if is_instance_valid(player_node) and player_node.has_signal("stats_changed"):
			player_node.stats_changed.connect(_update_build_analysis)
	
func _physics_process(delta: float):
	if not is_instance_valid(player_node): return

	# Accumulate the budget.
	run_timer += delta
	var base_budget_per_sec = difficulty_curve.sample(run_timer)
	var intensity_mult = CurrentRun.get_intensity_multiplier()
	var current_frame_budget = base_budget_per_sec * threat_level * intensity_mult * delta
	budget_accumulator += current_frame_budget
	
	# Check for any one-time "override" events that need to fire now.
	# While loop to handles multiple events triggering on the same frame.
	while not pending_encounter_sets.is_empty() and run_timer >= pending_encounter_sets[0].time_start:
		var event_to_check = pending_encounter_sets[0]
		
		if event_to_check.spawn_immediately_on_start:
			# It's a boss/burst event. Process it now.
			var event = pending_encounter_sets.pop_front() # Get and remove it from the list
			Logs.add_message("Director Override: Spawning immediate event '%s'" % event.resource_path)
			
			for enemy_stat in event.enemies:
				# Spawn the enemy and go into budget deficit.
				budget_accumulator -= enemy_stat.challenge_rating
				spawn_enemy(enemy_stat)
		else:
			# It's a normal, repeating set. Since the list is sorted,
			# we know no later "immediate" events are ready yet.
			break

func _on_spawn_pulse_timer_timeout():
	#Logs.add_message(["Director Budget:", budget_accumulator])
	var available_enemies = _get_currently_available_enemies()
	if available_enemies.is_empty(): return

	var theme_enemy_stats = _pick_theme_enemy(available_enemies, budget_accumulator)
	
	if not theme_enemy_stats: return

	while budget_accumulator >= theme_enemy_stats.challenge_rating:
		budget_accumulator -= theme_enemy_stats.challenge_rating
		spawn_enemy(theme_enemy_stats)


## Updates the cached build analysis when player's build changes.
func _update_build_analysis():
	if is_instance_valid(player_node):
		build_analyzer = BuildAnalyzer.analyze_player(player_node)

## Gathers all enemies from EncounterSets that are active at the current run_timer.
## If a biome is selected, filters to only enemies matching that biome.
func _get_currently_available_enemies() -> Array[EnemyStats]:
	var available: Array[EnemyStats] = []
	for encounter_set in encounter_sets:
		var is_active = run_timer >= encounter_set.time_start and \
						(encounter_set.time_end == -1 or run_timer < encounter_set.time_end)

		if is_active:
			available.append_array(encounter_set.enemies)

	# Filter by biome if one is selected
	if active_biome:
		available = available.filter(func(es): return active_biome.can_enemy_spawn(es))

	return available

## Selects an enemy from the pool, weighted by EncounterConfig tags.
func _pick_theme_enemy(pool: Array[EnemyStats], budget: float) -> EnemyStats:
	var affordable_pool = pool.filter(func(es): return es.challenge_rating <= budget)
	if affordable_pool.is_empty(): return null

	# If no encounter_config, fall back to unweighted random selection
	if not encounter_config:
		return affordable_pool.pick_random()

	# Build weighted selection based on tag weights
	return _pick_weighted_enemy(affordable_pool)


## Picks an enemy from the pool using EncounterConfig tag weights.
## Applies difficulty-based effectiveness multipliers if in EASY/HARD mode.
func _pick_weighted_enemy(pool: Array[EnemyStats]) -> EnemyStats:
	if pool.is_empty(): return null
	if not encounter_config:
		return pool.pick_random()

	# Calculate weights for each enemy
	var weighted_enemies: Array = []
	var total_weight = 0.0

	for enemy_stats in pool:
		var weight = encounter_config.calculate_enemy_weight(enemy_stats)

		# Apply difficulty-based effectiveness multipliers
		weight = _apply_difficulty_weight(weight, enemy_stats)

		total_weight += weight
		weighted_enemies.append({"stats": enemy_stats, "weight": weight})

	# If all weights are zero, fall back to random
	if total_weight <= 0:
		return pool.pick_random()

	# Weighted random selection
	var roll = randf() * total_weight
	var cumulative = 0.0
	for entry in weighted_enemies:
		cumulative += entry.weight
		if roll <= cumulative:
			return entry.stats

	return pool[0]

## Applies counter-mode weight adjustments using build analysis.
## EASY: Spawn more enemies the player counters (effectiveness > 1 = higher weight)
## HARD: Spawn more enemies that counter the player (effectiveness < 1 = higher weight)
func _apply_difficulty_weight(base_weight: float, enemy_stats: EnemyStats) -> float:
	# Skip if no counter adjustment or no build analysis
	if CurrentRun.counter_mode == CurrentRun.CounterMode.NORMAL:
		return base_weight
	if not build_analyzer:
		return base_weight

	# Get average effectiveness vs this enemy's behaviors
	var total_effectiveness = 0.0
	var behavior_count = 0
	for behavior in enemy_stats.behavior_tags:
		total_effectiveness += build_analyzer.get_effectiveness_vs_behavior(behavior)
		behavior_count += 1

	if behavior_count == 0:
		return base_weight

	var avg_effectiveness = total_effectiveness / behavior_count

	match CurrentRun.counter_mode:
		CurrentRun.CounterMode.EASY:
			# Higher effectiveness = spawn more (player is strong against this)
			# Scale: effectiveness 1.5 -> weight * 1.5, effectiveness 0.5 -> weight * 0.5
			return base_weight * avg_effectiveness
		CurrentRun.CounterMode.HARD:
			# Lower effectiveness = spawn more (player is weak against this)
			# Invert: effectiveness 0.5 -> weight * 2.0, effectiveness 2.0 -> weight * 0.5
			if avg_effectiveness > 0:
				return base_weight / avg_effectiveness
			return base_weight

	return base_weight

## Instantiates and positions a single enemy.
func spawn_enemy(stats: EnemyStats):
	var enemy_instance = enemy_scene.instantiate()

	# Pick a random size from the enemy's allowed sizes and apply scaling
	var scaled_stats = _apply_size_scaling(stats)
	enemy_instance.stats = scaled_stats.stats
	enemy_instance.spawned_size = scaled_stats.size

	var random_angle = randf_range(0, TAU)
	var spawn_offset = Vector2.RIGHT.rotated(random_angle) * spawn_radius
	var spawn_position = player_node.global_position + spawn_offset

	enemy_instance.global_position = spawn_position
	enemy_instance.scale *= scaled_stats.visual_scale
	get_tree().current_scene.add_child(enemy_instance)
	# Register with EntityRegistry for cached lookups
	EntityRegistry.register_enemy(enemy_instance)
	# Update ledger with enemy stats
	enemy_instance.died.connect(_on_enemy_died)
	_update_threat_ledger(stats, 1)

## Picks a size from the enemy's allowed sizes (weighted by EncounterConfig) and returns scaled stats.
## Returns a Dictionary with "stats" (duplicated & scaled), "size" (chosen size), "visual_scale" (float).
func _apply_size_scaling(base_stats: EnemyStats) -> Dictionary:
	# Pick size using EncounterConfig weights, or random if no config
	var chosen_size = EnemyTags.Size.MEDIUM
	if encounter_config:
		chosen_size = encounter_config.pick_weighted_size(base_stats)
	elif not base_stats.size_tags.is_empty():
		chosen_size = base_stats.size_tags.pick_random()

	var multipliers = EnemyTags.get_size_multipliers(chosen_size)

	# Duplicate stats to avoid modifying the shared resource
	var scaled_stats = base_stats.duplicate()

	# Apply multipliers
	scaled_stats.max_health = int(base_stats.max_health * multipliers.hp)
	scaled_stats.damage = int(base_stats.damage * multipliers.damage)
	scaled_stats.move_speed = base_stats.move_speed * multipliers.speed

	# Scale armor if enemy has any
	if base_stats.armor > 0:
		scaled_stats.armor = int(base_stats.armor * multipliers.armor_mult)

	# Scale challenge rating and XP based on size
	scaled_stats.challenge_rating = base_stats.challenge_rating * multipliers.xp

	return {
		"stats": scaled_stats,
		"size": chosen_size,
		"visual_scale": multipliers.scale
	}
	
## Signal handler for when any enemy dies.
func _on_enemy_died(enemy_stats: EnemyStats):
	_update_threat_ledger(enemy_stats, -1)
	
## Helper function to modify our internal threat tally using behavior tags.
func _update_threat_ledger(enemy_stats: EnemyStats, multiplier: int):
	# Track threat by behavior tags
	for tag in enemy_stats.behavior_tags:
		var current_cr = current_threat.get(tag, 0.0)
		var cr_change = enemy_stats.challenge_rating * multiplier
		current_threat[tag] = max(0.0, current_cr + cr_change)

func _on_timer_timeout() -> void:
	pass # Replace with function body.
