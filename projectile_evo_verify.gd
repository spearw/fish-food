extends Node
## Headless check of the finished Projectiles deck (July 2026). Run with --headless.
##   1. Deck shape: 5 weapons / 10 evolutions / 3 artifacts (meteor and bubble re-homed out).
##   2. All 10 evolutions, card-driven (target/key can't drift from the script branches).
##   3. Boomerang runtime: turns at half-life, homes to the thrower, Razor Return doubles the
##      return pass.
##   4. Overpressure: +pierce through the real projectile init; infinite pierce stays infinite.

class MockUser:
	extends Node2D
	signal stats_changed
	var stat_values := {
		"damage_increase": 1.0, "firerate": 1.0, "crit_flat": 0.0, "critical_hit_rate": 1.0,
		"crit_damage_flat": 0.0, "critical_hit_damage": 1.0, "dot_damage_bonus": 1.0,
		"status_chance_bonus": 1.0, "projectile_speed": 1.0, "pierce_bonus": 0.0,
	}
	func _init() -> void:
		add_to_group("player")
	func get_stat(key): return stat_values.get(key, 1.0)
	func notify_stats_changed() -> void: pass

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
	var mock := MockUser.new()
	add_child(mock)
	const P := "res://systems/upgrades/weapons/projectile/"

	# --- 1. Deck shape ---
	var deck = load("res://systems/upgrades/packs/projectile_pack.tres")
	var man: Dictionary = deck.get_manifest()
	var shape_ok: bool = man.weapons.size() == 5 and man.evolutions == 10 \
		and man.artifacts.size() == 3 and "Harpoon Gun" in man.weapons \
		and "Boomerang" in man.weapons and not "Meteor Strike" in man.weapons
	print("PROJEVO deck: weapons=%d evos=%d artifacts=%d ok=%s" % [
		man.weapons.size(), man.evolutions, man.artifacts.size(), str(shape_ok)])

	# --- 2. Evolutions ---
	var ric: Dictionary = _transformed("res://items/weapons/dagger/daggers_weapon.tscn",
		P + "daggers_ricochet_transform.tres")
	var ric_scene = ric.weapon.custom_projectile_scene.instantiate()
	var ric_ok: bool = ric.ok and ric_scene.fork_count == 1 and ric_scene.fork_damage_ratio == 0.8
	ric_scene.queue_free()

	var twin: Dictionary = _transformed("res://items/weapons/dagger/daggers_weapon.tscn",
		P + "daggers_twin_throw_transform.tres")
	var twin_ok: bool = twin.ok and twin.weapon.fire_behavior_component.fire_pattern \
		== FireBehaviorComponent.FirePattern.MIRRORED_FORWARD

	var choke: Dictionary = _transformed("res://items/weapons/shotgun/shotgun_weapon.tscn",
		P + "shotgun_choke_barrel_transform.tres")
	var choke_ok: bool = choke.ok and choke.weapon.base_projectile_count == 6 \
		and choke.weapon.fire_behavior_component.spread_angle_degrees == 10.0 \
		and choke.weapon.projectile_stats.pierce == 3 \
		and absf(choke.weapon.projectile_stats.damage - 9.0) < 0.01

	var riot: Dictionary = _transformed("res://items/weapons/shotgun/shotgun_weapon.tscn",
		P + "shotgun_riot_spread_transform.tres")
	var riot_ok: bool = riot.ok and riot.weapon.base_projectile_count == 16 \
		and riot.weapon.fire_behavior_component.spread_angle_degrees == 60.0

	var bladed: Dictionary = _transformed("res://items/weapons/spike_ring/spike_ring_weapon.tscn",
		P + "spike_ring_bladed_transform.tres")
	var bladed_ok: bool = bladed.ok and bladed.weapon.projectile_stats.pierce == -1 \
		and absf(bladed.weapon.projectile_stats.lifetime - 6.0) < 0.01

	var shrap: Dictionary = _transformed("res://items/weapons/spike_ring/spike_ring_weapon.tscn",
		P + "spike_ring_shrapnel_transform.tres")
	var shrap_ok: bool = shrap.ok \
		and shrap.weapon.projectile_stats is MultiStageProjectileStats \
		and shrap.weapon.projectile_stats.on_death_effect_stats is ExplosionStats

	var barbed: Dictionary = _transformed("res://items/weapons/harpoon_gun/harpoon_gun.tscn",
		P + "harpoon_barbed_transform.tres")
	var barbed_ok: bool = barbed.ok \
		and absf(barbed.weapon.projectile_stats.knockback_force - 225.0) < 0.01 \
		and barbed.weapon.projectile_stats.status_to_apply != null \
		and barbed.weapon.projectile_stats.status_to_apply.id == "impaled"

	var twinharp: Dictionary = _transformed("res://items/weapons/harpoon_gun/harpoon_gun.tscn",
		P + "harpoon_twin_transform.tres")
	var twinharp_ok: bool = twinharp.ok and twinharp.weapon.fire_behavior_component.fire_pattern \
		== FireBehaviorComponent.FirePattern.MIRRORED_FORWARD

	var razor: Dictionary = _transformed("res://items/weapons/boomerang/boomerang.tscn",
		P + "boomerang_razor_return_transform.tres")
	var razor_ok: bool = razor.ok and razor.weapon.razor_return == true

	var wide: Dictionary = _transformed("res://items/weapons/boomerang/boomerang.tscn",
		P + "boomerang_wide_arc_transform.tres")
	var wide_ok: bool = wide.ok and absf(wide.weapon.projectile_stats.lifetime - 2.88) < 0.01 \
		and absf(wide.weapon.projectile_stats.speed - 504.0) < 0.01

	var evo_ok: bool = ric_ok and twin_ok and choke_ok and riot_ok and bladed_ok \
		and shrap_ok and barbed_ok and twinharp_ok and razor_ok and wide_ok
	print("PROJEVO evolutions: ric=%s twin=%s choke=%s riot=%s bladed=%s shrap=%s barbed=%s twinharp=%s razor=%s wide=%s" % [
		str(ric_ok), str(twin_ok), str(choke_ok), str(riot_ok), str(bladed_ok), str(shrap_ok),
		str(barbed_ok), str(twinharp_ok), str(razor_ok), str(wide_ok)])

	# --- 3. Boomerang runtime: out, turn, home, razor double ---
	var boom = load("res://items/weapons/boomerang/boomerang_projectile.tscn").instantiate()
	var boom_stats = load("res://items/weapons/boomerang/boomerang_stats.tres").duplicate(true)
	boom_stats.lifetime = 1.0
	boom.stats = boom_stats
	boom.user = mock
	boom.weapon = razor.weapon  # razor_return = true
	boom.allegiance = Projectile.Allegiance.PLAYER
	boom.direction = Vector2.RIGHT
	add_child(boom)
	boom.global_position = Vector2(400, 0)  # far from the mock at origin: no instant catch
	var dmg_out: float = boom.damage
	boom._process(0.6)  # past half-life -> turns, razor doubles
	var flip_ok: bool = boom._returning and absf(boom.damage - dmg_out * 2.0) < 0.01 \
		and boom.direction.x < 0.0  # homing back toward the thrower at the origin
	print("PROJEVO boomerang: returning=%s dmg %.0f->%.0f homing_back=%s ok=%s" % [
		str(boom._returning), dmg_out, boom.damage, str(boom.direction.x < 0.0), str(flip_ok)])

	# --- 4. Overpressure pierce plumbing ---
	var over = load("res://items/artifacts/overpressure/overpressure_artifact.gd").new()
	add_child(over)
	var getter_ok: bool = over.get_pierce_bonus() == 1.0
	mock.stat_values["pierce_bonus"] = 2.0
	var pierced = load("res://systems/projectiles/projectile.tscn").instantiate()
	var p_stats = load("res://items/weapons/shotgun/pellet_stats.tres").duplicate(true)  # pierce 1
	pierced.stats = p_stats
	pierced.user = mock
	pierced.allegiance = Projectile.Allegiance.PLAYER
	pierced.direction = Vector2.RIGHT
	add_child(pierced)
	var pierce_ok: bool = pierced.pierce_count == 4  # (1 + 1) + 2 bonus
	var inf = load("res://systems/projectiles/projectile.tscn").instantiate()
	var inf_stats = load("res://items/weapons/harpoon_gun/harpoon_gun_stats.tres").duplicate(true)
	inf.stats = inf_stats
	inf.user = mock
	inf.allegiance = Projectile.Allegiance.PLAYER
	inf.direction = Vector2.RIGHT
	add_child(inf)
	var inf_ok: bool = inf.pierce_count == -1
	mock.stat_values["pierce_bonus"] = 0.0
	print("PROJEVO overpressure: getter=%s pierce=%d (want 4) infinite=%d (want -1) ok=%s" % [
		str(getter_ok), pierced.pierce_count, inf.pierce_count,
		str(getter_ok and pierce_ok and inf_ok)])

	var pass_all: bool = shape_ok and evo_ok and flip_ok and getter_ok and pierce_ok and inf_ok
	print("PROJEVO RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()
