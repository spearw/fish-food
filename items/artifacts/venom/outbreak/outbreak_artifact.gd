## outbreak_artifact.gd -- Venom deck: when a poisoned enemy dies, its venom bursts to nearby
## enemies (Static Discharge's toxin mirror; spreads the ramp through schools). Self-sufficient
## verb: any poison source feeds it -- it loves the Venom deck, it never requires it.
extends ArtifactBase

const POISON := preload("res://systems/status_effects/poison/poison_status_effect.tres")

@export var spread_chance: float = 0.5
@export var spread_radius: float = 140.0
@export var max_targets: int = 3

func on_equipped() -> void:
	if not Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.connect(_on_kill)

func on_unequipped() -> void:
	if Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.disconnect(_on_kill)

func _on_kill(enemy_node: Node) -> void:
	if not is_instance_valid(enemy_node) or randf() > spread_chance:
		return
	var mgr = enemy_node.get_node_or_null("StatusEffectManager")
	if mgr == null or not mgr.active_statuses.has("poison"):
		return
	var near: Array = EntityRegistry.get_candidates_near(
		"enemies", enemy_node.global_position, spread_radius)
	var spread := 0
	for e in near:
		if spread >= max_targets:
			break
		if not is_instance_valid(e) or e == enemy_node:
			continue
		var target_mgr = e.get_node_or_null("StatusEffectManager")
		if target_mgr:
			target_mgr.apply_status(POISON, user, "Outbreak")
			spread += 1
