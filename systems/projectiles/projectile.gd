## projectile.gd
## A generic projectile. Its behavior is configured by a ProjectileStats resource.
class_name Projectile
extends Node2D

# --- Allegiance ---
enum Allegiance { PLAYER, ENEMY, NONE }
var allegiance: Allegiance

# --- Public Properties ---
var stats: ProjectileStats
var direction: Vector2 = Vector2.RIGHT
var pierce_count: int = 0
var weapon: Node2D
var user: Node2D
var has_redirected: bool = false
## Damage-report identity ("Daggers"): set by FireBehaviorComponent from the owning weapon each
## fire; inherited by everything this projectile causes (sparks, explosions, statuses, zones).
var attribution_key: String = ""

# --- Calculated Values ---
var damage: float = 0.0
var critical_hit_rate: float = 0.0
var critical_hit_damage: float = 0.0
var speed: float = 0.0
var knockback: float = 0.0
var target: Node2D = null
var proximity_detector: Area2D
var status_chance = 0.0
var _spatial_hit_radius: float = 16.0  # used when stats.use_spatial_hits

# --- Pooling Support ---
var _is_pooled: bool = false  # Track if this projectile came from pool
var _signals_connected: bool = false  # Track signal state for pooling
var _is_destroying: bool = false  # Prevent double-destruction

# --- Node References ---
@onready var sprite: Sprite2D = $Area2D/Sprite2D
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var lifetime_timer: Timer = $LifetimeTimer
@onready var area2d: Area2D = $Area2D

func _ready():
	# For pooled projectiles, initialization happens in activate()
	if _is_pooled:
		return

	_initialize()

## Activate a pooled projectile (called instead of _ready for reused projectiles)
func activate():
	_is_pooled = true
	_is_destroying = false
	# Re-enable collision for reused projectiles
	if area2d:
		area2d.monitoring = true
		area2d.monitorable = true
	_initialize()

func _initialize():
	# Guard clause: If stats are missing, this projectile can't function.
	if not stats:
		printerr("Projectile spawned without stats! Deleting.")
		_destroy()
		return
	if not allegiance in Projectile.Allegiance.values():
		printerr("Projectile spawned without a valid allegiance! Deleting.")
		_destroy()
		return

	_calculate_stats()
	pierce_count = stats.pierce + 1 if stats.pierce != -1 else -1

	# Configure visuals from stats.
	sprite.texture = stats.texture
	sprite.scale = stats.scale

	if stats.use_spatial_hits:
		# Cheap-placeholder path: keep the Area2D out of the physics broadphase; hit via the grid.
		area2d.monitoring = false
		area2d.monitorable = false
		var sz := (sprite.texture.get_size() * sprite.scale.abs()) if sprite.texture else Vector2(16, 16)
		_spatial_hit_radius = maxf(sz.x, sz.y) * 0.5 + 8.0
	else:
		generate_hitbox_from_sprite()
		# Configure physics based on allegiance (using CollisionUtils).
		CollisionUtils.set_projectile_collision(self.area2d, allegiance)

	# This is a normal moving projectile.
	_intialize_as_bullet()
	# Check if it's a retargeting projectile
	if stats.can_retarget:
		# We connect to the global signal that announces any enemy's death.
		Events.enemy_killed.connect(_on_any_enemy_killed)
	# Check if it's a phasing projectile
	if stats.is_phasing:
		_apply_phasing()

func _intialize_as_bullet():
	# Configure lifetime.
	if stats.lifetime > 0:
		lifetime_timer.wait_time = stats.lifetime
		lifetime_timer.one_shot = true
		# Only connect if not already connected (for pooled projectiles)
		if not lifetime_timer.timeout.is_connected(_destroy):
			lifetime_timer.timeout.connect(_destroy)
		lifetime_timer.start()

	# Connect the damage signal (only if not already connected). Spatial-hit projectiles
	# don't use the Area2D at all.
	if not stats.use_spatial_hits and not _signals_connected:
		self.area2d.body_entered.connect(_on_body_entered)
		_signals_connected = true

## Generates and assigns a collision shape based on the sprite's current texture and scale.
func generate_hitbox_from_sprite():

	# If user is player and the projectile is scaling, apply stat bonuses.
	var size_multiplier = 1
	if stats.is_scaling and user.is_in_group("player"):
		size_multiplier *= user.get_stat("area_size")

	if not sprite.texture:
		printerr("Cannot generate hitbox: sprite has no texture.")
		return

	# Create a new rectangle shape resource.
	var new_shape = RectangleShape2D.new()

	# Set the rectangle's size. Get the texture's size and multiply by the sprite's scale.
	sprite.scale = sprite.scale.abs() * size_multiplier
	new_shape.size = sprite.texture.get_size() * sprite.scale.abs()


	# Assign the newly created and sized shape to our CollisionShape2D node.
	collision_shape.shape = new_shape
	collision_shape.position = sprite.position

