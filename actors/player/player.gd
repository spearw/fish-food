## player.gd
## Manages player state, including movement, stats, and unique abilities. Inherits from Entity.
extends Entity

# --- Player-Specific Signals ---
# The 'died' and 'health_changed' signals are inherited from the Entity class.
signal experience_changed(current_xp, required_xp)
signal leveled_up(new_level)
signal stats_changed
signal took_damage

# --- Node References ---
@onready var artifacts_node: Node = $Artifacts
@onready var proximity_detector: Area2D = $ProximityDetector
@onready var player_targeting_component = $TargetingComponent
@onready var player_fire_behavior_component = $FireBehaviorComponent
@onready var stats_panel: CanvasLayer = get_tree().get_root().get_node("World/StatsPanel")

# --- Runtime Variables ---
var upgrade_manager: Node
var is_invulnerable: bool = false
var level: int = 1
var current_experience: int = 0
var experience_to_next_level: int = 10
var last_move_direction: Vector2 = Vector2.RIGHT

# Dictionaries for tracking stat bonuses.
var in_run_bonuses: Dictionary = {}
var timed_bonuses: Dictionary = {}

# --- Cached Values (for performance) ---
var _cached_artifacts: Array = []  # Cached artifact list
var _cached_nearby_enemies: int = 0  # Cached proximity count
var _cached_move_speed: float = 0.0  # Cached move speed
var _stats_dirty: bool = true  # Flag to recalculate stats
var _proximity_update_timer: float = 0.0  # Timer for proximity updates
const PROXIMITY_UPDATE_INTERVAL: float = 0.1  # Update proximity every 100ms
var _artifacts_cache_connected: bool = false  # Track if artifact signals connected

# Dictionary for tracking unique, levelable powers.
var unlocked_powers: Dictionary = {}

# --- Unique Ability Flags ---
var can_redirect_projectiles: bool = false
var has_grounding: bool = false  # Allows chains to bounce through player
var grounding_damage_boost: float = 0.5  # Damage boost per player bounce (50%)

# Base values for unique powers, allowing for scaling.
var undaunted_knockback_base: float = 200.0
var whirlwind_speed_buff_base: float = 0.30
var whirlwind_duration_base: float = 2.0
var fof_speed_per_enemy_base: float = 0.01


## Initializes the player. The parent Entity's _ready() is called automatically first.
func _ready() -> void:
	# The parent _ready() handles the stats check and basic health initialization.
	super._ready()
	
	# Announce that the initial stats are ready for any UI elements.
	notify_stats_changed()

## Configures the player node using data from a PlayerStats resource.
## This is called by the World scene right after the player is instanced.
func initialize_character(character_data: PlayerStats, world_upgrade_manager: Node):
	upgrade_manager = world_upgrade_manager
	self.stats = character_data
		
	# Recalculate max_health using the get_stat method to include any permanent bonuses.
	# This overrides the initial value set by the parent Entity.
	self.max_health = get_stat("max_health")
	self.current_health = self.max_health
	self.scale = stats.scale
	animated_sprite.sprite_frames = stats.sprite_frames
	
	# Register with the UpgradeManager to handle leveling up.
	if is_instance_valid(upgrade_manager):
		upgrade_manager.register_player(self)
		
	# Grant the character's identity loadout. GRANTED: earned by being this character, not drafted,
	# so it never spends a loadout slot (the identity artifact must not be a tax -- design doc s3).
	if stats and stats.starting_upgrades:
		for upgrade_resource in stats.starting_upgrades:
			var upgrade_package = {
				"upgrade": upgrade_resource, "rarity": upgrade_resource.rarity, "granted": true }
			upgrade_manager.apply_upgrade(upgrade_package)


## Handles player input and movement every physics frame.
func _physics_process(delta: float) -> void:
	# Call the parent class's physics process to apply knockback decay. This is crucial.
	super._physics_process(delta)

	# Periodically update proximity count (expensive physics query)
	_proximity_update_timer += delta
	if _proximity_update_timer >= PROXIMITY_UPDATE_INTERVAL:
		_proximity_update_timer = 0.0
		_cached_nearby_enemies = proximity_detector.get_overlapping_bodies().size()
		# Proximity changes affect fight_or_flight, so mark move_speed dirty
		if unlocked_powers.has("fight_or_flight"):
			_stats_dirty = true

	# Recalculate cached move_speed if stats changed
	if _stats_dirty:
		_cached_move_speed = _calculate_move_speed()
		_stats_dirty = false

	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if direction.length() > 0:
		last_move_direction = direction.normalized()

	velocity = direction * _cached_move_speed
	# Add the (decaying) knockback velocity from the parent class.
	velocity += knockback_velocity

	move_and_slide()

