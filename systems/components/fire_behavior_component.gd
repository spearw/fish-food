## fire_behavior_component.gd
## A component that defines HOW a weapon fires its projectiles.
class_name FireBehaviorComponent
extends Node

# --- Define the different ways a weapon can fire ---
enum FirePattern {
	FORWARD,      # Fires all projectiles in a single targeted direction with optional spread
	NOVA,         # Fires all projectiles in an even arc without aim.
	AIMED_AOE,    # Spawns exactly on targeted enemy with variable delay
	MIRRORED_FORWARD, # Like forward but also creates projectile at 180 degrees.
	RANDOM, 		# Randomly targets for each projectile.
	CONE, 		# Fires all projectiles in a set cone towards a target.
}
enum SpawnLocation {
	IN_WORLD,  # For normal, independent projectiles (bullets, fireballs).
	ON_USER    # For attached effects (melee swings, auras).
}

# --- Configurable Properties ---
@export var base_pattern: FirePattern = FirePattern.FORWARD
@export var spawn_location: SpawnLocation = SpawnLocation.IN_WORLD
@export var spread_angle_degrees: float = 30.0 # Only used for SPREAD pattern
@export var burst_delay: float = 0.08 # Delay between shots in a burst
var burst_delay_timer: Timer  # Optional child timer for burst fire

# Only for AoE attacks
@export var aoe_warning_scene: PackedScene
@export var aoe_delay: float = 1.0
var aoe_delay_timer: Timer  # Optional child timer for AoE

# --- References (set at runtime) ---
var weapon # The parent weapon node
const GENERIC_PROJECTILE_SCENE = preload("res://systems/projectiles/projectile.tscn")
var stats_comp: WeaponStatsComponent;
var targeting_comp: TargetingComponent;
var pattern_override = -1 # -1 means no override
var fire_pattern = -1
var current_fire_pattern = -1
var additional_multiplier = 1
var _current_scene: Node  # Cached reference to avoid tree queries


func _ready():
	weapon = get_parent()
	# Optional sibling components (may not exist when attached to Player)
	stats_comp = weapon.get_node_or_null("WeaponStatsComponent")
	targeting_comp = weapon.get_node_or_null("TargetingComponent")
	# Optional child timers (may not exist when attached to Player)
	burst_delay_timer = get_node_or_null("BurstDelayTimer")
	aoe_delay_timer = get_node_or_null("AoeDelayTimer")
	fire_pattern = base_pattern
	# Cache the current scene reference to avoid tree queries during fire
	_current_scene = get_tree().current_scene

## The main public method called by the weapon's timer or AI.
func fire(damage_multiplier=1):
	additional_multiplier = damage_multiplier
	if not is_instance_valid(weapon): return
	
	if not stats_comp or not targeting_comp:
		printerr("FireBehaviorComponent on '%s' is missing required components!" % weapon.name)
		return
		
	var final_projectile_count = stats_comp.get_final_projectile_count()
	var allegiance = stats_comp.get_projectile_allegiance()
	var projectile_stats = weapon.projectile_stats
	
	current_fire_pattern = fire_pattern
	if pattern_override != -1:
		current_fire_pattern = pattern_override # Or use the override
		pattern_override = -1 # Reset override
	
	# --- Main Firing Logic ---
	match current_fire_pattern:
		FirePattern.FORWARD, FirePattern.MIRRORED_FORWARD, FirePattern.RANDOM:
			_execute_burst_fire(final_projectile_count, projectile_stats, allegiance, targeting_comp)
		FirePattern.NOVA:
			_execute_nova_fire(final_projectile_count, projectile_stats, allegiance)
		FirePattern.CONE:
			_execute_cone_fire(final_projectile_count, projectile_stats, allegiance, targeting_comp)
		FirePattern.AIMED_AOE:
			# For AoE, the "projectile count" is how many meteors we drop.
			for i in range(final_projectile_count):
				# Get a target position. We can reuse our targeting component!
				# Find a target, but default to a random position near the owner if none are found.
				var target_node = targeting_comp.find_target(weapon.global_position, allegiance)
				if not target_node:
					return
				var target_position = weapon.global_position + Vector2(randf_range(-150, 150), randf_range(-150, 150))
								
				if is_instance_valid(target_node):
					target_position = target_node.global_position
					
				_execute_aoe_strike(target_position, projectile_stats, allegiance)

