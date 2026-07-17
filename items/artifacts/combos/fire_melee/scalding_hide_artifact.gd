## scalding_hide_artifact.gd -- combo synergy (Fire + Melee): anything that hits you starts
## BURNING. The facetank deck's revenge, in fire's currency.
extends ArtifactBase

const BURN := preload("res://systems/status_effects/fire/burning.tres")

func on_equipped() -> void:
	if not Events.player_was_hit.is_connected(_on_player_hit):
		Events.player_was_hit.connect(_on_player_hit)

func on_unequipped() -> void:
	if Events.player_was_hit.is_connected(_on_player_hit):
		Events.player_was_hit.disconnect(_on_player_hit)

func _on_player_hit(source_node: Node) -> void:
	if not is_instance_valid(source_node):
		return
	var mgr = source_node.get_node_or_null("StatusEffectManager")
	if mgr:
		mgr.apply_status(BURN, user, "Scalding Hide")
