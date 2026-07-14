## spark_detonate_artifact.gd
## Fire + Lightning combo synergy (DETONATE / BURST): a spark that hits a burning enemy deals the burn's
## remaining damage instantly, then consumes the burn. Trades sustained DOT for a front-loaded spike.
class_name SparkDetonateArtifact
extends ArtifactBase

func on_equipped() -> void:
	if not Events.spark_hit_enemy.is_connected(_on_spark_hit):
		Events.spark_hit_enemy.connect(_on_spark_hit)

func on_unequipped() -> void:
	if Events.spark_hit_enemy.is_connected(_on_spark_hit):
		Events.spark_hit_enemy.disconnect(_on_spark_hit)

func _on_spark_hit(enemy_node: Node) -> void:
	if not is_instance_valid(enemy_node) or enemy_node.is_dying:
		return
	var manager = enemy_node.get_node_or_null("StatusEffectManager")
	if manager == null or not manager.active_statuses.has("ignited"):
		return
	var info = manager.active_statuses["ignited"]
	var effect = info["effect"]
	if not (effect is DotStatusEffect):
		return

	# Remaining burn = remaining ticks x damage per tick.
	var remaining_ticks: float = info["timer"].time_left / maxf(0.01, effect.time_between_ticks)
	var burst := int(effect.damage_per_tick * remaining_ticks)
	if burst <= 0:
		return

	if enemy_node.has_method("take_damage"):
		enemy_node.take_damage(burst, 1.0, false)  # 100% armor pen; no crit
	# Consume the burn: shorten it so it ends almost immediately via its normal expiry path.
	info["timer"].start(0.01)
