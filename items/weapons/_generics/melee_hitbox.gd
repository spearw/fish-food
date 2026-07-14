## melee_hitbox.gd
extends Area2D

var stats: ProjectileStats
var allegiance: Projectile.Allegiance
var user: Node2D  # Set by parent swing if available
var weapon: Node2D  # Set by parent swing if available

var pierce_count: int = 0
var hit_targets: Array = [] # Prevent hitting the same enemy twice in one swing


func _ready():
	# Configure collision based on allegiance (using CollisionUtils).
	if allegiance == Projectile.Allegiance.PLAYER:
		self.collision_mask = 1 << CollisionUtils.LAYER_ENEMY_BODY
	else:
		self.collision_mask = 1 << CollisionUtils.LAYER_PLAYER_BODY

	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D):
	if hit_targets.has(body): return # Already hit this target

	if body.has_method("take_damage"):
		# Roll for crit using DamageUtils.
		var crit_result = DamageUtils.roll_crit(stats.damage, stats.critical_hit_rate, stats.critical_hit_damage)
		var damage = crit_result["damage"]
		var is_crit = crit_result["is_crit"]

		var hit_details = {
			"enemy": body,
			"weapon": get_parent().weapon,
			"damage": damage,
			"position": body.global_position,
			"is_crit": is_crit
		}
		# Use batched hit queue instead of direct emit (reduces per-hit signal overhead)
		Events.queue_enemy_hit(hit_details)
		body.take_damage(damage, stats.armor_penetration, is_crit)
		hit_targets.append(body)

		if stats.knockback_force > 0 and body.has_method("apply_knockback"):
			body.apply_knockback(stats.knockback_force, get_parent().global_position)

		# SPARK Effect - Spawn sparks on hit
		# Also triggers if user has Conductive artifact (all weapons spark)
		var actual_user = user if is_instance_valid(user) else get_parent().user if "user" in get_parent() else null
		var has_conductive = is_instance_valid(actual_user) and actual_user.has_method("get_stat") and actual_user.get_stat("has_conductive") > 0
		if stats.has_effect(WeaponTags.Effect.SPARK) or has_conductive:
			_apply_spark_effect(body)

	if pierce_count != -1:
		pierce_count -= 1
		if pierce_count <= 0:
			$CollisionShape2D.disabled = true

## Spawns spark projectiles on hit.
func _apply_spark_effect(hit_body: Node2D):
	# Get user from parent swing if not set directly
	var actual_user = user if is_instance_valid(user) else get_parent().user if "user" in get_parent() else null
	var actual_weapon = weapon if is_instance_valid(weapon) else get_parent().weapon if "weapon" in get_parent() else null

	if not is_instance_valid(actual_user):
		return

	var spark_data = stats.get_effect_data(WeaponTags.Effect.SPARK)
	var spark_count = spark_data.get("spark_count", 1)
	var spark_damage = spark_data.get("spark_damage", 6)
	var spark_bounces = spark_data.get("spark_bounces", 3)
	var spark_range = spark_data.get("spark_range", 200.0)
	var spark_speed = spark_data.get("spark_speed", 600.0)
	var spark_lifetime = spark_data.get("spark_lifetime", 0.5)

	# Apply player bonuses
	if actual_user.has_method("get_stat"):
		spark_count += int(actual_user.get_stat("spark_count_bonus")) if actual_user.get_stat("spark_count_bonus") else 0
		var damage_mult = actual_user.get_stat("spark_damage_bonus") if actual_user.get_stat("spark_damage_bonus") else 1.0
		spark_damage = int(spark_damage * damage_mult)
		spark_bounces += int(actual_user.get_stat("spark_bounce_bonus")) if actual_user.get_stat("spark_bounce_bonus") else 0

	# Find enemies to target (excluding the one we just hit) -- bounded spatial query, not every enemy
	# on the map, matching the projectile spark path (projectile.gd _apply_spark_effect).
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
		_create_spark(hit_body.global_position, target_enemy, spark_damage, spark_bounces, spark_range, spark_speed, spark_lifetime, actual_user, actual_weapon)

func _create_spark(spawn_pos: Vector2, target_enemy: Node2D, dmg: int, bounces: int, range_val: float, spd: float, lifetime_val: float, spark_user: Node2D, spark_weapon: Node2D):
	var spark = ProjectilePool.get_spark()
	if spark == null:
		return  # over the concurrent-spark cap (pool returned null)

	spark.allegiance = SparkProjectile.Allegiance.PLAYER if allegiance == Projectile.Allegiance.PLAYER else SparkProjectile.Allegiance.ENEMY
	spark.user = spark_user
	spark.weapon = spark_weapon
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
