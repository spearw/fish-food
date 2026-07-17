## toxic_rounds_artifact.gd -- combo synergy (projectile + venom).
## Toxic Rounds: every projectile has a chance to add a venom stack (same conductive-style pattern, venom payload).
extends ArtifactBase

@export var amount: float = 0.25

func get_on_hit_venom_chance_bonus() -> float:
	return amount
