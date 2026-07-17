## kill_current_artifact.gd -- combo synergy (Lightning + Projectile): kills have a chance to
## release a spark from the corpse.
extends ArtifactBase

@export var spark_chance: float = 0.5

func on_equipped() -> void:
	if not Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.connect(_on_kill)

func on_unequipped() -> void:
	if Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.disconnect(_on_kill)

func _on_kill(enemy_node: Node) -> void:
	if not is_instance_valid(enemy_node) or randf() > spark_chance:
		return
	var spark_data = WeaponTagRegistry.get_effect_data(WeaponTags.Effect.SPARK, {})
	var spark = ProjectilePool.get_spark()
	if spark == null:
		return
	spark.allegiance = SparkProjectile.Allegiance.PLAYER
	spark.user = user
	spark.weapon = null
	spark.attribution_key = "Kill Current"
	spark.target = null
	spark.base_damage = int(spark_data.get("spark_damage", 6))
	spark.bounce_count = int(spark_data.get("spark_bounces", 3))
	spark.bounces_remaining = spark.bounce_count
	spark.bounce_range = spark_data.get("spark_range", 200.0)
	spark.speed = spark_data.get("spark_speed", 600.0)
	spark.lifetime = spark_data.get("spark_lifetime", 0.5)
	spark.direction = Vector2.from_angle(randf() * TAU)
	spark.rotation = spark.direction.angle()
	get_tree().current_scene.add_child(spark)
	spark.global_position = enemy_node.global_position
