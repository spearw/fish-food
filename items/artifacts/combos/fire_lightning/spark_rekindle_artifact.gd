## spark_rekindle_artifact.gd
## Fire + Lightning combo synergy (SUSTAIN): a spark that hits a burning enemy re-ignites it (refreshes
## the burn's duration), so your DOTs never lapse while sparks keep landing.
class_name SparkRekindleArtifact
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
	# Only re-ignite enemies that are ALREADY burning -- this extends the burn, it doesn't start one.
	if manager and manager.active_statuses.has("ignited"):
		var info = manager.active_statuses["ignited"]
		info["timer"].start(info["effect"].duration)  # refresh to full duration
