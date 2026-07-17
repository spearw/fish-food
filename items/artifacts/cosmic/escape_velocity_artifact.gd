## escape_velocity_artifact.gd -- Cosmic deck: you fall forever, sideways. +15% move speed,
## always (the Adrenaline machinery, minus the condition).
extends ArtifactBase

@export var speed_multiplier: float = 1.15

func get_speed_modifier() -> float:
	return speed_multiplier
