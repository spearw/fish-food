## flamethrower_weapon.gd
## A specialized weapon that adds unique transformation logic for the Flamethrower.
class_name FlamethrowerWeapon
extends TransformableWeapon

@export var ring_of_fire_stats: PersistentEffectStats

# --- Reference for the Ring of Fire effect ---
var ring_of_fire_instance: Node = null

# The fire() method is called by the timer.
func fire(multiplier: int = 1):
	# If the "Ring of Fire" transformation is active, it completely takes over.
	# The normal firing mechanism is disabled.
	if has_transformation("ring_of_fire"):
		# The aura is persistent, so the timer firing doesn't need to do anything.
		return

	super.fire()

func _on_transformation_acquired(id: String):
	if id == "flaming_tongues":
		fire_behavior_component.fire_pattern = FireBehaviorComponent.FirePattern.MIRRORED_FORWARD

	if id == "ring_of_fire":
		# When we get this upgrade, immediately create the ring.
		_create_ring_of_fire()

## Logic to create and manage the persistent Ring of Fire aura.
func _create_ring_of_fire():
	var user = stats_component.user
	if not is_instance_valid(user): return

	# If a ring already exists, don't create another one.
	if is_instance_valid(ring_of_fire_instance): return

	# Load aura scene
	var ring_scene = load("res://items/effects/persistent_damage_effect.tscn")
	ring_of_fire_instance = ring_scene.instantiate()

	# Pass necessary stats to the aura.
	ring_of_fire_instance.stats = self.ring_of_fire_stats
	ring_of_fire_instance.allegiance = stats_component.get_projectile_allegiance()
	ring_of_fire_instance.user = user
	ring_of_fire_instance.attribution_key = String(get_meta("weapon_type", name))

	# Attach the aura to the player.
	user.add_child(ring_of_fire_instance)
