## overpressure_artifact.gd -- Projectiles deck: every finite-pierce projectile you fire pierces
## one more body (infinite pierce stays infinite). Volume of fire, now with follow-through.
extends ArtifactBase

@export var bonus_pierce: float = 1.0

func get_pierce_bonus() -> float:
	return bonus_pierce