func _process(delta: float):
	if stats.homing_strength > 0 and is_instance_valid(target):
		var direction_to_target = (target.global_position - self.global_position).normalized()
		# Rotate the current direction towards the target direction.
		direction = direction.lerp(direction_to_target, stats.homing_strength * delta)
		# Update visual rotation to match the new direction.
		self.rotation = direction.angle()
	global_position += direction * stats.speed * delta
	if stats.use_spatial_hits:
		_check_spatial_hits()

## Off-broadphase hit detection via the shared spatial-hash scan (no physics broadphase). Hits every
## enemy in range (pierce is handled downstream in _on_body_entered). Mirrors the scan used by
## SparkProjectile -- both go through EntityRegistry.get_enemies_within so the query lives in one place.
func _check_spatial_hits() -> void:
	if _is_destroying:
		return
	if CollisionUtils.get_target_group(allegiance) != "enemies":
		return  # grid is enemy-only; enemy projectiles keep the Area2D path
	for body in EntityRegistry.get_enemies_within(global_position, _spatial_hit_radius):
		if _is_destroying:
			return
		_on_body_entered(body)

func _on_body_entered(body: Node2D):
	# Hit Logic - check if this body is a valid target for our allegiance.
	var target_group = CollisionUtils.get_target_group(allegiance)
	if not body.is_in_group(target_group):
		return

	# Valid target found - apply damage and knockback.
	var damage_dealt = 0.0
	if body.has_method("take_damage"):
		damage_dealt = _deal_damage(body)

	# Apply effect tags (pass damage dealt for lifesteal)
	_apply_effect_tags(body, damage_dealt)

	# Legacy status effect application (for backwards compatibility)
	if stats.status_to_apply and body.has_node("StatusEffectManager"):
		_apply_status(body)
	if stats.knockback_force > 0 and body.has_method("apply_knockback"):
		body.apply_knockback(stats.knockback_force, self.global_position)

	# Decrement pierce_count
	if pierce_count != -1: # Do nothing if pierce is infinite
		pierce_count -= 1
		if pierce_count <= 0:
			_destroy()

func _deal_damage(body: Node2D) -> float:
	var final_damage = damage
	var is_crit = false

	# Apply critical hit (check CRIT_BOOST effect for bonus)
	var crit_rate = critical_hit_rate
	var crit_damage = critical_hit_damage
	if stats.has_effect(WeaponTags.Effect.CRIT_BOOST):
		var crit_data = stats.get_effect_data(WeaponTags.Effect.CRIT_BOOST)
		crit_rate += crit_data.get("crit_chance_bonus", 0.0)
		crit_damage += crit_data.get("crit_damage_bonus", 0.0)

	if randf() < crit_rate:
		final_damage = damage * crit_damage
		is_crit = true

	# Apply tag bonus damage vs enemy types
	final_damage *= _calculate_tag_bonus(body)

	# Apply ARMOR_PEN effect for bonus penetration
	var armor_pen = stats.armor_penetration
	if stats.has_effect(WeaponTags.Effect.ARMOR_PEN):
		var pen_data = stats.get_effect_data(WeaponTags.Effect.ARMOR_PEN)
		armor_pen = min(1.0, armor_pen + pen_data.get("penetration", 0.0))

	body.take_damage(final_damage, armor_pen, is_crit, self)
	return final_damage  # Return for lifesteal calculation

## Calculates bonus damage multiplier based on target's type tags.
func _calculate_tag_bonus(target: Node2D) -> float:
	if stats.bonus_vs_types.is_empty():
		return 1.0

	if not target.stats or not target.stats.type_tags:
		return 1.0

	var bonus = 1.0
	for tag in target.stats.type_tags:
		if tag in stats.bonus_vs_types:
			bonus += stats.bonus_vs_types[tag]

	return bonus

func _apply_status(body: Node2D):
	var status_manager = body.get_node("StatusEffectManager")
	status_manager.apply_status(stats.status_to_apply, user, attribution_key)

## Applies effect tag behaviors (DOT, SLOW, LIFESTEAL, etc.)
func _apply_effect_tags(body: Node2D, damage_dealt: float):
	if stats.effects.is_empty():
		return

	# Check status chance (affects DOT and SLOW application)
	var apply_status_effects = randf() < status_chance

	# DOT Effect - Apply damage over time
	if apply_status_effects and stats.has_effect(WeaponTags.Effect.DOT):
		_apply_dot_effect(body)

	# SLOW Effect - Reduce movement speed
	if apply_status_effects and stats.has_effect(WeaponTags.Effect.SLOW):
		_apply_slow_effect(body)

	# LIFESTEAL Effect - Heal user based on damage dealt
	if stats.has_effect(WeaponTags.Effect.LIFESTEAL) and damage_dealt > 0:
		_apply_lifesteal_effect(damage_dealt)

	# SPARK Effect - Spawn spark projectiles on hit
	# Also triggers if user has Conductive artifact (all weapons spark)
	var has_conductive = is_instance_valid(user) and user.has_method("get_stat") and user.get_stat("has_conductive") > 0
	if stats.has_effect(WeaponTags.Effect.SPARK) or has_conductive:
		_apply_spark_effect(body)

