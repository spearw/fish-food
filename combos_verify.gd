extends Node
## Headless check of full combo coverage (July 2026): every deck PAIR has a combo. Run headless.
##   1. Registry: 10 combos (C(5,2)), unordered pairs unique, every deck id real, every synergy
##      card an UNLOCK_ARTIFACT whose scene root name matches its target (the apply lookup).
##   2. Behavior spot-checks on the novel hooks: Caustic Detonation consume math + the
##      double-detonation guard, Toxic Discharge's full-stack gate, Capacitor Magazine's
##      whiff-spark, on-hit combo statuses (Incendiary path), melee-hit payloads (Venom Blades),
##      Fever Bloom's poisoned-death ground fire.

class MockUser:
	extends Node2D
	signal stats_changed
	var stat_values := {
		"damage_increase": 1.0, "crit_flat": 0.0, "critical_hit_rate": 1.0,
		"crit_damage_flat": 0.0, "critical_hit_damage": 1.0, "dot_damage_bonus": 1.0,
		"status_chance_bonus": 1.0, "status_duration": 1.0, "dot_armor_shred": 0.0,
		"spark_count_bonus": 0.0, "spark_damage_bonus": 1.0, "spark_bounce_bonus": 0.0,
		"has_conductive": 0.0, "on_hit_burn_chance": 0.0, "on_hit_venom_chance": 0.0,
		"point_blank_bonus": 0.0, "whiff_spark": 0.0,
	}
	func _init() -> void:
		add_to_group("player")
	func get_stat(key): return stat_values.get(key, 1.0)
	func notify_stats_changed() -> void: pass

const POISON := "res://systems/status_effects/poison/poison_status_effect.tres"

func _entity() -> Node:
	var e = load("res://actors/entity.gd").new()
	e.stats = load("res://bench_dummies/dummy_baseline.tres").duplicate()
	add_child(e)
	var mgr := StatusEffectManager.new()
	mgr.name = "StatusEffectManager"
	e.add_child(mgr)
	return e

func _count(check: Callable) -> int:
	var n := 0
	for c in get_children():
		if check.call(c):
			n += 1
	return n

