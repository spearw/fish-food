## branding_blade_artifact.gd -- combo synergy (Fire + Melee): your melee strikes BRAND --
## each swing hit has a chance to set the target burning.
extends ArtifactBase

const BURN := preload("res://systems/status_effects/fire/burning.tres")

@export var burn_chance: float = 0.5

func on_equipped() -> void:
	if not Events.enemy_hit.is_connected(_on_enemy_hit):
		Events.enemy_hit.connect(_on_enemy_hit)

func on_unequipped() -> void:
	if Events.enemy_hit.is_connected(_on_enemy_hit):
		Events.enemy_hit.disconnect(_on_enemy_hit)

func _on_enemy_hit(hit_details: Dictionary) -> void:
	# enemy_hit only fires from MELEE hitboxes -- exactly the gate this combo wants.
	if randf() > burn_chance:
		return
	var enemy = hit_details.get("enemy")
	if not is_instance_valid(enemy):
		return
	var mgr = enemy.get_node_or_null("StatusEffectManager")
	if mgr:
		mgr.apply_status(BURN, user, "Branding Blade")
