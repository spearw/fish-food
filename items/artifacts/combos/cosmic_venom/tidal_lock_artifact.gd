## tidal_lock_artifact.gd -- combo synergy (Cosmic + Venom): applying poison also applies a 25%
## slow, so enemies stay inside strike telegraphs longer.
extends ArtifactBase

const TIDAL_SLOW := preload("res://systems/status_effects/poison/tidal_slow.tres")

func on_equipped() -> void:
	if not Events.status_applied_to_enemy.is_connected(_on_status_applied):
		Events.status_applied_to_enemy.connect(_on_status_applied)

func on_unequipped() -> void:
	if Events.status_applied_to_enemy.is_connected(_on_status_applied):
		Events.status_applied_to_enemy.disconnect(_on_status_applied)

func _on_status_applied(enemy_node: Node, status_id: String) -> void:
	# Poison only -- the slow's own application re-fires this signal and is ignored here.
	if status_id != "poison" or not is_instance_valid(enemy_node):
		return
	var mgr = enemy_node.get_node_or_null("StatusEffectManager")
	if mgr:
		mgr.apply_status(TIDAL_SLOW, user, "Tidal Lock")
