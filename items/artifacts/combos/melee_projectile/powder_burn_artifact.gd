## powder_burn_artifact.gd -- combo synergy (melee + projectile).
## Powder Burn: projectiles that connect within melee range (130px) deal +50% -- bridges the two decks' range identities.
extends ArtifactBase

@export var amount: float = 0.5

func get_point_blank_bonus_bonus() -> float:
	return amount
