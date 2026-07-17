## storm_cell_artifact.gd -- combo synergy (cosmic + lightning).
## Storm Cell: your critical hits release a spark (projectile path; registry defaults).
extends ArtifactBase

@export var amount: float = 1.0

func get_crit_spark_bonus() -> float:
	return amount
