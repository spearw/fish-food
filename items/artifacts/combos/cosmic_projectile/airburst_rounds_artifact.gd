## airburst_rounds_artifact.gd -- combo synergy (cosmic + projectile).
## Airburst Rounds: projectile hits have a 10% chance to detonate a 12-dmg mini-strike on the target.
extends ArtifactBase

@export var amount: float = 0.1

func get_on_hit_strike_chance_bonus() -> float:
	return amount
