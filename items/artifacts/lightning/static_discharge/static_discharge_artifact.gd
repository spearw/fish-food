## static_discharge_artifact.gd
## An artifact that causes enemies killed by chain lightning to explode.
## The explosion deals 30% of the killing blow's damage to nearby enemies.
class_name StaticDischargeArtifact
extends ArtifactBase

const EXPLOSION_SCENE = preload("res://systems/projectiles/explosion/explosion_effect.tscn")
const EXPLOSION_RADIUS: float = 60.0
const DAMAGE_PERCENT: float = 0.3  # 30% of the damage dealt

func on_equipped() -> void:
	if not Events.chain_kill.is_connected(_on_chain_kill):
		Events.chain_kill.connect(_on_chain_kill)

func on_unequipped() -> void:
	if Events.chain_kill.is_connected(_on_chain_kill):
		Events.chain_kill.disconnect(_on_chain_kill)

## Called when an enemy is killed by a chain projectile.
func _on_chain_kill(position: Vector2, damage: float) -> void:
	if not is_instance_valid(user):
		return

	# Calculate explosion damage (30% of the killing blow)
	var explosion_damage = int(damage * DAMAGE_PERCENT)
	if explosion_damage < 1:
		explosion_damage = 1

	# Create explosion stats dynamically
	var explosion_stats = ExplosionStats.new()
	explosion_stats.damage = explosion_damage
	explosion_stats.scale = Vector2(EXPLOSION_RADIUS / 16.0, EXPLOSION_RADIUS / 16.0)  # Scale based on radius
	explosion_stats.modulation = Color(0.6, 0.8, 1.0, 0.7)  # Blue-white lightning color
	explosion_stats.effect_duration = 0.3

	# Spawn the explosion
	var explosion = EXPLOSION_SCENE.instantiate()
	explosion.stats = explosion_stats
	explosion.allegiance = Projectile.Allegiance.PLAYER
	explosion.user = user
	explosion.attribution_key = "Static Discharge"
	explosion.global_position = position

	# Add to scene
	var scene_root = user.get_tree().current_scene
	if scene_root:
		scene_root.add_child(explosion)
