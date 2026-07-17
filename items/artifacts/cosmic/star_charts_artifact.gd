## star_charts_artifact.gd -- Cosmic deck: the charts predict one more falling star.
## +1 projectile on everything (the Tome's machinery; they stack).
extends ArtifactBase

@export var bonus_projectiles: int = 1

func get_projectile_bonus() -> int:
	return bonus_projectiles