## Creates and applies a DOT status effect based on registry data.
func _apply_dot_effect(body: Node2D):
	if not body.has_node("StatusEffectManager"):
		return

	var dot_data = stats.get_effect_data(WeaponTags.Effect.DOT)

	# Create a DotStatusEffect instance with registry values
	var dot_effect = DotStatusEffect.new()
	dot_effect.id = "effect_dot"  # Standard ID for tag-based DOT
	dot_effect.damage_per_tick = dot_data.get("damage_per_tick", 3.0)
	dot_effect.time_between_ticks = dot_data.get("tick_rate", 0.5)
	dot_effect.duration = dot_data.get("duration", 3.0)
	dot_effect.modulate_color = Color(1.0, 0.6, 0.3)  # Orange tint for DOT

	var status_manager = body.get_node("StatusEffectManager")
	status_manager.apply_status(dot_effect, user, attribution_key)

## Creates and applies a SLOW status effect based on registry data.
func _apply_slow_effect(body: Node2D):
	if not body.has_node("StatusEffectManager"):
		return

	var slow_data = stats.get_effect_data(WeaponTags.Effect.SLOW)

	# Create a SlowStatusEffect instance with registry values
	var slow_effect = SlowStatusEffect.new()
	slow_effect.id = "effect_slow"  # Standard ID for tag-based slow
	slow_effect.slow_percent = slow_data.get("slow_percent", 0.3)
	slow_effect.duration = slow_data.get("duration", 2.0)
	slow_effect.modulate_color = Color(0.5, 0.7, 1.0)  # Blue tint for slow

	var status_manager = body.get_node("StatusEffectManager")
	status_manager.apply_status(slow_effect, user, attribution_key)

## Heals the user based on damage dealt.
func _apply_lifesteal_effect(damage_dealt: float):
	if not is_instance_valid(user) or not user.has_method("heal"):
		return

	var lifesteal_data = stats.get_effect_data(WeaponTags.Effect.LIFESTEAL)
	var heal_percent = lifesteal_data.get("percent", 0.1)
	var heal_amount = int(damage_dealt * heal_percent)

	if heal_amount > 0:
		user.heal(heal_amount)

## Spawns spark projectiles on hit.
func _apply_spark_effect(hit_body: Node2D):
	if not is_instance_valid(user):
		return

	var spark_data = stats.get_effect_data(WeaponTags.Effect.SPARK)
	var spark_count = spark_data.get("spark_count", 1)
	var spark_damage = spark_data.get("spark_damage", 6)
	var spark_bounces = spark_data.get("spark_bounces", 3)
	var spark_range = spark_data.get("spark_range", 200.0)
	var spark_speed = spark_data.get("spark_speed", 600.0)
	var spark_lifetime = spark_data.get("spark_lifetime", 0.5)

	# Apply player bonuses
	if user.has_method("get_stat"):
		spark_count += int(user.get_stat("spark_count_bonus")) if user.get_stat("spark_count_bonus") else 0
		var damage_mult = user.get_stat("spark_damage_bonus") if user.get_stat("spark_damage_bonus") else 1.0
		spark_damage = int(spark_damage * damage_mult)
		spark_bounces += int(user.get_stat("spark_bounce_bonus")) if user.get_stat("spark_bounce_bonus") else 0

	# Find enemies to target (excluding the one we just hit) -- spatial-hash query, not all enemies.
	var candidates = EntityRegistry.get_candidates_near("enemies", hit_body.global_position, spark_range)
	candidates = candidates.filter(func(c): return c != hit_body and is_instance_valid(c))

	# Sort by distance to find closest targets
	if not candidates.is_empty():
		var hit_pos = hit_body.global_position
		candidates.sort_custom(func(a, b):
			return hit_pos.distance_squared_to(a.global_position) < hit_pos.distance_squared_to(b.global_position)
		)

	# Spawn sparks
	for i in range(spark_count):
		var target_enemy = candidates[i % candidates.size()] if not candidates.is_empty() else null
		_create_spark(hit_body.global_position, target_enemy, spark_damage, spark_bounces, spark_range, spark_speed, spark_lifetime)

