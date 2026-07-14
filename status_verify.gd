extends Node
## Headless correctness check for the StatusEffectManager idle-processing change.
## Confirms: (1) a fresh manager is idle (physics processing OFF), (2) applying a DOT turns processing
## ON and the DOT actually ticks damage over time, (3) after the DOT expires the manager goes back to
## idle with no active statuses. Prints a PASS/FAIL line and quits. Run with --headless.

class MockHost:
	extends Node2D
	var total_damage: float = 0.0
	func take_damage(amount, _armor_pen = 0, _is_crit = false, _src = null) -> void:
		total_damage += amount

func _ready() -> void:
	var host := MockHost.new()
	add_child(host)
	var mgr := StatusEffectManager.new()
	host.add_child(mgr)
	mgr._ready()

	var idle_before := not mgr.is_physics_processing()

	var dot := DotStatusEffect.new()
	dot.id = "verify_burn"
	dot.duration = 0.4
	dot.damage_per_tick = 5.0
	dot.time_between_ticks = 0.1
	mgr.apply_status(dot, null)

	var processing_after_apply := mgr.is_physics_processing()
	var dmg_after_first_tick := host.total_damage  # on_apply does an immediate tick

	# Let it tick and expire (~0.4s of ticks, then duration timer fires).
	await get_tree().create_timer(0.8).timeout

	var ticked_over_time := host.total_damage > dmg_after_first_tick  # more ticks landed after the first
	var idle_after_expiry := not mgr.is_physics_processing()          # expired -> should stop processing
	var active_empty := mgr.active_statuses.is_empty()

	var ok := idle_before and processing_after_apply and dmg_after_first_tick > 0.0 \
		and ticked_over_time and idle_after_expiry and active_empty
	print("STATUSVERIFY idle_before=%s proc_after_apply=%s first_tick_dmg=%.1f total_dmg=%.1f ticked_over_time=%s idle_after_expiry=%s active_empty=%s RESULT=%s" % [
		str(idle_before), str(processing_after_apply), dmg_after_first_tick, host.total_damage,
		str(ticked_over_time), str(idle_after_expiry), str(active_empty),
		"PASS" if ok else "FAIL"])
	get_tree().quit()