# --- Overridden Base Class Methods ---

## Overrides the parent `take_damage` to add player-specific logic like invulnerability.
func take_damage(amount: int, armor_pen: float, is_crit: bool, source_node: Node = null) -> void:
	# Emit player_was_hit BEFORE checking invulnerability (for Surge Protector etc.)
	Events.player_was_hit.emit(source_node)

	if is_invulnerable:
		return

	# Call the parent method. It will handle the core logic: armor calculation,
	# health reduction, emitting 'health_changed', and calling our `_on_take_damage` hook.
	super.take_damage(amount, armor_pen, is_crit, source_node)

## This virtual method is called by the parent Entity's `take_damage` function
## AFTER health has been reduced. We use it for player-specific reactions to damage.
func _on_take_damage(damage_taken: int, is_crit: bool, source_node: Node) -> void:
	# If actual damage was taken, emit the signal for visual effects (e.g., screen flash).
	if damage_taken > 0:
		took_damage.emit()

	# Handle the "Undaunted" power: knock back the attacker.
	if unlocked_powers.has("undaunted") and source_node is Enemy:
		var undaunted_level = unlocked_powers["undaunted"]
		var final_knockback = undaunted_knockback_base * (1 + (0.5 * (undaunted_level - 1)))
		source_node.apply_knockback(final_knockback, self.global_position)
	
	# Handle the projectile redirection ability.
	if can_redirect_projectiles and source_node is Projectile:
		var redirect_direction = player_targeting_component.get_fire_direction(self.global_position, Vector2.RIGHT, Projectile.Allegiance.PLAYER)
		player_fire_behavior_component._spawn_projectile(source_node.stats, Projectile.Allegiance.PLAYER, redirect_direction, self.global_position, self)

## Overrides the parent `die` method to ensure player-specific signals are emitted.
func die() -> void:
	# Prevent this from running multiple times.
	if is_dying: return
	
	# Call the parent method. It will set the is_dying flag to true,
	# emit the base 'died' signal, and ultimately call queue_free().
	super.die()
	
# --- Player-Specific Stat and Ability Methods ---

## Adds a percentage-based bonus to the player's stat tracker for the current run.
func add_bonus(key: String, value: float, is_additive: bool=false):
	var current_bonus = in_run_bonuses.get(key, 0.0)
	in_run_bonuses[key] = current_bonus + value
	notify_stats_changed()

## Calculates the final multiplier for a given stat.
func get_stat_multiplier(key: String) -> float:
	var permanent_bonus = GameData.data["permanent_stats"].get(key, 0.0)
	# For stats where a lower number is better (e.g., cooldowns), we subtract from 1.
	if (key in ["firerate", "dot_damage_tick_rate"]):
		return max(0.1, 1.0 - (permanent_bonus + in_run_bonuses.get(key, 0.0)))
	else:
		return 1.0 + permanent_bonus + in_run_bonuses.get(key, 0.0)

## Internal helper to calculate move speed (uses cached values).
const ARMOR_SPEED_PENALTY: float = 0.01  # 1% speed reduction per armor point

func _calculate_move_speed() -> float:
	var move_speed = stats.move_speed * get_stat_multiplier("move_speed")

	# Apply armor speed penalty (~1% per armor point)
	var armor = get_stat("armor")
	if armor > 0:
		move_speed *= (1.0 - armor * ARMOR_SPEED_PENALTY)

	if unlocked_powers.has("fight_or_flight"):
		var fof_level = unlocked_powers["fight_or_flight"]
		var final_speed_per_enemy = fof_speed_per_enemy_base * (1 + (0.5 * (fof_level - 1)))
		var fof_bonus = 1.0 + (_cached_nearby_enemies * final_speed_per_enemy)
		move_speed *= fof_bonus
	for artifact in _cached_artifacts:
		if artifact.has_method("get_speed_modifier"):
			move_speed *= artifact.get_speed_modifier()
	return move_speed

