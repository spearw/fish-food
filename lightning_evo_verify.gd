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
	signal stats_changed  # component/aura user-setters connect to this
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
	# Each weapon gets its OWN holder: two instances of the same scene under one parent get
	# auto-renamed ("ChainLightningWeapon2"), which breaks the name==target check for real.
	var holder := Node.new()
	add_child(holder)
	var weapon = load(scene_path).instantiate()
	holder.add_child(weapon)
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
	var tesla_holder := Node.new()
	add_child(tesla_holder)
	var tesla = load("res://items/weapons/tesla_coil/tesla_coil.tscn").instantiate()
	tesla_holder.add_child(tesla)
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
	var epic_holder := Node.new()
	add_child(epic_holder)
	var storm_epic = load("res://items/weapons/storm_staff/storm_staff.tscn").instantiate()
	storm_epic.set_rarity(Upgrade.Rarity.EPIC)
	epic_holder.add_child(storm_epic)
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

	# ============ SECOND evolutions (every weapon has 2; alternatives, pick one per run) ========

	# --- 6. Superconductor: spark data overrides through the real merge (registry + overrides) ---
	var chain2: Dictionary = _transformed(
		"res://items/weapons/chain_lightning/chain_lightning.tscn",
		"res://systems/upgrades/weapons/lightning/chain_lightning/chain_lightning_superconductor_transform.tres")
	var spark_data: Dictionary = chain2.weapon.projectile_stats.get_effect_data(WeaponTags.Effect.SPARK)
	var super_ok: bool = chain2.ok and spark_data.get("spark_count", 0) == 2 \
		and spark_data.get("spark_bounces", 0) == 6 and spark_data.get("spark_range", 0.0) == 300.0
	print("EVO superconductor: count=%s bounces=%s range=%s ok=%s" % [
		str(spark_data.get("spark_count")), str(spark_data.get("spark_bounces")),
		str(spark_data.get("spark_range")), str(super_ok)])

	# --- 7. Tesla Field: firing stops, a permanent aura rides the user, attribution intact ---
	var tesla2_holder := Node.new()
	add_child(tesla2_holder)
	var tesla2 = load("res://items/weapons/tesla_coil/tesla_coil.tscn").instantiate()
	tesla2_holder.add_child(tesla2)
	tesla2.get_node("WeaponStatsComponent").user = mock
	var field_card: Upgrade = load(
		"res://systems/upgrades/weapons/lightning/tesla_coil/tesla_coil_field_transform.tres")
	var field_wired: bool = String(tesla2.name) == field_card.target_class_name
	tesla2.apply_transformation(field_card.key)
	var field = tesla2._field_instance
	var field_ok: bool = field_wired and is_instance_valid(field) \
		and field.get_parent() == mock and field.attribution_key == "TeslaCoilWeapon" \
		and field.stats.duration > 1000.0
	var mock_children_before: int = mock.get_child_count()
	tesla2.fire()  # transformed: must be inert (no projectiles, no second aura)
	var field_inert_ok: bool = mock.get_child_count() == mock_children_before \
		and get_tree().current_scene == self
	print("EVO tesla_field: aura=%s on_user=%s inert_fire=%s ok=%s" % [
		str(is_instance_valid(field)), str(is_instance_valid(field) and field.get_parent() == mock),
		str(field_inert_ok), str(field_ok and field_inert_ok)])

	# --- 8. Ball Lightning: the living-flame mutation set on the LOCALIZED stats ---
	var storm2: Dictionary = _transformed(
		"res://items/weapons/storm_staff/storm_staff.tscn",
		"res://systems/upgrades/weapons/lightning/storm_staff/storm_staff_ball_lightning_transform.tres")
	var ball = storm2.weapon.projectile_stats
	var ball_ok: bool = storm2.ok and ball.pierce == -1 and ball.can_retarget \
		and absf(ball.speed - 350.0 * 0.4) < 0.01 and ball.homing_strength == 3.0
	print("EVO ball_lightning: pierce=%d retarget=%s speed=%.0f ok=%s" % [
		ball.pierce, str(ball.can_retarget), ball.speed, str(ball_ok)])

	# --- 9. Thunderclap: every 3rd swing detonates (counter via _register_swing, no firing) ---
	var sword2_holder := Node.new()
	add_child(sword2_holder)
	var sword2 = load("res://items/weapons/lightning_sword/lightning_sword_weapon.tscn").instantiate()
	sword2_holder.add_child(sword2)
	sword2.get_node("WeaponStatsComponent").user = mock
	var clap_card: Upgrade = load(
		"res://systems/upgrades/weapons/lightning/lightning_sword/lightning_sword_thunderclap_transform.tres")
	var clap_wired: bool = String(sword2.name) == clap_card.target_class_name
	sword2.apply_transformation(clap_card.key)
	var claps0: int = _count(func(c): return String(c.get("attribution_key")) == "LightningSwordWeapon" if c.get("attribution_key") != null else false)
	sword2._register_swing()
	sword2._register_swing()
	var early: int = _count(func(c): return String(c.get("attribution_key")) == "LightningSwordWeapon" if c.get("attribution_key") != null else false)
	sword2._register_swing()
	var after_third: int = _count(func(c): return String(c.get("attribution_key")) == "LightningSwordWeapon" if c.get("attribution_key") != null else false)
	var clap_ok: bool = clap_wired and sword2.is_transformed \
		and early == claps0 and after_third == claps0 + 1
	print("EVO thunderclap: swings1-2=%d (base %d) swing3=%d ok=%s" % [
		early, claps0, after_third, str(clap_ok)])

	# --- 10. Arc Fan: the shotgun plumbing (weapon-local count + spread) ---
	var dagger2_holder := Node.new()
	add_child(dagger2_holder)
	var dagger2 = load("res://items/weapons/spark_dagger/spark_dagger.tscn").instantiate()
	dagger2_holder.add_child(dagger2)
	var pre_count: int = dagger2.base_projectile_count
	var fan_card: Upgrade = load(
		"res://systems/upgrades/weapons/lightning/spark_dagger/spark_dagger_arc_fan_transform.tres")
	var fan_wired: bool = String(dagger2.name) == fan_card.target_class_name
	dagger2.apply_transformation(fan_card.key)
	var fan_ok: bool = fan_wired and dagger2.is_transformed \
		and dagger2.base_projectile_count == pre_count + 2 \
		and dagger2.fire_behavior_component.spread_angle_degrees == 24.0
	print("EVO arc_fan: count %d->%d spread=%.0f ok=%s" % [
		pre_count, dagger2.base_projectile_count,
		dagger2.fire_behavior_component.spread_angle_degrees, str(fan_ok)])

	var pass_all: bool = fork_ok and no_refork_ok and tesla_ok and storm_ok \
		and cloud_scales_ok and sword_ok and needles_ok and double_ok \
		and super_ok and field_ok and field_inert_ok and ball_ok and clap_ok and fan_ok
	print("LIGHTNINGEVO RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()
