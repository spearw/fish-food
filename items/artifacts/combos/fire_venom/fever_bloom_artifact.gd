## fever_bloom_artifact.gd -- combo synergy (Fire + Venom): enemies that die POISONED have a
## chance to leave burning ground.
extends ArtifactBase

const GROUND_FIRE_STATS := preload("res://items/weapons/molotov_cocktail/molotov_ground_fire_stats.tres")
const ZONE_SCENE := preload("res://items/effects/persistent_damage_effect.tscn")

@export var bloom_chance: float = 0.5

func on_equipped() -> void:
	if not Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.connect(_on_kill)

func on_unequipped() -> void:
	if Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.disconnect(_on_kill)

func _on_kill(enemy_node: Node) -> void:
	if not is_instance_valid(enemy_node) or randf() > bloom_chance:
		return
	var mgr = enemy_node.get_node_or_null("StatusEffectManager")
	if mgr == null or not mgr.active_statuses.has("poison"):
		return
	var zone = ZONE_SCENE.instantiate()
	zone.stats = GROUND_FIRE_STATS
	zone.allegiance = Projectile.Allegiance.PLAYER
	zone.user = user
	zone.attribution_key = "Fever Bloom"
	get_tree().current_scene.add_child(zone)
	zone.global_position = enemy_node.global_position
