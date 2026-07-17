## singularity_weapon.gd -- Cosmic's crowd-control conversion: a strike that opens a pull,
## drags the school to its center, then pops. The zone reads the exports below at spawn.
class_name SingularityWeapon
extends TransformableWeapon

@export var pull_radius: float = 220.0
@export var pull_force: float = 90.0
@export var pull_duration: float = 1.2
@export var pop_per_enemy: int = 0

func _on_transformation_acquired(id: String):
	## Accretion: the well widens and drags harder.
	if id == "accretion":
		pull_radius = pull_radius * 1.5
		pull_force = pull_force * 1.4
	## Collapse: the pop detonates hard, scaled by every enemy caught in the well.
	if id == "collapse":
		pop_per_enemy = 6
