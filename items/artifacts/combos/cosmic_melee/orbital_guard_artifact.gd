## orbital_guard_artifact.gd -- combo synergy (Cosmic + Melee): anything that hits you gets
## struck from above (15-dmg burst on the attacker). The sky hits back.
extends ArtifactBase

const EXPLOSION_SCENE := preload("res://systems/projectiles/explosion/explosion_effect.tscn")

@export var burst_damage: int = 15

func on_equipped() -> void:
	if not Events.player_was_hit.is_connected(_on_player_hit):
		Events.player_was_hit.connect(_on_player_hit)

func on_unequipped() -> void:
	if Events.player_was_hit.is_connected(_on_player_hit):
		Events.player_was_hit.disconnect(_on_player_hit)

func _on_player_hit(source_node: Node) -> void:
	if not is_instance_valid(source_node) or not source_node is Node2D:
		return
	var explosion_stats = ExplosionStats.new()
	explosion_stats.damage = burst_damage
	explosion_stats.scale = Vector2(2.6, 2.6)
	explosion_stats.modulation = Color(0.85, 0.9, 1.0, 0.85)
	explosion_stats.effect_duration = 0.3
	var explosion = EXPLOSION_SCENE.instantiate()
	explosion.stats = explosion_stats
	explosion.allegiance = Projectile.Allegiance.PLAYER
	explosion.user = user
	explosion.attribution_key = "Orbital Guard"
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = source_node.global_position