## Helper function to handle the actual creation of a single projectile.
func _spawn_projectile(
		projectile_stats: ProjectileStats,
		projectile_allegiance: Projectile.Allegiance,
		projectile_direction: Vector2,
		p_position: Vector2 = weapon.global_position,
		user_override: Node2D = null,
		projectile_target = null,
		):
	# The weapon is attached to the user, so its global_position is the user's position.
	var spawn_position = weapon.global_position

	# Check for custom scene
	var projectile_scene = GENERIC_PROJECTILE_SCENE
	var use_custom_scene = "custom_projectile_scene" in weapon and weapon.custom_projectile_scene
	if use_custom_scene:
		projectile_scene = weapon.custom_projectile_scene

	# Use pool for generic projectiles, instantiate for custom scenes
	var projectile: Node
	var from_pool = false
	if not use_custom_scene:
		projectile = ProjectilePool.get_projectile(projectile_scene)
		if projectile == null:
			return  # over the concurrent generic-projectile cap
		from_pool = projectile._is_pooled if projectile.get("_is_pooled") != null else false
	else:
		projectile = projectile_scene.instantiate()

	projectile.stats = projectile_stats
	projectile.direction = projectile_direction
	projectile.allegiance = projectile_allegiance
	projectile.weapon = weapon
	projectile.target = projectile_target

	# Determine projectile's user
	var user
	if user_override:
		user = user_override
	elif stats_comp:
		user = stats_comp.user
	else:
		user = weapon  # Fallback when no stats_comp (e.g., player)
	projectile.user = user

	match spawn_location:
		SpawnLocation.IN_WORLD:
			# The old logic: spawn in the main world.
			projectile.direction = projectile_direction
			_current_scene.add_child(projectile)
			projectile.global_position = spawn_position
			projectile.rotation = projectile_direction.angle()

		SpawnLocation.ON_USER:
			# The new logic: spawn as a child of the user.
			user.add_child(projectile)
			# Its position will be (0,0) relative to the user, which is correct.
			projectile.position = Vector2.ZERO
			# The swing's rotation is set relative to the user's facing direction.
			projectile.rotation = projectile_direction.angle()

	# For pooled projectiles, call activate() after adding to scene
	if from_pool and projectile.has_method("activate"):
		projectile.activate()
	elif not from_pool and not use_custom_scene:
		# Mark new projectiles as poolable for future reuse
		projectile._is_pooled = true

# This is a public function the weapon script can now call to override the pattern for a single shot.
func override_pattern_for_next_shot(new_pattern: FirePattern):
	pattern_override = new_pattern

