## solar_flare_artifact.gd -- combo synergy (cosmic + fire).
## Solar Flare: your hits deal +40% to BURNING enemies -- ignite, then obliterate (consumed in the projectile damage path).
extends ArtifactBase

@export var amount: float = 0.4

func get_bonus_vs_burning_bonus() -> float:
	return amount
