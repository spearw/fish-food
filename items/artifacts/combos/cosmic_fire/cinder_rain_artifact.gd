## cinder_rain_artifact.gd -- combo synergy (Cosmic + Fire): burning enemies that die pull a
## cinder down from above -- a 15-dmg burst at the corpse.
extends ArtifactBase

const EXPLOSION_SCENE := preload("res://systems/projectiles/explosion/explosion_effect.tscn")

@export var burst_damage: int = 15

func on_equipped() -> void:
	if not Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.connect(_on_kill)

func on_unequipped() -> void:
	if Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.disconnect(_on_kill)

func _on_kill(enemy_node: Node) -> void:
	if not is_instance_valid(enemy_node):
		return
	var mgr = enemy_node.get_node_or_null("StatusEffectManager")
	if mgr == null or not (mgr.active_statuses.has("burning") or mgr.active_statuses.has("ignited")):
		return
	var explosion_stats = ExplosionStats.new()
	explosion_stats.damage = burst_damage
	explosion_stats.scale = Vector2(2.6, 2.6)
	explosion_stats.modulation = Color(1.0, 0.65, 0.3, 0.8)
	explosion_stats.effect_duration = 0.3
	var explosion = EXPLOSION_SCENE.instantiate()
	explosion.stats = explosion_stats
	explosion.allegiance = Projectile.Allegiance.PLAYER
	explosion.user = user
	explosion.attribution_key = "Cinder Rain"
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = enemy_node.global_position
