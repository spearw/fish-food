## emberheart_artifact.gd
## Magic Man's identity artifact: his burns CATCH. Every burn he applies has a chance to escalate
## into a full ignite. A verb, not a stat line -- fire doesn't tick harder for him, it spreads.
## (No class_name on purpose: scene-attached only, and a new class_name needs a cache rebuild.)
extends ArtifactBase

const IGNITE := preload("res://systems/status_effects/fire/ignited.tres")

## Chance for a fresh burn to escalate. Playtest fodder.
@export var escalate_chance: float = 0.25

func on_equipped() -> void:
	if not Events.status_applied_to_enemy.is_connected(_on_status_applied):
		Events.status_applied_to_enemy.connect(_on_status_applied)

func on_unequipped() -> void:
	if Events.status_applied_to_enemy.is_connected(_on_status_applied):
		Events.status_applied_to_enemy.disconnect(_on_status_applied)

func _on_status_applied(enemy_node: Node, status_id: String) -> void:
	# Escalate BURNS only. Listening for "ignited" would chain off our own effect.
	if status_id != "burning" or not is_instance_valid(enemy_node):
		return
	if randf() >= escalate_chance:
		return
	if enemy_node.has_node("StatusEffectManager"):
		enemy_node.get_node("StatusEffectManager").apply_status(IGNITE, user)
