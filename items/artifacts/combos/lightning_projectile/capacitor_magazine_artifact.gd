## capacitor_magazine_artifact.gd -- combo synergy (lightning + projectile).
## Capacitor Magazine: projectiles that die having hit NOTHING leave a spark at the expiry point -- volume builds convert their whiffs.
extends ArtifactBase

@export var amount: float = 1.0

func get_whiff_spark_bonus() -> float:
	return amount
