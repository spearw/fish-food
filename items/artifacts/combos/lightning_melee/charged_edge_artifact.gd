## charged_edge_artifact.gd -- combo synergy (Lightning + Melee): melee strikes have a chance to
## release a spark from the struck enemy.
extends ArtifactBase

@export var spark_chance: float = 0.5

func on_equipped() -> void:
	if not Events.enemy_hit.is_connected(_on_enemy_hit):
		Events.enemy_hit.connect(_on_enemy_hit)

func on_unequipped() -> void:
	if Events.enemy_hit.is_connected(_on_enemy_hit):
		Events.enemy_hit.disconnect(_on_enemy_hit)

func _on_enemy_hit(hit_details: Dictionary) -> void:
	if randf() > spark_chance:
		return
	var enemy = hit_details.get("enemy")
	if is_instance_valid(enemy):
		_spawn_spark_at(enemy)

func _spawn_spark_at(enemy_node: Node2D) -> void:
	var spark_data = WeaponTagRegistry.get_effect_data(WeaponTags.Effect.SPARK, {})
	var dmg := int(spark_data.get("spark_damage", 6))
	var bounces := int(spark_data.get("spark_bounces", 3))
	if is_instance_valid(user) and user.has_method("get_stat"):
		var dmg_mult = user.get_stat("spark_damage_bonus") if user.get_stat("spark_damage_bonus") else 1.0
		dmg = int(dmg * dmg_mult)
		bounces += int(user.get_stat("spark_bounce_bonus")) if user.get_stat("spark_bounce_bonus") else 0
	var spark = ProjectilePool.get_spark()
	if spark == null:
		return
	spark.allegiance = SparkProjectile.Allegiance.PLAYER
	spark.user = user
	spark.weapon = null
	spark.attribution_key = "Charged Edge"
	spark.target = enemy_node
	spark.base_damage = dmg
	spark.bounce_count = bounces
	spark.bounces_remaining = bounces
	spark.bounce_range = spark_data.get("spark_range", 200.0)
	spark.speed = spark_data.get("spark_speed", 600.0)
	spark.lifetime = spark_data.get("spark_lifetime", 0.5)
	spark.direction = Vector2.from_angle(randf() * TAU)
	spark.rotation = spark.direction.angle()
	get_tree().current_scene.add_child(spark)
	spark.global_position = enemy_node.global_position
