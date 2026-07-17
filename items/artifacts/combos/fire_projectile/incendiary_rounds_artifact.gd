## incendiary_rounds_artifact.gd -- combo synergy (fire + projectile).
## Incendiary Rounds: every projectile has a chance to set its target burning (consumed in the projectile hit path via the player stat loop).
extends ArtifactBase

@export var amount: float = 0.25

func get_on_hit_burn_chance_bonus() -> float:
	return amount
