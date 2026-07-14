extends CharacterBody2D
## Benchmark-only stub player: absorbs the contact-damage callbacks enemies now make
## via the distance check, with no-ops, so the perf run doesn't error.

func take_damage(_amount, _armor_pen, _is_crit, _source = null) -> void:
	pass

func apply_knockback(_force, _from) -> void:
	pass
