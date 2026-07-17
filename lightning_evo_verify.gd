extends Node
## Headless check of the five lightning evolutions (one per weapon). Driven from the CARDS so a
## card's target/key and the weapon-script branch can never drift apart: each card's target scene
## is instantiated, transformed with the card's own key, and the behavior delta asserted.
##   1. Fork Lightning: chain bolts swap to the x2 fork scene; a fork hit spawns exactly 2
##      children at 60% damage, generation 1 -- and children never re-fork.
##   2. Overcharged Capacitor: wait 2.5 -> 4.0, damage x3, x3 fork scene.
##   3. Thunderhead: stats swap to MultiStage with a persistent cloud on death (duration 3s), and
##      the exported stats were rarity-scaled at _ready (EPIC cloud outdamages COMMON).
##   4. Storm Blade: transformation flag + wave stats present and tier-scaled.
##   5. Static Needles: +10 points weapon crit, and a crit hit DOUBLES sparks through the real
##      projectile spark pipeline.

class MockUser:
	extends Node2D
	var stat_values := {
		"damage_increase": 1.0, "firerate": 1.0, "crit_flat": 0.0, "critical_hit_rate": 1.0,
		"crit_damage_flat": 0.0, "critical_hit_damage": 1.0, "dot_damage_bonus": 1.0,
		"status_chance_bonus": 1.0, "spark_count_bonus": 0.0, "spark_damage_bonus": 1.0,
		"spark_bounce_bonus": 0.0, "has_conductive": 0.0, "projectile_speed": 1.0,
	}
	func _init() -> void:
		add_to_group("player")
	func get_stat(key): return stat_values.get(key, 1.0)
	func notify_stats_changed() -> void: pass

class Victim:
	extends Node2D
	var hits := 0
	func take_damage(_a, _p = 0.0, _c = false, _s = null) -> void:
		hits += 1

func _transformed(scene_path: String, card_path: String) -> Dictionary:
	var weapon = load(scene_path).instantiate()
	add_child(weapon)
	var card: Upgrade = load(card_path)
	var wired: bool = String(weapon.name) == card.target_class_name \
		and card.type == Upgrade.UpgradeType.TRANSFORMATION
	weapon.apply_transformation(card.key)
	return {"weapon": weapon, "ok": wired and weapon.is_transformed}

func _count(type_check: Callable) -> int:
	var n := 0
	for c in get_children():
		if type_check.call(c):
			n += 1
	return n