func _execute_burst_fire(p_count: int, p_stats: ProjectileStats, p_allegiance: Projectile.Allegiance, targeting_comp: TargetingComponent):
	var final_projectile_count = stats_comp.get_final_projectile_count()
	# Get a target from the targeting component.
	var target = targeting_comp.find_target(weapon.global_position, p_allegiance)
	if not target:
		return
	var base_direction = (target.global_position - weapon.global_position).normalized()

	# If the pattern is MIRRORED_FORWARD, it doubles the current projectile count (to fire behind).
	if current_fire_pattern == FirePattern.MIRRORED_FORWARD:
		final_projectile_count *= 2

	# Pre-fetch targets for RANDOM mode to avoid per-projectile queries
	var prefetched_targets: Array = []
	if current_fire_pattern == FirePattern.RANDOM:
		prefetched_targets = targeting_comp.find_multiple_targets(weapon.global_position, p_allegiance, final_projectile_count)
		if prefetched_targets.is_empty():
			return

	for i in range(final_projectile_count):
		var fire_direction = base_direction
		if current_fire_pattern == FirePattern.RANDOM:
			# Use prefetched target (cycle through if fewer targets than projectiles)
			if prefetched_targets.size() > 0:
				var target_idx = i % prefetched_targets.size()
				target = prefetched_targets[target_idx]
				if is_instance_valid(target):
					fire_direction = (target.global_position - weapon.global_position).normalized()
				else:
					continue
		elif not is_instance_valid(target):
			# Fallback: find new target if current became invalid
			target = targeting_comp.find_target(weapon.global_position, p_allegiance)
			if not target:
				return
			base_direction = (target.global_position - weapon.global_position).normalized()
		if current_fire_pattern == FirePattern.FORWARD or current_fire_pattern == FirePattern.MIRRORED_FORWARD:
			fire_direction = base_direction.rotated(
				deg_to_rad(randf_range(-spread_angle_degrees / 2.0, spread_angle_degrees / 2.0))
			)
		var should_delay = true
		if current_fire_pattern == FirePattern.MIRRORED_FORWARD:
			# Fire behind every odd shot (index 1, 3, etc.)
			if i % 2 == 1:
				fire_direction = fire_direction.rotated(PI)
			if i % 2 == 0:
				should_delay = false

		_spawn_projectile(p_stats, p_allegiance, fire_direction, weapon.global_position, null, target)

		# Delay burst (only if timer exists)
		if i < final_projectile_count - 1 and burst_delay > 0 and should_delay and burst_delay_timer:
			burst_delay_timer.wait_time = burst_delay
			burst_delay_timer.start()
			await burst_delay_timer.timeout


	weapon.last_fire_direction = base_direction
	
func _execute_nova_fire(p_count: int, p_stats: ProjectileStats, p_allegiance: Projectile.Allegiance):
	var angle_step = TAU / p_count
	for i in range(p_count):
		var fire_direction = Vector2.RIGHT.rotated(angle_step * i)
		_spawn_projectile(p_stats, p_allegiance, fire_direction)

		# Add burst delay to NOVA for a ripple effect (only if timer exists).
		if i < p_count - 1 and burst_delay > 0 and burst_delay_timer:
			burst_delay_timer.wait_time = burst_delay
			burst_delay_timer.start()
			await burst_delay_timer.timeout
			
func _execute_cone_fire(p_count: int, p_stats: ProjectileStats, p_allegiance: Projectile.Allegiance, targeting_comp: TargetingComponent):
	# Get a single base direction from the targeting component.
	var base_direction = targeting_comp.get_fire_direction(weapon.global_position, weapon.last_fire_direction, p_allegiance)
	var final_projectile_count = stats_comp.get_final_projectile_count()
	# Projectile angle is 45 degrees / projectile count
	var angle_step = PI / 4 / p_count
	for i in range(p_count):
		# Projectile arc is -22.5 degrees + current step value evenly spaced
		var fire_direction = base_direction.rotated(-(PI/8) + (angle_step * i))
		_spawn_projectile(p_stats, p_allegiance, fire_direction)
	
## Handles the sequence for a single AoE strike.
func _execute_aoe_strike(target_pos: Vector2, p_stats: ProjectileStats, p_allegiance: Projectile.Allegiance):
	# Spawn the warning indicator.
	if aoe_warning_scene:
		var warning = aoe_warning_scene.instantiate()
		_current_scene.add_child(warning)
		warning.global_position = target_pos

	# Wait for AoE delay (only if timer exists).
	if aoe_delay_timer:
		aoe_delay_timer.wait_time = aoe_delay
		aoe_delay_timer.start()
		await aoe_delay_timer.timeout

	# Spawn the configured "projectile" that will act as the explosion.
	_spawn_projectile(p_stats, p_allegiance, Vector2.ZERO, target_pos)