func _ready() -> void:
	CurrentRun.reset_run_state()
	var mock := MockUser.new()
	add_child(mock)

	# --- 1. Registry ---
	var master = load("res://systems/combos/master_combo_list.tres")
	var deck_ids: Array = []
	for deck in load("res://systems/global/lists/master_pack_list.tres").decks:
		deck_ids.append(deck.id)
	var pairs := {}
	var registry_ok: bool = master.combos.size() == 10
	for combo in master.combos:
		var key_arr: Array = [combo.deck_a_id, combo.deck_b_id]
		key_arr.sort()
		var pair_key: String = "%s+%s" % [key_arr[0], key_arr[1]]
		if pairs.has(pair_key) or combo.deck_a_id == combo.deck_b_id:
			registry_ok = false
		pairs[pair_key] = true
		if not combo.deck_a_id in deck_ids or not combo.deck_b_id in deck_ids:
			registry_ok = false
		if combo.synergies.size() < 2 or combo.power_gate < 1:
			registry_ok = false
		for synergy in combo.synergies:
			if synergy == null or synergy.type != Upgrade.UpgradeType.UNLOCK_ARTIFACT \
					or synergy.scene_to_unlock == null:
				registry_ok = false
				continue
			var node = synergy.scene_to_unlock.instantiate()
			if String(node.name) != synergy.target_class_name:
				registry_ok = false
			node.queue_free()
	print("COMBOS registry: combos=%d unique_pairs=%d ok=%s" % [
		master.combos.size(), pairs.size(), str(registry_ok)])

	# --- 2a. Caustic Detonation: stacks x 6, consumed, no double-detonation ---
	var victim = _entity()
	var mgr: StatusEffectManager = victim.get_node("StatusEffectManager")
	for i in range(3):
		mgr.apply_status(load(POISON), null, "T")
	var caustic = load("res://items/artifacts/combos/fire_venom/caustic_detonation_artifact.gd").new()
	caustic.user = mock
	add_child(caustic)
	var hp0: int = victim.current_health
	caustic._on_status_applied(victim, "burning")
	var burst: int = hp0 - victim.current_health          # 3 stacks x 6 = 18
	caustic._on_status_applied(victim, "ignited")         # same-frame second trigger: consumed -> 0
	var caustic_ok: bool = burst == 18 and victim.current_health == hp0 - 18
	print("COMBOS caustic: burst=%d (want 18) double_guard=%s" % [
		burst, str(victim.current_health == hp0 - 18)])

	# --- 2b. Toxic Discharge: below cap inert, at cap detonates 5 x 8 ---
	var victim2 = _entity()
	var mgr2: StatusEffectManager = victim2.get_node("StatusEffectManager")
	for i in range(2):
		mgr2.apply_status(load(POISON), null, "T")
	var discharge = load("res://items/artifacts/combos/lightning_venom/toxic_discharge_artifact.gd").new()
	discharge.user = mock
	add_child(discharge)
	var hp2: int = victim2.current_health
	discharge._on_spark_hit(victim2)                      # 2 stacks < cap 5 -> inert
	var below_ok: bool = victim2.current_health == hp2
	for i in range(5):
		mgr2.apply_status(load(POISON), null, "T")
	discharge._on_spark_hit(victim2)                      # at cap -> 5 x 8 = 40
	var discharge_ok: bool = below_ok and hp2 - victim2.current_health == 40
	print("COMBOS discharge: below_cap_inert=%s at_cap=%d (want 40) ok=%s" % [
		str(below_ok), hp2 - victim2.current_health, str(discharge_ok)])

	# --- 2c. Capacitor Magazine: a clean miss leaves a spark at expiry ---
	mock.stat_values["whiff_spark"] = 1.0
	var proj = load("res://systems/projectiles/projectile.tscn").instantiate()
	proj.stats = load("res://items/artifacts/combos/melee_projectile/riposte_dart_stats.tres")
	proj.user = mock
	proj.allegiance = Projectile.Allegiance.PLAYER
	proj.direction = Vector2.RIGHT
	add_child(proj)
	var sparks0: int = _count(func(c): return c is SparkProjectile)
	proj._destroy()
	var whiff_ok: bool = _count(func(c): return c is SparkProjectile) == sparks0 + 1
	mock.stat_values["whiff_spark"] = 0.0
	print("COMBOS whiff_spark: spawned=%s" % str(whiff_ok))

	# --- 2d. On-hit combo statuses (Incendiary Rounds path through the real hit pipeline) ---
	mock.stat_values["on_hit_burn_chance"] = 1.0
	var victim3 = _entity()
	var proj2 = load("res://systems/projectiles/projectile.tscn").instantiate()
	proj2.stats = load("res://items/artifacts/combos/melee_projectile/riposte_dart_stats.tres")
	proj2.user = mock
	proj2.allegiance = Projectile.Allegiance.PLAYER
	proj2.direction = Vector2.RIGHT
	add_child(proj2)
	proj2._apply_effect_tags(victim3, 5.0)
	var incendiary_ok: bool = victim3.get_node("StatusEffectManager").active_statuses.has("burning")
	mock.stat_values["on_hit_burn_chance"] = 0.0
	print("COMBOS incendiary: burning_applied=%s" % str(incendiary_ok))

	# --- 2e. Venom Blades via the melee-hit signal ---
	var blades = load("res://items/artifacts/combos/melee_venom/venom_blades_artifact.gd").new()
	blades.user = mock
	blades.venom_chance = 1.0
	add_child(blades)
	blades.on_equipped()
	var victim4 = _entity()
	Events.enemy_hit.emit({"enemy": victim4, "damage": 5, "is_crit": false})
	var blades_ok: bool = victim4.get_node("StatusEffectManager").active_statuses.has("poison")
	blades.on_unequipped()
	print("COMBOS venom_blades: poison_applied=%s" % str(blades_ok))

	# --- 2f. Fever Bloom: poisoned death leaves ground fire ---
	var bloom = load("res://items/artifacts/combos/fire_venom/fever_bloom_artifact.gd").new()
	bloom.user = mock
	bloom.bloom_chance = 1.0
	add_child(bloom)
	var victim5 = _entity()
	victim5.get_node("StatusEffectManager").apply_status(load(POISON), null, "T")
	var zones0: int = _count(func(c): return c is PersistentDamageEffect)
	bloom._on_kill(victim5)
	var bloom_ok: bool = _count(func(c): return c is PersistentDamageEffect) == zones0 + 1
	var victim6 = _entity()  # unpoisoned -> no bloom
	bloom._on_kill(victim6)
	bloom_ok = bloom_ok and _count(func(c): return c is PersistentDamageEffect) == zones0 + 1
	print("COMBOS fever_bloom: zone_on_poisoned_death=%s" % str(bloom_ok))

	CurrentRun.reset_run_state()
	var pass_all: bool = registry_ok and caustic_ok and discharge_ok and whiff_ok \
		and incendiary_ok and blades_ok and bloom_ok
	print("COMBOS RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()
