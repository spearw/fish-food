## return_stroke_artifact.gd -- combo synergy (Cosmic + Lightning): a chain kill completes the
## circuit skyward, and the sky answers -- a 20-dmg burst at the kill point.
extends ArtifactBase

const EXPLOSION_SCENE := preload("res://systems/projectiles/explosion/explosion_effect.tscn")

@export var burst_damage: int = 20

func on_equipped() -> void:
	if not Events.chain_kill.is_connected(_on_chain_kill):
		Events.chain_kill.connect(_on_chain_kill)

func on_unequipped() -> void:
	if Events.chain_kill.is_connected(_on_chain_kill):
		Events.chain_kill.disconnect(_on_chain_kill)

func _on_chain_kill(position: Vector2, _damage: float) -> void:
	var explosion_stats = ExplosionStats.new()
	explosion_stats.damage = burst_damage
	explosion_stats.scale = Vector2(3.0, 3.0)
	explosion_stats.modulation = Color(0.8, 0.9, 1.0, 0.85)
	explosion_stats.effect_duration = 0.3
	var explosion = EXPLOSION_SCENE.instantiate()
	explosion.stats = explosion_stats
	explosion.allegiance = Projectile.Allegiance.PLAYER
	explosion.user = user
	explosion.attribution_key = "Return Stroke"
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = position
