## static_charge_artifact.gd -- combo synergy (Lightning + Melee): getting hit discharges a nova
## of sparks.
extends ArtifactBase

@export var spark_count: int = 3

func on_equipped() -> void:
	if not Events.player_was_hit.is_connected(_on_player_hit):
		Events.player_was_hit.connect(_on_player_hit)

func on_unequipped() -> void:
	if Events.player_was_hit.is_connected(_on_player_hit):
		Events.player_was_hit.disconnect(_on_player_hit)

func _on_player_hit(_source_node: Node) -> void:
	if not is_instance_valid(user):
		return
	var spark_data = WeaponTagRegistry.get_effect_data(WeaponTags.Effect.SPARK, {})
	for i in range(spark_count):
		var spark = ProjectilePool.get_spark()
		if spark == null:
			return
		spark.allegiance = SparkProjectile.Allegiance.PLAYER
		spark.user = user
		spark.weapon = null
		spark.attribution_key = "Static Charge"
		spark.target = null
		spark.base_damage = int(spark_data.get("spark_damage", 6))
		spark.bounce_count = int(spark_data.get("spark_bounces", 3))
		spark.bounces_remaining = spark.bounce_count
		spark.bounce_range = spark_data.get("spark_range", 200.0)
		spark.speed = spark_data.get("spark_speed", 600.0)
		spark.lifetime = spark_data.get("spark_lifetime", 0.5)
		spark.direction = Vector2.from_angle(TAU * i / spark_count)
		spark.rotation = spark.direction.angle()
		get_tree().current_scene.add_child(spark)
		spark.global_position = user.global_position
