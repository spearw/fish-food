## water_wears_stone_artifact.gd -- Lightning deck: the chip floor. Your hits ALWAYS deal at
## least 20% of their raw damage (minimum 1), so armor can weaken hits but not zero them. The
## million-tiny-hits build's answer to heavy shells, bought with a card; the global armor rule is
## untouched, and the director's walled-share cap silently stands down for this build.
extends ArtifactBase

@export var floor_pct: float = 0.2

func get_chip_floor_bonus() -> float:
	return floor_pct
