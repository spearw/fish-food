extends Node
## Headless check of the growing population floor (playtest finding: late-game skews to high-HP
## enemies and feels EMPTY -- the threat budget was met by ever-fewer bodies). Run with --headless.
## VS's own wave minimums grow across the run; our first import of the floor was static.

func _ready() -> void:
	var d = load("res://systems/spawner/encounter_director.gd").new()
	d.min_active_enemies = 6
	d.min_active_enemies_late = 48
	d.min_floor_ramp_time = 1200.0

	d.run_timer = 0.0
	var start_ok: bool = d._current_min_active() == 6
	d.run_timer = 600.0
	var mid: int = d._current_min_active()
	var mid_ok: bool = mid == 27  # halfway between 6 and 48
	d.run_timer = 1200.0
	var late_ok: bool = d._current_min_active() == 48
	d.run_timer = 99999.0
	var clamp_ok: bool = d._current_min_active() == 48
	# ramp disabled -> static floor (the old behavior stays reachable)
	d.min_floor_ramp_time = 0.0
	var static_ok: bool = d._current_min_active() == 6

	print("PACE floor: t0=6 t600=%d t1200=48 clamped=%s static_mode=%s" % [
		mid, str(late_ok and clamp_ok), str(static_ok)])

	# --- Infinite mode: past win_time the target compounds mildly per minute; before it, inert.
	d.win_time = 1200.0
	d.infinite_growth_per_minute = 1.15
	d.run_timer = 600.0
	var pre_ok: bool = d._infinite_multiplier() == 1.0
	d.run_timer = 1200.0
	var at_ok: bool = d._infinite_multiplier() == 1.0
	d.run_timer = 1260.0
	var one_min: float = d._infinite_multiplier()
	d.run_timer = 1500.0
	var five_min: float = d._infinite_multiplier()
	var inf_ok: bool = pre_ok and at_ok and absf(one_min - 1.15) < 0.001 \
		and absf(five_min - pow(1.15, 5.0)) < 0.001
	print("PACE infinite: pre=1.0 at=1.0 +1min=%.3f +5min=%.3f (want 1.15 / %.3f) ok=%s" % [
		one_min, five_min, pow(1.15, 5.0), str(inf_ok)])

	d.free()
	var pass_all: bool = start_ok and mid_ok and late_ok and clamp_ok and static_ok and inf_ok
	print("PACE RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()