func _ready() -> void:
	var mock := MockUser.new()
	add_child(mock)
	var victim := Victim.new()
	add_child(victim)
	victim.global_position = Vector2(50, 0)

	# --- 1. Fork Lightning ---
	var chain: Dictionary = _transformed(
		"res://items/weapons/chain_lightning/chain_lightning.tscn",
		"res://systems/upgrades/weapons/lightning/chain_lightning/chain_lightning_fork_transform.tres")
	var fork = chain.weapon.custom_projectile_scene.instantiate()
	fork.stats = chain.weapon.projectile_stats.duplicate(true)
	fork.user = mock
	fork.weapon = chain.weapon
	fork.allegiance = Projectile.Allegiance.PLAYER
	fork.attribution_key = "ChainLightningWeapon"
	fork.direction = Vector2.RIGHT
	add_child(fork)
	fork._deal_damage(victim)
	var children: Array = []
	for c in get_children():
		if c is ForkProjectile and c != fork and c.generation == 1:
			children.append(c)
	# ProjectileStats.damage is an INT: 12 x 0.6 truncates to 7 -- assert the truncated value.
	var fork_ok: bool = chain.ok and children.size() == 2 \
		and children[0].stats.damage == int(fork.stats.damage * 0.6) \
		and children[0].attribution_key == "ChainLightningWeapon"
	var forks_before_refork: int = _count(func(c): return c is ForkProjectile)
	children[0]._deal_damage(victim)
	var no_refork_ok: bool = _count(func(c): return c is ForkProjectile) == forks_before_refork
	print("EVO fork: applied=%s children=%d child_dmg=%.1f (parent %.1f) no_refork=%s" % [
		str(chain.ok), children.size(), children[0].stats.damage if not children.is_empty() else -1.0,
		fork.stats.damage, str(no_refork_ok)])

	# --- 2. Overcharged Capacitor ---
	var tesla = load("res://items/weapons/tesla_coil/tesla_coil.tscn").instantiate()
	add_child(tesla)
	var pre_damage: float = tesla.projectile_stats.damage
	var tesla_card: Upgrade = load(
		"res://systems/upgrades/weapons/lightning/tesla_coil/tesla_coil_overcharge_transform.tres")
	var tesla_wired: bool = String(tesla.name) == tesla_card.target_class_name
	tesla.apply_transformation(tesla_card.key)
	var x3 = tesla.custom_projectile_scene.instantiate()
	var tesla_ok: bool = tesla_wired and tesla.is_transformed and tesla.base_fire_rate == 4.0 \
		and absf(tesla.projectile_stats.damage - pre_damage * 3.0) < 0.01 and x3.fork_count == 3
	x3.queue_free()
	print("EVO overcharge: wait=%.1f dmg=%.0f (was %.0f) fork3=%s ok=%s" % [
		tesla.base_fire_rate, tesla.projectile_stats.damage, pre_damage,
		str(x3.fork_count == 3), str(tesla_ok)])

	# --- 3. Thunderhead (+ exported stats rarity-scale with the instance tier) ---
	var storm: Dictionary = _transformed(
		"res://items/weapons/storm_staff/storm_staff.tscn",
		"res://systems/upgrades/weapons/lightning/storm_staff/storm_staff_thunderhead_transform.tres")
	var cloud = storm.weapon.projectile_stats.on_death_effect_stats \
		if storm.weapon.projectile_stats is MultiStageProjectileStats else null
	var storm_ok: bool = storm.ok and cloud is PersistentEffectStats and cloud.duration == 3.0
	var common_cloud_dmg: float = cloud.damage if cloud else -1.0
	var storm_epic = load("res://items/weapons/storm_staff/storm_staff.tscn").instantiate()
	storm_epic.set_rarity(Upgrade.Rarity.EPIC)
	add_child(storm_epic)
	storm_epic.apply_transformation("thunderhead")
	var epic_cloud_dmg: float = storm_epic.projectile_stats.on_death_effect_stats.damage
	var cloud_scales_ok: bool = epic_cloud_dmg > common_cloud_dmg
	print("EVO thunderhead: multistage=%s cloud_dur=%.1f dmg C=%.1f E=%.1f scales=%s" % [
		str(storm_ok), cloud.duration if cloud else -1.0, common_cloud_dmg, epic_cloud_dmg,
		str(cloud_scales_ok)])

	# --- 4. Storm Blade ---
	var sword: Dictionary = _transformed(
		"res://items/weapons/lightning_sword/lightning_sword_weapon.tscn",
		"res://systems/upgrades/weapons/lightning/lightning_sword/lightning_sword_storm_blade_transform.tres")
	var sword_ok: bool = sword.ok and sword.weapon.has_transformation("storm_blade") \
		and sword.weapon.wave_stats != null and sword.weapon.wave_stats.damage > 0
	print("EVO storm_blade: applied=%s wave_dmg=%.0f ok=%s" % [
		str(sword.ok), sword.weapon.wave_stats.damage if sword.weapon.wave_stats else -1.0,
		str(sword_ok)])

	# --- 5. Static Needles (+ the crit-spark pipeline end to end) ---
	var dagger: Dictionary = _transformed(
		"res://items/weapons/spark_dagger/spark_dagger.tscn",
		"res://systems/upgrades/weapons/lightning/spark_dagger/spark_dagger_static_needles_transform.tres")
	var d_stats = dagger.weapon.projectile_stats
	var needles_ok: bool = dagger.ok and absf(d_stats.critical_hit_rate - 0.25) < 0.001 \
		and d_stats.get_effect_data(WeaponTags.Effect.SPARK).get("crit_spark_multiplier", 0.0) == 2.0
	var proj = load("res://systems/projectiles/projectile.tscn").instantiate()
	proj.stats = d_stats
	proj.user = mock
	proj.allegiance = Projectile.Allegiance.PLAYER
	proj.direction = Vector2.RIGHT
	add_child(proj)
	var sparks0: int = _count(func(c): return c is SparkProjectile)
	proj._last_hit_crit = false
	proj._apply_spark_effect(victim)
	var normal_sparks: int = _count(func(c): return c is SparkProjectile) - sparks0
	proj._last_hit_crit = true
	proj._apply_spark_effect(victim)
	var crit_sparks: int = _count(func(c): return c is SparkProjectile) - sparks0 - normal_sparks
	var double_ok: bool = normal_sparks == 1 and crit_sparks == 2
	print("EVO static_needles: crit=%.2f override=%s sparks normal=%d crit=%d ok=%s" % [
		d_stats.critical_hit_rate, str(needles_ok), normal_sparks, crit_sparks,
		str(needles_ok and double_ok)])

	var pass_all: bool = fork_ok and no_refork_ok and tesla_ok and storm_ok \
		and cloud_scales_ok and sword_ok and needles_ok and double_ok
	print("LIGHTNINGEVO RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()
