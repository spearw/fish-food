## extra_barrels_artifact.gd
## Shotgunner's identity artifact: more barrels. Every projectile weapon he holds fires extra
## projectiles -- ANY weapon becomes a shotgun in his hands.
extends ArtifactBase

@export var bonus_projectiles: int = 2

## Summed additively by Player.get_artifact_projectile_bonus() before the projectile-count
## multiplier applies, so the bonus itself scales with count upgrades.
func get_projectile_bonus() -> int:
	return bonus_projectiles
