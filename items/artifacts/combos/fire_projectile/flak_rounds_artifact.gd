## flak_rounds_artifact.gd -- combo synergy (Fire + Projectile): your kills have a chance to
## detonate in a fireball.
extends ArtifactBase

const EXPLOSION_SCENE := preload("res://systems/projectiles/explosion/explosion_effect.tscn")

@export var detonate_chance: float = 0.35
@export var explosion_damage: int = 15

func on_equipped() -> void:
	if not Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.connect(_on_kill)

func on_unequipped() -> void:
	if Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.disconnect(_on_kill)

func _on_kill(enemy_node: Node) -> void:
	if not is_instance_valid(enemy_node) or randf() > detonate_chance:
		return
	var explosion_stats = ExplosionStats.new()
	explosion_stats.damage = explosion_damage
	explosion_stats.scale = Vector2(3.5, 3.5)
	explosion_stats.modulation = Color(1.0, 0.6, 0.25, 0.8)
	explosion_stats.effect_duration = 0.3
	var explosion = EXPLOSION_SCENE.instantiate()
	explosion.stats = explosion_stats
	explosion.allegiance = Projectile.Allegiance.PLAYER
	explosion.user = user
	explosion.attribution_key = "Flak Rounds"
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = enemy_node.global_position
