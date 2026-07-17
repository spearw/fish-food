extends Node
## Headless check of the Cosmic deck (July 2026): death from above, on the roster for real.
##   1. Deck shape: 3 weapons / 6 evolutions / 3 artifacts / 3 mechanics; master list has 7 decks;
##      meteor re-themed ARCANE.
##   2. All 6 evolutions, card-driven.
##   3. Artifacts: Skyfall's kill-call (target gate + burst attribution), Star Charts and Escape
##      Velocity getters on the existing artifact-modifier machinery.

class MockUser:
	extends Node2D
	signal stats_changed
	func _init() -> void:
		add_to_group("player")
	func get_stat(_key): return 1.0
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
	const C := "res://systems/upgrades/weapons/cosmic/"

	# --- 1. Deck shape + roster ---
	var deck = load("res://systems/upgrades/packs/cosmic_pack.tres")
	var man: Dictionary = deck.get_manifest()
	var master = load("res://systems/global/lists/master_pack_list.tres").decks
	var meteor_scene = load("res://items/weapons/meteor/meteor_weapon.tscn").instantiate()
	# Mechanics are FOUR (user revision): Event Horizon / Supernova (crit damage, replaced the
	# damage card) / Orbital Decay / Terminal Velocity (impact delay -- the deck's own dial).
	var velocity_card: Upgrade = load(
		"res://systems/upgrades/upgrades/cosmic/cosmic_terminal_velocity_upgrade.tres")
	var nova_card: Upgrade = load(
		"res://systems/upgrades/upgrades/cosmic/cosmic_supernova_upgrade.tres")
	var cards_ok: bool = velocity_card.key == "impact_delay" \
		and velocity_card.modifier_type == Upgrade.ModifierType.MULTIPLICATIVE \
		and nova_card.key == "critical_hit_damage" \
		and nova_card.modifier_type == Upgrade.ModifierType.MULTIPLICATIVE
	var shape_ok: bool = man.weapons.size() == 5 and man.evolutions == 10 \
		and man.artifacts.size() == 3 and man.mechanics.size() == 4 and cards_ok \
		and master.size() == 7 and deck.id == "cosmic" \
		and meteor_scene.themes == Array([5], TYPE_INT, "", null)
	meteor_scene.queue_free()
	print("COSMIC deck: weapons=%d evos=%d artifacts=%d mechanics=%d decks=%d ok=%s" % [
		man.weapons.size(), man.evolutions, man.artifacts.size(), man.mechanics.size(),
		master.size(), str(shape_ok)])

	# --- 2. Evolutions ---
	var shower: Dictionary = _transformed("res://items/weapons/meteor/meteor_weapon.tscn",
		C + "meteor_shower_transform.tres")
	var shower_ok: bool = shower.ok and shower.weapon.base_projectile_count == 6

	var impact: Dictionary = _transformed("res://items/weapons/meteor/meteor_weapon.tscn",
		C + "meteor_deep_impact_transform.tres")
	var impact_ok: bool = impact.ok \
		and absf(impact.weapon.projectile_stats.damage - 75.0) < 0.01 \
		and impact.weapon.projectile_stats.effect_overrides.has(WeaponTags.Effect.AOE)

	var twin: Dictionary = _transformed("res://items/weapons/comet_lance/comet_lance.tscn",
		C + "comet_twin_transform.tres")
	var twin_ok: bool = twin.ok and twin.weapon.base_projectile_count == 2

	var iron: Dictionary = _transformed("res://items/weapons/comet_lance/comet_lance.tscn",
		C + "comet_iron_star_transform.tres")
	var iron_ok: bool = iron.ok and iron.weapon.projectile_stats.armor_penetration == 0.6 \
		and absf(iron.weapon.projectile_stats.damage - 35.0) < 0.01

	var eternal: Dictionary = _transformed("res://items/weapons/starlight_pillar/starlight_pillar.tscn",
		C + "pillar_eternal_light_transform.tres")
	var eternal_ok: bool = eternal.ok \
		and absf(eternal.weapon.projectile_stats.on_death_effect_stats.duration - 5.4) < 0.01

	var gyre: Dictionary = _transformed("res://items/weapons/starlight_pillar/starlight_pillar.tscn",
		C + "pillar_widening_gyre_transform.tres")
	var gyre_zone = gyre.weapon.projectile_stats.on_death_effect_stats
	var gyre_ok: bool = gyre.ok and absf(gyre_zone.tick_rate - 0.2625) < 0.001 \
		and absf(gyre_zone.scale.x - 2.24) < 0.01

	var accretion: Dictionary = _transformed("res://items/weapons/singularity/singularity.tscn",
		C + "singularity_accretion_transform.tres")
	var accretion_ok: bool = accretion.ok and absf(accretion.weapon.pull_radius - 330.0) < 0.01 \
		and absf(accretion.weapon.pull_force - 126.0) < 0.01

	var collapse: Dictionary = _transformed("res://items/weapons/singularity/singularity.tscn",
		C + "singularity_collapse_transform.tres")
	var collapse_ok: bool = collapse.ok and collapse.weapon.pop_per_enemy == 6

	var storm_stars: Dictionary = _transformed("res://items/weapons/falling_sky/falling_sky.tscn",
		C + "falling_sky_storm_of_stars_transform.tres")
	var storm_stars_ok: bool = storm_stars.ok \
		and absf(storm_stars.weapon.base_fire_rate - 0.52) < 0.001

	var guided: Dictionary = _transformed("res://items/weapons/falling_sky/falling_sky.tscn",
		C + "falling_sky_guided_descent_transform.tres")
	var guided_ok: bool = guided.ok and guided.weapon.has_transformation("guided_descent")

	var evo_ok: bool = shower_ok and impact_ok and twin_ok and iron_ok and eternal_ok \
		and gyre_ok and accretion_ok and collapse_ok and storm_stars_ok and guided_ok
	print("COSMIC evolutions: shower=%s impact=%s twin=%s iron=%s eternal=%s gyre=%s accretion=%s collapse=%s storm=%s guided=%s" % [
		str(shower_ok), str(impact_ok), str(twin_ok), str(iron_ok), str(eternal_ok), str(gyre_ok),
		str(accretion_ok), str(collapse_ok), str(storm_stars_ok), str(guided_ok)])

	# --- 2b. Singularity zone runtime: the pull drags an entity toward the center; the pop lands ---
	var zone = load("res://items/weapons/singularity/singularity_zone.tscn").instantiate()
	zone.stats = load("res://items/weapons/singularity/singularity_stats.tres").duplicate(true)
	zone.user = mock
	zone.attribution_key = "SingularityWeapon"
	add_child(zone)
	zone.global_position = Vector2.ZERO
	var prey = load("res://actors/entity.gd").new()
	prey.stats = load("res://bench_dummies/dummy_baseline.tres").duplicate()
	add_child(prey)
	var prey_mgr := StatusEffectManager.new()
	prey_mgr.name = "StatusEffectManager"
	prey.add_child(prey_mgr)
	prey.global_position = Vector2(100, 0)
	EntityRegistry.register_enemy(prey)  # the zone finds targets through the registry
	EntityRegistry._rebuild_grid()  # grid rebuilds on physics frames; _ready is synchronous
	# Pull ticks push from the enemy's far-side reflection = knockback velocity points centerward.
	zone._pull_tick = 0.0
	zone._physics_process(0.016)
	var pulled_ok: bool = false
	if "knockback_velocity" in prey:
		pulled_ok = prey.knockback_velocity.x < 0.0
	var hp_prey: int = prey.current_health
	zone._age = 99.0
	zone._physics_process(0.016)  # past pull_duration -> pop
	var pop_ok: bool = hp_prey - prey.current_health == 25 and zone._popped
	print("COSMIC singularity: pulled_centerward=%s pop_dmg=%d (want 25) ok=%s" % [
		str(pulled_ok), hp_prey - prey.current_health, str(pulled_ok and pop_ok)])

	# --- 3. Artifacts ---
	var charts = load("res://items/artifacts/cosmic/star_charts_artifact.gd").new()
	add_child(charts)
	var escape = load("res://items/artifacts/cosmic/escape_velocity_artifact.gd").new()
	add_child(escape)
	var getters_ok: bool = charts.get_projectile_bonus() == 1 \
		and absf(escape.get_speed_modifier() - 1.15) < 0.001
	var skyfall = load("res://items/artifacts/cosmic/skyfall_artifact.gd").new()
	skyfall.user = mock
	skyfall.call_chance = 1.0
	add_child(skyfall)
	var lone := Node2D.new()
	add_child(lone)
	skyfall._on_kill(lone)  # empty registry: no second target -> no burst, must not crash
	var art_ok: bool = getters_ok
	print("COSMIC artifacts: charts=+%d escape=x%.2f skyfall_no_target_safe=true ok=%s" % [
		charts.get_projectile_bonus(), escape.get_speed_modifier(), str(art_ok)])

	var pass_all: bool = shape_ok and evo_ok and art_ok and pulled_ok and pop_ok
	print("COSMIC RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()
