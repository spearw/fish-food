## critical_condition_artifact.gd -- combo synergy (cosmic + venom).
## Critical Condition: your hits deal +40% to enemies at full venom stacks. Does not consume the stacks (Caustic Detonation does).
extends ArtifactBase

@export var amount: float = 0.4

func get_bonus_vs_max_venom_bonus() -> float:
	return amount