func _create_spark(spawn_pos: Vector2, target_enemy: Node2D, dmg: int, bounces: int, range_val: float, spd: float, lifetime_val: float):
	var spark = ProjectilePool.get_spark()
	if spark == null:
		return  # over the concurrent-spark cap

	spark.allegiance = SparkProjectile.Allegiance.PLAYER if allegiance == Allegiance.PLAYER else SparkProjectile.Allegiance.ENEMY
	spark.user = user
	spark.weapon = weapon
	spark.attribution_key = attribution_key
	spark.target = target_enemy
	spark.base_damage = dmg
	spark.bounce_count = bounces
	spark.bounces_remaining = bounces
	spark.bounce_range = range_val
	spark.speed = spd
	spark.lifetime = lifetime_val

	spark.global_position = spawn_pos

	# Aim at target if we have one, otherwise random direction
	if is_instance_valid(target_enemy):
		spark.direction = (target_enemy.global_position - spawn_pos).normalized()
	else:
		var random_angle = randf() * TAU
		spark.direction = Vector2.from_angle(random_angle)
	spark.rotation = spark.direction.angle()

	get_tree().current_scene.add_child(spark)

## Calculates all final stats by querying the weapon's user.
func _calculate_stats():
	# Use DamageUtils to centralize stat scaling logic.
	var scaled = DamageUtils.scale_all_projectile_stats(stats, user)
	damage = scaled["damage"]
	critical_hit_rate = scaled["crit_rate"]
	critical_hit_damage = scaled["crit_damage"]
	speed = scaled["speed"]
	status_chance = scaled["status_chance"]
	knockback = stats.knockback_force


func _apply_phasing():
	# Start with the main hitbox disabled.
	CollisionUtils.disable_collision(area2d)

	# Create and configure a small proximity detector.
	proximity_detector = Area2D.new()
	var proximity_shape = CircleShape2D.new()
	proximity_shape.radius = 30 # Small radius
	var proximity_collider = CollisionShape2D.new()
	proximity_collider.shape = proximity_shape
	proximity_detector.add_child(proximity_collider)

	# The detector only needs to look for potential targets.
	proximity_detector.collision_mask = 1 << CollisionUtils.LAYER_ENEMY_BODY if allegiance == Allegiance.PLAYER else 1 << CollisionUtils.LAYER_PLAYER_BODY

	proximity_detector.body_entered.connect(_on_proximity_detected)
	add_child(proximity_detector)

func _on_proximity_detected(body: Node2D):
	# When any enemy enters our proximity, check if it's the specific target.
	if body == self.target:
		# Re-enable our main hitbox and destroy the detector.
		print("Seeker missile arming!")
		CollisionUtils.set_projectile_collision(area2d, allegiance)
		proximity_detector.queue_free()

func _destroy():
	# Prevent double-destruction (can happen if projectile hits multiple enemies before cleanup)
	if _is_destroying:
		return
	_is_destroying = true

	# Disable collision immediately to prevent further physics callbacks
	if area2d:
		area2d.set_deferred("monitoring", false)
		area2d.set_deferred("monitorable", false)

	# Disconnect from global signals to prevent memory leaks
	if stats and stats.can_retarget and Events.enemy_killed.is_connected(_on_any_enemy_killed):
		Events.enemy_killed.disconnect(_on_any_enemy_killed)

	# Stop the lifetime timer
	if lifetime_timer:
		lifetime_timer.stop()

	# Clean up phasing proximity detector if it exists
	if is_instance_valid(proximity_detector):
		proximity_detector.queue_free()
		proximity_detector = null

	# Only pool simple projectiles (no phasing, no retargeting - they have extra state)
	# Pool handles deferred removal internally, safe to call during physics callbacks
	if _is_pooled and stats and not stats.can_retarget and not stats.is_phasing:
		# Reset state for reuse
		target = null
		has_redirected = false
		ProjectilePool.return_projectile(self)
	else:
		# A POOLED projectile that became unpoolable (a retarget/phasing evolution) still holds a
		# generic-cap slot -- release it, or the counter leaks one per shot until the cap silences
		# every pooled weapon in the game (player and enemy ranged alike).
		if _is_pooled:
			ProjectilePool.abandon_generic(self)
		call_deferred("queue_free")

## Called by the global "enemy_killed" signal.
func _on_any_enemy_killed():
	# This function runs when ANY enemy on the screen dies.

	# First, check if our own target is the one that just died or is now invalid.
	if not is_instance_valid(target) or target.is_dying:
		# Find a new target.
		var target_group
		if allegiance == Allegiance.PLAYER:
			target_group = "enemies"
		else:
			target_group = "player"
		var candidates = TargetingUtils.get_candidates(target_group)
		var new_target = TargetingUtils.find_nearest(self.global_position, candidates)
		if is_instance_valid(new_target):
			print("Living Flame is re-targeting!")
			self.target = new_target
