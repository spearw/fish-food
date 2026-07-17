extends Node
## Headless check of the Venom deck build-out (July 2026). Run with --headless.
##   1. VENOM STACKING (the deck's signature): applications add stacks to the cap (5), ticks
##      scale with stacks, fire stays refresh-only by authoring (max_stacks 1).
##   2. Rename: display "Venom", id stays "toxin" (stable combo/draft anchor).
##   3. All 8 evolutions, card-driven (target/key can't drift from the script branches).
##   4. Artifacts: Outbreak's poison gate, Corrosion's per-entity armor shred through a real
##      tick + armor math, Toxic Wake dropping zones on movement.
##   5. Rolling Fog drift motion on a real zone.

class MockUser:
	extends Node2D
	signal stats_changed
	var stat_values := {
		"damage_increase": 1.0, "firerate": 1.0, "crit_flat": 0.0, "critical_hit_rate": 1.0,
		"crit_damage_flat": 0.0, "critical_hit_damage": 1.0, "dot_damage_bonus": 1.0,
		"status_chance_bonus": 1.0, "status_duration": 1.0, "dot_armor_shred": 0.0,
	}
	func _init() -> void:
		add_to_group("player")
	func get_stat(key): return stat_values.get(key, 1.0)
	func notify_stats_changed() -> void: pass

const POISON := "res://systems/status_effects/poison/poison_status_effect.tres"

func _entity(stats_path: String = "res://bench_dummies/dummy_baseline.tres") -> Node:
	var e = load("res://actors/entity.gd").new()
	e.stats = load(stats_path).duplicate()
	add_child(e)
	var mgr := StatusEffectManager.new()
	mgr.name = "StatusEffectManager"
	e.add_child(mgr)
	return e

func _transformed(scene_path: String, card_path: String) -> Dictionary:
	var holder := Node.new()
	add_child(holder)
	var weapon = load(scene_path).instantiate()
	holder.add_child(weapon)
	var card: Upgrade = load(card_path)
	var wired: bool = String(weapon.name) == card.target_class_name \
		and card.type == Upgrade.UpgradeType.TRANSFORMATION
	weapon.apply_transformation(card.key)
	return {"weapon": weapon, "ok": wired and weapon.is_transformed}

