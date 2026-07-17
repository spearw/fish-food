## comet_fist_artifact.gd -- combo synergy (Cosmic + Melee): every 4th melee strike calls a comet
## down on the victim (18-dmg burst).
extends ArtifactBase

const EXPLOSION_SCENE := preload("res://systems/projectiles/explosion/explosion_effect.tscn")

@export var every_n_hits: int = 4
@export var burst_damage: int = 18

var _hits := 0

func on_equipped() -> void:
	if not Events.enemy_hit.is_connected(_on_enemy_hit):
		Events.enemy_hit.connect(_on_enemy_hit)

func on_unequipped() -> void:
	if Events.enemy_hit.is_connected(_on_enemy_hit):
		Events.enemy_hit.disconnect(_on_enemy_hit)

func _on_enemy_hit(hit_details: Dictionary) -> void:
	_hits += 1
	if _hits < every_n_hits:
		return
	_hits = 0
	var enemy = hit_details.get("enemy")
	if not is_instance_valid(enemy):
		return
	var explosion_stats = ExplosionStats.new()
	explosion_stats.damage = burst_damage
	explosion_stats.scale = Vector2(2.8, 2.8)
	explosion_stats.modulation = Color(0.85, 0.9, 1.0, 0.85)
	explosion_stats.effect_duration = 0.3
	var explosion = EXPLOSION_SCENE.instantiate()
	explosion.stats = explosion_stats
	explosion.allegiance = Projectile.Allegiance.PLAYER
	explosion.user = user
	explosion.attribution_key = "Comet Fist"
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = enemy.global_position