## Returns the final, calculated value for any player stat, including all bonuses.
func get_stat(key: String):
	match key:
		"move_speed":
			# Return cached value for frequently-called move_speed
			if not _stats_dirty:
				return _cached_move_speed
			return _calculate_move_speed()
		"luck":
			var luck = stats.luck * get_stat_multiplier(key)
			for artifact in _cached_artifacts:
				if artifact.has_method("get_luck_modifier"):
					luck *= artifact.get_luck_modifier()
			return luck
		"critical_hit_rate":
			var crit_rate = stats.critical_chance * get_stat_multiplier(key)
			for artifact in _cached_artifacts:
				if artifact.has_method("get_crit_chance_modifier"):
					crit_rate *= artifact.get_crit_chance_modifier()
			return crit_rate
		"critical_hit_damage":
			var crit_dmg = stats.critical_damage * get_stat_multiplier(key)
			for artifact in _cached_artifacts:
				if artifact.has_method("get_crit_damage_modifier"):
					crit_dmg *= artifact.get_crit_damage_modifier()
			return crit_dmg
		"damage_increase":
			var damage = get_stat_multiplier(key)
			for artifact in _cached_artifacts:
				if artifact.has_method("get_damage_modifier"):
					damage *= artifact.get_damage_modifier()
			return damage
		"firerate":
			var firerate = get_stat_multiplier(key)
			for artifact in _cached_artifacts:
				if artifact.has_method("get_firerate_modifier"):
					firerate *= artifact.get_firerate_modifier()
			return firerate
		"projectile_speed":
			return get_stat_multiplier(key)
		"area_size":
			var area = get_stat_multiplier(key)
			for artifact in _cached_artifacts:
				if artifact.has_method("get_size_modifier"):
					area *= artifact.get_size_modifier()
			return area
		"size":
			var size = 1.0
			for artifact in _cached_artifacts:
				if artifact.has_method("get_size_modifier"):
					size *= artifact.get_size_modifier()
			return size
		"projectile_count_multiplier":
			return stats.projectile_count_multiplier * get_stat_multiplier(key)
		"armor":
			var permanent_bonus = GameData.data["permanent_stats"].get("armor", 0)
			var in_run_bonus = in_run_bonuses.get("armor", 0)
			var timed_bonus = timed_bonuses.get("armor", 0)
			var base_armor = stats.armor + permanent_bonus + in_run_bonus + timed_bonus
			for artifact in _cached_artifacts:
				if artifact.has_method("get_armor_modifier"):
					base_armor *= artifact.get_armor_modifier()
			return base_armor
		"max_health":
			var permanent_bonus = GameData.data["permanent_stats"].get("max_health", 0)
			var in_run_bonus = in_run_bonuses.get("max_health", 0)
			var base_health = stats.max_health + permanent_bonus + in_run_bonus
			for artifact in _cached_artifacts:
				if artifact.has_method("get_max_health_modifier"):
					base_health *= artifact.get_max_health_modifier()
			return base_health
		"dot_damage_bonus":
			return get_stat_multiplier(key)
		"dot_damage_tick_rate":
			return get_stat_multiplier(key)
		"status_chance_bonus":
			return get_stat_multiplier(key)
		"status_duration":
			return get_stat_multiplier(key)
		"xp_multiplier":
			return get_stat_multiplier(key)
		"pickup_radius":
			return stats.pickup_radius * get_stat_multiplier(key)
		"projectile_count":
			return get_stat_multiplier(key)
		"spark_count_bonus":
			return in_run_bonuses.get("spark_count_bonus", 0)
		"spark_damage_bonus":
			return 1.0 + in_run_bonuses.get("spark_damage_bonus", 0.0)
		"spark_bounce_bonus":
			return in_run_bonuses.get("spark_bounce_bonus", 0)
		_:
			printerr("get_stat: Requested unknown stat key: '", key, "'")
			return 1.0

## Returns the total additive projectile bonus from all artifacts (e.g., Tome of Duplication).
func get_artifact_projectile_bonus() -> int:
	var bonus = 0
	for artifact in _cached_artifacts:
		if artifact.has_method("get_projectile_bonus"):
			bonus += artifact.get_projectile_bonus()
	return bonus

