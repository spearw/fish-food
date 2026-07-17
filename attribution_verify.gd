extends Node
## Headless check of per-source damage attribution (UX: "what's carrying"). Run with --headless.
##   1. Choke point (entity.take_damage): POST-ARMOR damage credits the source's attribution_key;
##      keyless sources credit "Other"; armor-blocked hits credit nothing.
##   2. A null source is the DoT-tick path: the choke skips it (ticks credit themselves, stamped
##      with the weapon that applied the status -- else "Other"). No double counting.
##   3. reset_run_state clears the tally.
##   4. The report line: top-first, comma-formatted, with share percentages.

const BuildSummary := preload("res://systems/global/build_summary.gd")

class KeyedSource:
	extends Node2D
	var attribution_key: String = "Daggers"

class PlainSource:
	extends Node2D

func _make_entity(stats_path: String) -> Node:
	var e = load("res://actors/entity.gd").new()
	e.stats = load(stats_path).duplicate()
	add_child(e)
	var mgr := StatusEffectManager.new()
	mgr.name = "StatusEffectManager"
	e.add_child(mgr)
	return e

func _ready() -> void:
	CurrentRun.reset_run_state()
	var bare = _make_entity("res://bench_dummies/dummy_baseline.tres")   # armor 0, 150 hp
	var armored = _make_entity("res://bench_dummies/dummy_armor10.tres") # armor 10
	var keyed := KeyedSource.new()
	add_child(keyed)
	var plain := PlainSource.new()
	add_child(plain)

	# --- 1 + 2. Choke crediting ---
	bare.take_damage(3, 0.0, false, keyed)     # -> Daggers 3
	armored.take_damage(5, 0.0, false, keyed)  # blocked by armor 10 -> nothing
	bare.take_damage(2, 0.0, false, plain)     # keyless source -> Other 2
	bare.take_damage(4, 0.0, false, null)      # null = tick-reserved path -> nothing at the choke
	var total := 0
	for k in CurrentRun.damage_by_source:
		total += CurrentRun.damage_by_source[k]
	var choke_ok: bool = CurrentRun.damage_by_source.get("Daggers", 0) == 3 \
		and CurrentRun.damage_by_source.get("Other", 0) == 2 and total == 5
	print("ATTR choke: daggers=%d other=%d total=%d ok=%s" % [
		CurrentRun.damage_by_source.get("Daggers", 0),
		CurrentRun.damage_by_source.get("Other", 0), total, str(choke_ok)])

	# --- 2. DoT ticks credit their stamped weapon exactly once ---
	var mgr: StatusEffectManager = bare.get_node("StatusEffectManager")
	var burn: DotStatusEffect = load("res://systems/status_effects/fire/burning.tres").duplicate(true)
	burn.attribution_key = "FireballStaffWeapon"
	burn._do_damage_tick(mgr, null)  # tick 2.0 -> +2 to the staff, nothing extra anywhere
	var unstamped: DotStatusEffect = load("res://systems/status_effects/fire/burning.tres").duplicate(true)
	unstamped._do_damage_tick(mgr, null)  # no key -> Other
	var tick_ok: bool = CurrentRun.damage_by_source.get("FireballStaffWeapon", 0) == 2 \
		and CurrentRun.damage_by_source.get("Other", 0) == 4
	print("ATTR ticks: staff=%d other=%d ok=%s" % [
		CurrentRun.damage_by_source.get("FireballStaffWeapon", 0),
		CurrentRun.damage_by_source.get("Other", 0), str(tick_ok)])

	# --- 2b. apply_status stamps the per-enemy duplicate (the escalation chain inherits it) ---
	mgr.apply_status(load("res://systems/status_effects/fire/burning.tres"), null, "PoisonCloudWeapon")
	var stamped_ok := false
	for entry in mgr.active_statuses.values():
		for v in entry.values():
			if v is DotStatusEffect and v.attribution_key == "PoisonCloudWeapon":
				stamped_ok = true
	print("ATTR stamp: applied_status_carries_key=%s" % str(stamped_ok))

	# --- 3. Reset clears ---
	CurrentRun.reset_run_state()
	var reset_ok: bool = CurrentRun.damage_by_source.is_empty()

	# --- 4. Report formatting: top-first, commas, shares ---
	CurrentRun.credit_damage("Daggers", 2500)
	CurrentRun.credit_damage("PoisonCloudWeapon", 7500)
	var line: String = BuildSummary.damage_report_line()
	var line_ok: bool = line.begins_with("Damage: Poison Cloud 7,500 (75%)") \
		and "Daggers 2,500 (25%)" in line
	print("ATTR report: '%s' reset=%s ok=%s" % [line, str(reset_ok), str(line_ok)])

	CurrentRun.reset_run_state()
	var pass_all: bool = choke_ok and tick_ok and stamped_ok and reset_ok and line_ok
	print("ATTR RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()
