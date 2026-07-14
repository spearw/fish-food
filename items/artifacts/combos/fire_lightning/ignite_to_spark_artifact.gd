## ignite_to_spark_artifact.gd
## Fire + Lightning combo synergy (GENERATION): when an enemy is ignited, spawn a spark from it.
## Your fire investment (more ignites) feeds your lightning; scales with spark stats.
class_name IgniteToSparkArtifact
extends ArtifactBase

func on_equipped() -> void:
	if not Events.status_applied_to_enemy.is_connected(_on_status_applied):
		Events.status_applied_to_enemy.connect(_on_status_applied)

func on_unequipped() -> void:
	if Events.status_applied_to_enemy.is_connected(_on_status_applied):
		Events.status_applied_to_enemy.disconnect(_on_status_applied)

func _on_status_applied(enemy_node: Node, status_id: String) -> void:
	if status_id != "ignited" or not is_instance_valid(enemy_node) or not is_instance_valid(user):
		return

	var spark_data = WeaponTagRegistry.get_effect_data(WeaponTags.Effect.SPARK, {})
	var dmg := int(spark_data.get("spark_damage", 6))
	var bounces := int(spark_data.get("spark_bounces", 3))
	var range_val: float = spark_data.get("spark_range", 200.0)
	var speed: float = spark_data.get("spark_speed", 600.0)
	var lifetime: float = spark_data.get("spark_lifetime", 0.5)
	if user.has_method("get_stat"):
		var dmg_mult = user.get_stat("spark_damage_bonus") if user.get_stat("spark_damage_bonus") else 1.0
		dmg = int(dmg * dmg_mult)
		bounces += int(user.get_stat("spark_bounce_bonus")) if user.get_stat("spark_bounce_bonus") else 0

	var spark = ProjectilePool.get_spark()
	if spark == null:
		return  # over the concurrent-spark cap
	spark.allegiance = SparkProjectile.Allegiance.PLAYER
	spark.user = user
	spark.weapon = null
	spark.target = enemy_node
	spark.base_damage = dmg
	spark.bounce_count = bounces
	spark.bounces_remaining = bounces
	spark.bounce_range = range_val
	spark.speed = speed
	spark.lifetime = lifetime
	spark.global_position = enemy_node.global_position
	spark.direction = Vector2.from_angle(randf() * TAU)
	spark.rotation = spark.direction.angle()
	enemy_node.get_tree().current_scene.add_child(spark)
