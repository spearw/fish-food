## star_charts_artifact.gd -- Cosmic deck: +1 projectile on everything.
## Uses the same projectile-bonus hook as the Tome of Duplication; they stack.
extends ArtifactBase

@export var bonus_projectiles: int = 1

func get_projectile_bonus() -> int:
	return bonus_projectiles
