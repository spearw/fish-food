## lethal_dose_artifact.gd -- Venom deck: enemies carrying more queued damage-over-time than their
## MAX health die on the spot. The doomed skip the funeral -- DoT's overkill-wait, solved. By
## design this flips the regenerator counter on its head (user call, Jul 2026): a lethal dose
## does not care how fast the wound knits. The check lives in StatusEffectManager (the only
## moments the pending total grows); this artifact just announces itself via the stat.
extends ArtifactBase

func get_dot_execute_bonus() -> float:
	return 1.0
