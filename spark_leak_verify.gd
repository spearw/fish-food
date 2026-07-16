extends Node
## Headless regression check for the spark pool leak (playtest report: sparks float around slowly,
## never die, then sparks stop spawning entirely). Run with --headless.
##   1. FIRST life honors the CALLER'S lifetime (not the scene default: _ready used to arm the timer
##      before the spawner configured it, so every first life ran on 5s).
##   2. REUSED sparks die by lifetime (the leak: _destroy stopped the timer, reset never re-armed it
##      -- reused wanderers were immortal, accumulated to the pool cap, get_spark went null).
##   3. The pool's active counter returns to zero both times (the "sparks stopped spawning" half).
##   4. Homing keeps direction UNIT-LENGTH (slerp, not lerp -- lerp shrank it on hard turns, which
##      was the "floating slowly" half).

func _ready() -> void:
	# No enemies exist here, so a spark can never exhaust its bounces -- lifetime is its ONLY exit.
	# That is exactly the wanderer case that leaked.
	var spark = ProjectilePool.get_spark()
	add_child_if_needed(spark)
	spark.allegiance = SparkProjectile.Allegiance.PLAYER
	spark.lifetime = 0.2
	spark.global_position = Vector2(10000, 10000)

	await get_tree().create_timer(0.6).timeout
	var first_ok: bool = spark._is_destroying and ProjectilePool._active_sparks == 0
	print("SPARKLEAK first_life: destroyed=%s active=%d ok=%s" % [
		str(spark._is_destroying), ProjectilePool._active_sparks, str(first_ok)])

	# --- 2. The reuse leak: get the SAME spark back from the pool, configure, let it live ---
	var reused = ProjectilePool.get_spark()
	add_child_if_needed(reused)
	reused.allegiance = SparkProjectile.Allegiance.PLAYER
	reused.lifetime = 0.2
	reused.global_position = Vector2(10000, 10000)
	var was_same: bool = reused == spark  # pooled reuse, the exact path that leaked

	await get_tree().create_timer(0.6).timeout
	var reuse_ok: bool = reused._is_destroying and ProjectilePool._active_sparks == 0
	print("SPARKLEAK reused: same_node=%s destroyed=%s active=%d ok=%s" % [
		str(was_same), str(reused._is_destroying), ProjectilePool._active_sparks, str(reuse_ok)])

	# --- 4. Homing keeps unit speed: aim at a target BEHIND the spark, step once ---
	var third = ProjectilePool.get_spark()
	add_child_if_needed(third)
	third.allegiance = SparkProjectile.Allegiance.PLAYER
	third.lifetime = 5.0
	third.global_position = Vector2.ZERO
	third.direction = Vector2.RIGHT
	var behind := Node2D.new()
	behind.global_position = Vector2(-500, 1)  # nearly dead-opposite: lerp would crush the magnitude
	add_child(behind)
	third.target = behind
	third._process(0.016)
	var dir_len: float = third.direction.length()
	var slerp_ok: bool = absf(dir_len - 1.0) < 0.01
	print("SPARKLEAK homing: direction_length=%.3f (lerp would be ~0.5) ok=%s" % [dir_len, str(slerp_ok)])
	third._destroy()

	await get_tree().process_frame

	# --- The GENERIC pool's twin leak: a pooled projectile that became unpoolable at runtime
	#     (retarget/phasing evolutions -> _destroy queue_frees it instead of returning it) must
	#     still release its cap slot. Pre-fix, every Living Flame shot leaked +1 until the 300 cap
	#     silenced every pooled weapon -- including all enemy ranged attacks (the eel bug).
	var before_generic: int = ProjectilePool._active_generic
	var p = ProjectilePool.get_projectile()
	add_child_if_needed(p)
	var got_slot: bool = ProjectilePool._active_generic == before_generic + 1
	var s := ProjectileStats.new()
	s.lifetime = 0.0
	s.can_retarget = true  # the evolution state that made it unpoolable
	p.stats = s
	# fire_behavior marks every pool-obtained projectile pooled (activate() on reuse, direct
	# assignment on a fresh instantiate) -- mimic the fresh path.
	p._is_pooled = true
	p._destroy()
	var generic_ok: bool = got_slot and ProjectilePool._active_generic == before_generic
	print("SPARKLEAK generic_abandon: slot_taken=%s released_after_destroy=%s (active=%d)" % [
		str(got_slot), str(ProjectilePool._active_generic == before_generic), ProjectilePool._active_generic])

	var pass_all: bool = first_ok and reuse_ok and slerp_ok and generic_ok \
		and ProjectilePool._active_sparks == 0
	print("SPARKLEAK RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()

func add_child_if_needed(node: Node) -> void:
	if node and not node.is_inside_tree():
		add_child(node)
