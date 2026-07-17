## rolling_barrage_artifact.gd -- combo synergy (Cosmic + Projectile): every 10th kill calls a
## BIG strike (40 dmg, wide) on the fallen. The barrage creeps forward on momentum.
extends ArtifactBase

const EXPLOSION_SCENE := preload("res://systems/projectiles/explosion/explosion_effect.tscn")

@export var every_n_kills: int = 10
@export var burst_damage: int = 40

var _kills := 0

func on_equipped() -> void:
	if not Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.connect(_on_kill)

func on_unequipped() -> void:
	if Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.disconnect(_on_kill)

func _on_kill(enemy_node: Node) -> void:
	_kills += 1
	if _kills < every_n_kills:
		return
	_kills = 0
	if not is_instance_valid(enemy_node):
		return
	var explosion_stats = ExplosionStats.new()
	explosion_stats.damage = burst_damage
	explosion_stats.scale = Vector2(4.5, 4.5)
	explosion_stats.modulation = Color(0.9, 0.92, 1.0, 0.9)
	explosion_stats.effect_duration = 0.35
	var explosion = EXPLOSION_SCENE.instantiate()
	explosion.stats = explosion_stats
	explosion.allegiance = Projectile.Allegiance.PLAYER
	explosion.user = user
	explosion.attribution_key = "Rolling Barrage"
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = enemy_node.global_position
