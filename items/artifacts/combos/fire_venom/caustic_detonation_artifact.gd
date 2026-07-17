## caustic_detonation_artifact.gd -- combo synergy (Fire + Venom): setting a POISONED enemy on
## fire detonates its venom: the stacks are consumed as instant damage.
extends ArtifactBase

## Damage-report identity for the detonation hits.
var attribution_key: String = "Caustic Detonation"

@export var damage_per_stack: int = 6

func on_equipped() -> void:
	if not Events.status_applied_to_enemy.is_connected(_on_status_applied):
		Events.status_applied_to_enemy.connect(_on_status_applied)

func on_unequipped() -> void:
	if Events.status_applied_to_enemy.is_connected(_on_status_applied):
		Events.status_applied_to_enemy.disconnect(_on_status_applied)

func _on_status_applied(enemy_node: Node, status_id: String) -> void:
	if status_id != "burning" and status_id != "ignited":
		return
	if not is_instance_valid(enemy_node) or not enemy_node.has_method("take_damage"):
		return
	var mgr = enemy_node.get_node_or_null("StatusEffectManager")
	if mgr == null:
		return
	var stacks: int = mgr.consume_status("poison")
	if stacks <= 0:
		return
	var dot_mult: float = 1.0
	if is_instance_valid(user) and user.has_method("get_stat"):
		dot_mult = user.get_stat("dot_damage_bonus")
	# 100% armor pen: this IS venom damage, cashed out early.
	enemy_node.take_damage(int(stacks * damage_per_stack * dot_mult), 1.0, false, self)