func _ready() -> void:
	CurrentRun.reset_run_state()
	var mock := MockUser.new()
	add_child(mock)

	# --- 1. Stacking ---
	var host = _entity()
	var mgr: StatusEffectManager = host.get_node("StatusEffectManager")
	for i in range(3):
		mgr.apply_status(load(POISON), null, "VenomTest")
	var venom: DotStatusEffect = mgr.active_statuses["poison"]["effect"]
	var three_ok: bool = venom.stacks == 3
	var hp0: int = host.current_health
	venom._do_damage_tick(mgr, null)
	var tick3: int = hp0 - host.current_health          # 1 dmg x 3 stacks
	for i in range(9):
		mgr.apply_status(load(POISON), null, "VenomTest")
	var cap_ok: bool = venom.stacks == 5
	var burn: DotStatusEffect = load("res://systems/status_effects/fire/burning.tres").duplicate(true)
	var fire_no_stack_ok: bool = burn.max_stacks == 1
	print("VENOM stacking: 3apps=%d tick=%d cap=%d fire_max=%d ok=%s" % [
		venom.stacks if not cap_ok else 3, tick3, venom.stacks, burn.max_stacks,
		str(three_ok and tick3 == 3 and cap_ok and fire_no_stack_ok)])
	var stack_ok: bool = three_ok and tick3 == 3 and cap_ok and fire_no_stack_ok

	# --- 2. Rename ---
	var deck = load("res://systems/upgrades/packs/toxin_pack.tres")
	var man: Dictionary = deck.get_manifest()
	var rename_ok: bool = deck.deck_name == "Venom" and deck.id == "toxin" \
		and man.weapons.size() == 4 and "Ink Jet" in man.weapons \
		and man.evolutions == 8 and man.artifacts.size() == 3
	print("VENOM deck: name=%s id=%s weapons=%d evos=%d artifacts=%d ok=%s" % [
		deck.deck_name, deck.id, man.weapons.size(), man.evolutions, man.artifacts.size(),
		str(rename_ok)])

	# --- 3. Evolutions (card-driven) ---
	var fog: Dictionary = _transformed("res://items/weapons/poison_cloud/poison_cloud_weapon.tscn",
		"res://systems/upgrades/weapons/venom/poison_cloud_rolling_fog_transform.tres")
	var fog_ok: bool = fog.ok \
		and fog.weapon.projectile_stats.on_death_effect_stats.drift_speed == 45.0

	var spore: Dictionary = _transformed("res://items/weapons/poison_cloud/poison_cloud_weapon.tscn",
		"res://systems/upgrades/weapons/venom/poison_cloud_spore_burst_transform.tres")
	spore.weapon.spore_chance = 1.0
	spore.weapon.get_node("WeaponStatsComponent").user = mock
	var victim = _entity()
	victim.get_node("StatusEffectManager").apply_status(load(POISON), null, "VenomTest")
	victim.global_position = Vector2(300, 300)
	var zones0: int = _count_zones()
	spore.weapon._on_kill(victim)
	var spore_ok: bool = spore.ok and _count_zones() == zones0 + 1
	var clean = _entity()  # NOT poisoned -> no zone
	spore.weapon._on_kill(clean)
	spore_ok = spore_ok and _count_zones() == zones0 + 1

	var viper: Dictionary = _transformed("res://items/weapons/sea_snake_fang/sea_snake_fang.tscn",
		"res://systems/upgrades/weapons/venom/sea_snake_pit_viper_transform.tres")
	var viper_scene = viper.weapon.custom_projectile_scene.instantiate()
	var viper_ok: bool = viper.ok and viper_scene.fork_count == 1 \
		and viper_scene.fork_damage_ratio == 1.0
	viper_scene.queue_free()

	var neuro: Dictionary = _transformed("res://items/weapons/sea_snake_fang/sea_snake_fang.tscn",
		"res://systems/upgrades/weapons/venom/sea_snake_neurotoxin_transform.tres")
	var neuro_status = neuro.weapon.projectile_stats.status_to_apply
	var neuro_ok: bool = neuro.ok and neuro_status.max_stack_status != null \
		and neuro_status.max_stack_status.id == "neuro_slow"

	var tide: Dictionary = _transformed("res://items/weapons/urchin_volley/urchin_volley.tscn",
		"res://systems/upgrades/weapons/venom/urchin_tidepool_transform.tres")
	var tide_ok: bool = tide.ok and tide.weapon.projectile_stats is MultiStageProjectileStats \
		and tide.weapon.projectile_stats.on_death_effect_stats is PersistentEffectStats

	var storm: Dictionary = _transformed("res://items/weapons/urchin_volley/urchin_volley.tscn",
		"res://systems/upgrades/weapons/venom/urchin_needle_storm_transform.tres")
	var storm_ok: bool = storm.ok and storm.weapon.base_projectile_count == 14 \
		and absf(storm.weapon.base_fire_rate - 1.35) < 0.001

	var deep: Dictionary = _transformed("res://items/weapons/ink_jet/ink_jet.tscn",
		"res://systems/upgrades/weapons/venom/ink_jet_deep_ink_transform.tres")
	var deep_ok: bool = deep.ok and deep.weapon.projectile_stats is MultiStageProjectileStats

	var jet: Dictionary = _transformed("res://items/weapons/ink_jet/ink_jet.tscn",
		"res://systems/upgrades/weapons/venom/ink_jet_jet_propulsion_transform.tres")
	var jet_ok: bool = jet.ok and jet.weapon.has_transformation("jet_propulsion")

	var evo_ok: bool = fog_ok and spore_ok and viper_ok and neuro_ok and tide_ok \
		and storm_ok and deep_ok and jet_ok
	print("VENOM evolutions: fog=%s spore=%s viper=%s neuro=%s tide=%s storm=%s deep=%s jet=%s" % [
		str(fog_ok), str(spore_ok), str(viper_ok), str(neuro_ok), str(tide_ok), str(storm_ok),
		str(deep_ok), str(jet_ok)])

	# --- 4. Artifacts ---
	var outbreak = load("res://items/artifacts/venom/outbreak/outbreak_artifact.gd").new()
	outbreak.user = mock
	outbreak.spread_chance = 1.0
	add_child(outbreak)
	outbreak._on_kill(victim)  # poisoned, empty registry nearby -> must not crash
	outbreak._on_kill(clean)   # unpoisoned -> gated, must not crash
	var outbreak_ok := true

	var corrosion = load("res://items/artifacts/venom/corrosion/corrosion_artifact.gd").new()
	add_child(corrosion)
	var shred_stat_ok: bool = corrosion.get_dot_armor_shred_bonus() == 1.0
	mock.stat_values["dot_armor_shred"] = 2.0
	var armored = _entity("res://bench_dummies/dummy_armor10.tres")
	var venom2: DotStatusEffect = load(POISON).duplicate(true)
	venom2.attribution_key = "VenomTest"
	venom2._do_damage_tick(armored.get_node("StatusEffectManager"), mock)
	var shred_applied_ok: bool = armored.armor_shred == 2.0
	armored.armor_shred = 8.0
	var hp_a: int = armored.current_health
	armored.take_damage(5, 0.0, false, mock)  # armor 10-8=2 -> 3 damage lands
	var shred_math_ok: bool = hp_a - armored.current_health == 3
	mock.stat_values["dot_armor_shred"] = 0.0

	var wake = load("res://items/artifacts/venom/toxic_wake/toxic_wake_artifact.gd").new()
	wake.user = mock
	add_child(wake)
	wake.set_physics_process(false)
	mock.global_position = Vector2.ZERO
	wake._physics_process(0.016)          # first call only anchors
	var wake0: int = _count_zones()
	mock.global_position = Vector2(60, 0)
	wake._physics_process(0.016)          # moved past spacing -> drop a wake zone
	var wake_ok: bool = _count_zones() == wake0 + 1
	var art_ok: bool = outbreak_ok and shred_stat_ok and shred_applied_ok and shred_math_ok \
		and wake_ok
	print("VENOM artifacts: outbreak=%s corrosion(stat=%s applied=%s math=%s) wake=%s" % [
		str(outbreak_ok), str(shred_stat_ok), str(shred_applied_ok), str(shred_math_ok),
		str(wake_ok)])

	# --- 5. Rolling Fog drift motion ---
	var zone = load("res://items/effects/persistent_damage_effect.tscn").instantiate()
	var drift_stats = load("res://items/weapons/poison_cloud/spore_cloud_stats.tres").duplicate(true)
	drift_stats.drift_speed = 45.0
	zone.stats = drift_stats
	zone.user = mock
	add_child(zone)
	zone.global_position = Vector2.ZERO
	var prey := Node2D.new()
	add_child(prey)
	prey.global_position = Vector2(100, 0)
	zone._drift_target = prey
	zone._drift_requery = 99.0
	zone._physics_process(0.1)
	var drift_ok: bool = absf(zone.global_position.x - 4.5) < 0.01
	print("VENOM drift: x=%.2f (want 4.50) ok=%s" % [zone.global_position.x, str(drift_ok)])

	CurrentRun.reset_run_state()
	var pass_all: bool = stack_ok and rename_ok and evo_ok and art_ok and drift_ok
	print("VENOM RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()

func _count_zones() -> int:
	var n := 0
	for c in get_children():
		if c is PersistentDamageEffect:
			n += 1
	return n
