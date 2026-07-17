## toxic_discharge_artifact.gd -- combo synergy (Lightning + Venom): a spark that hits an enemy
## at FULL venom stacks detonates the venom as lightning damage. Saturate, then strike.
extends ArtifactBase

## Damage-report identity for the discharge hits.
var attribution_key: String = "Toxic Discharge"

@export var damage_per_stack: int = 8

func on_equipped() -> void:
	if not Events.spark_hit_enemy.is_connected(_on_spark_hit):
		Events.spark_hit_enemy.connect(_on_spark_hit)

func on_unequipped() -> void:
	if Events.spark_hit_enemy.is_connected(_on_spark_hit):
		Events.spark_hit_enemy.disconnect(_on_spark_hit)

func _on_spark_hit(enemy_node: Node) -> void:
	if not is_instance_valid(enemy_node) or not enemy_node.has_method("take_damage"):
		return
	var mgr = enemy_node.get_node_or_null("StatusEffectManager")
	if mgr == null or not mgr.active_statuses.has("poison"):
		return
	var venom = mgr.active_statuses["poison"]["effect"]
	if not "stacks" in venom or venom.stacks < venom.max_stacks:
		return
	var stacks: int = mgr.consume_status("poison")
	enemy_node.take_damage(stacks * damage_per_stack, 1.0, false, self)
