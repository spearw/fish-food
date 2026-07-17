## emberheart_artifact.gd
## Magic Man's identity artifact, in two halves that feed each other:
##   1. SPREAD -- kills he makes have a chance to ignite enemies near the victim. Fire spreads from
##      death (the fire mirror of Static Discharge's kill-sparks). This half works in EVERY build,
##      which is the identity-artifact rule: it may love a deck, but must never require one. The
##      first version only listened for burns, so a fire-less run carried a literally dead artifact.
##   2. ESCALATE -- burns he applies (from any source: the spread above, fire weapons, combo
##      artifacts) have a chance to escalate into a true IGNITE. With the fire deck this rides the
##      whole engine; without it, it rides the spread.
## (No class_name on purpose: scene-attached only, avoids the class-cache rebuild.)
extends ArtifactBase

const BURN := preload("res://systems/status_effects/fire/burning.tres")
const IGNITE := preload("res://systems/status_effects/fire/ignited.tres")

## Chance for a kill to spread fire, and how far/wide it catches. Playtest fodder.
@export var spread_chance: float = 0.25
@export var spread_radius: float = 130.0
@export var max_spread_targets: int = 3
## Chance for a fresh burn to escalate into a true ignite. Playtest fodder.
@export var escalate_chance: float = 0.25

func on_equipped() -> void:
	if not Events.status_applied_to_enemy.is_connected(_on_status_applied):
		Events.status_applied_to_enemy.connect(_on_status_applied)
	if not Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.connect(_on_kill)

func on_unequipped() -> void:
	if Events.status_applied_to_enemy.is_connected(_on_status_applied):
		Events.status_applied_to_enemy.disconnect(_on_status_applied)
	if Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.disconnect(_on_kill)

## SPREAD: fire catches from the fallen. Uses the registry's spatial query (the perf-safe primitive)
## rather than touching any per-hit path.
func _on_kill(enemy_node: Node) -> void:
	if not is_instance_valid(enemy_node) or randf() >= spread_chance:
		return
	var caught := 0
	for e in EntityRegistry.get_enemies_within(enemy_node.global_position, spread_radius):
		if e == enemy_node or not is_instance_valid(e) or e.is_dying:
			continue
		if e.has_node("StatusEffectManager"):
			e.get_node("StatusEffectManager").apply_status(BURN, user, "Emberheart")
			caught += 1
			if caught >= max_spread_targets:
				break

## ESCALATE: burns become true ignites. Listens for BURNS only -- reacting to "ignited" would chain
## off our own effect.
func _on_status_applied(enemy_node: Node, status_id: String) -> void:
	if status_id != "burning" or not is_instance_valid(enemy_node):
		return
	if randf() >= escalate_chance:
		return
	if enemy_node.has_node("StatusEffectManager"):
		enemy_node.get_node("StatusEffectManager").apply_status(IGNITE, user, "Emberheart")
