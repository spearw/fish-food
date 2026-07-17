## poison_cloud_weapon.gd -- evolution host for the Venom deck's zone anchor.
class_name PoisonCloudWeapon
extends TransformableWeapon

## Spore Burst: enemies that die poisoned pop into a mini-cloud (kill-spread pattern; chains
## through schools because mini-clouds poison too). Exported so it localizes + rarity-scales.
@export var spore_cloud_stats: PersistentEffectStats
@export var spore_chance: float = 0.5
const ZONE_SCENE := preload("res://items/effects/persistent_damage_effect.tscn")

func _on_transformation_acquired(id: String):
	## Rolling Fog: clouds creep toward the nearest enemy -- mobile area denial. The drift lives
	## on the LOCALIZED nested ground stats, so the tier's damage scaling is untouched.
	if id == "rolling_fog":
		if projectile_stats is MultiStageProjectileStats and projectile_stats.on_death_effect_stats:
			projectile_stats.on_death_effect_stats.drift_speed = 45.0
	if id == "spore_burst":
		if not Events.enemy_killed.is_connected(_on_kill):
			Events.enemy_killed.connect(_on_kill)

func _on_kill(enemy_node: Node) -> void:
	if not has_transformation("spore_burst") or spore_cloud_stats == null:
		return
	if not is_instance_valid(enemy_node) or randf() > spore_chance:
		return
	var mgr = enemy_node.get_node_or_null("StatusEffectManager")
	if mgr == null or not mgr.active_statuses.has("poison"):
		return
	var zone = ZONE_SCENE.instantiate()
	zone.stats = spore_cloud_stats
	zone.allegiance = Projectile.Allegiance.PLAYER
	zone.user = stats_component.user
	zone.attribution_key = String(get_meta("weapon_type", name))
	get_tree().current_scene.add_child(zone)
	zone.global_position = enemy_node.global_position