## Adds experience to the player and handles leveling up.
func add_experience(amount: int, force_level = false) -> void:
	current_experience += amount
	experience_changed.emit(current_experience, experience_to_next_level)
	
	if current_experience >= experience_to_next_level or force_level:
		current_experience -= experience_to_next_level
		level += 1
		experience_to_next_level = int(experience_to_next_level * 1.2)
		leveled_up.emit(level)
		experience_changed.emit(current_experience, experience_to_next_level)
		
## Applies a temporary, flat bonus to a stat.
func apply_timed_bonus(stat_key: String, value: float, duration: float):
	var current_bonus = timed_bonuses.get(stat_key, 0.0)
	timed_bonuses[stat_key] = current_bonus + value

	# Use Callable.bind() instead of lambda to avoid signal memory leaks
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(remove_timed_bonus.bind(stat_key, value))

	notify_stats_changed()

## Removes a temporary bonus. Called by the timer from apply_timed_bonus.
func remove_timed_bonus(stat_key: String, value: float):
	var current_bonus = timed_bonuses.get(stat_key, 0.0)
	timed_bonuses[stat_key] = current_bonus - value
	notify_stats_changed()
		
## Emits the stats_changed signal and updates any visuals that depend on stats.
func notify_stats_changed():
	# Invalidate stat cache
	_stats_dirty = true

	# Connect to artifact child signals for automatic cache updates (once)
	if not _artifacts_cache_connected and is_instance_valid(artifacts_node):
		artifacts_node.child_entered_tree.connect(_on_artifact_added)
		artifacts_node.child_exiting_tree.connect(_on_artifact_removed)
		_artifacts_cache_connected = true
		# Initial cache build
		_cached_artifacts = artifacts_node.get_children()

	stats_changed.emit()
	# Area size affects both weapon AoE and pickup radius
	proximity_detector.scale.x = 1 * get_stat("area_size")
	proximity_detector.scale.y = 1 * get_stat("area_size")
	self.scale = Vector2.ONE * get_stat("size")

## Called when an artifact is added - updates cache incrementally.
func _on_artifact_added(node: Node):
	if node not in _cached_artifacts:
		_cached_artifacts.append(node)
	_stats_dirty = true

## Called when an artifact is removed - updates cache incrementally.
func _on_artifact_removed(node: Node):
	_cached_artifacts.erase(node)
	_stats_dirty = true
	
## Sets the player's invulnerability state.
func set_invulnerability(active: bool):
	is_invulnerable = active
	animated_sprite.modulate.a = 0.5 if active else 1.0
		
## Activates or deactivates the projectile redirection ability.
func set_redirect_ability(can_redirect: bool):
	can_redirect_projectiles = can_redirect

## Activates or deactivates the grounding ability (chains bounce through player).
func set_grounding_ability(active: bool):
	has_grounding = active

## Finds a power by its key, adds levels to it, and initializes it if it's new.
func add_power_level(power_key: String, levels_to_add: int):
	var current_level = unlocked_powers.get(power_key, 0)
	
	if current_level == 0:
		_unlock_power(power_key)

	unlocked_powers[power_key] = current_level + levels_to_add
	notify_stats_changed()

## A private helper to handle one-time setup for new powers.
func _unlock_power(power_key: String):
	if power_key == "whirlwind":
		# Connect to the global event bus to gain buffs on enemy kills.
		Events.enemy_killed.connect(_on_enemy_killed)

# --- Build Analysis Methods (for counter-spawning) ---

## Returns all equipped weapons for build analysis.
func get_weapons() -> Array:
	if has_node("Equipment"):
		return get_node("Equipment").get_children()
	return []

## Returns all equipped artifacts for build analysis.
func get_artifacts() -> Array:
	return _cached_artifacts

# --- Signal Callbacks ---

## Triggered by the "whirlwind" power when an enemy is killed.
func _on_enemy_killed(enemy: Node): 
	if unlocked_powers.has("whirlwind"):
		var whirlwind_level = unlocked_powers["whirlwind"]
		var speed_buff = whirlwind_speed_buff_base * (1 + (0.5 * (whirlwind_level - 1)))
		var attack_speed_buff = whirlwind_speed_buff_base * (1 + (0.5 * (whirlwind_level - 1)))
		var duration = whirlwind_duration_base
		apply_timed_bonus("move_speed", speed_buff, duration)
		apply_timed_bonus("firerate", attack_speed_buff, duration)
