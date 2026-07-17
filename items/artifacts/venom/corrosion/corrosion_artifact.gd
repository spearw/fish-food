## corrosion_artifact.gd -- Venom deck: your damage-over-time ticks also EAT ARMOR (1 point per
## tick, per entity, floor 0). This is the roadmap's armor-BREAK artifact wearing acid flavor:
## venom doesn't just ignore shells -- it dissolves them for your whole build. Player-side verb
## only; the global armor formula is untouched (armor law, balance README).
extends ArtifactBase

@export var shred_per_tick: float = 1.0

func get_dot_armor_shred_bonus() -> float:
	return shred_per_tick
