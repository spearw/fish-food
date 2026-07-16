extends Node
## Headless check of BuildSummary -- the single formatter behind the stats panel and the level-up
## summary. Run with --headless.
##   1. Stat formatting: multipliers as +X% vs base; firerate presented as attack speed (1/mult);
##      projectile count uses the REAL key (the old panel queried a wrong key and overwrote the
##      projectile-speed label).
##   2. Loadout: weapons show tier (and * when evolved), granted artifacts get the ^ mark, the slot
##      line counts the shared pool.
##   3. Draft line reflects combo-gate progress.

const DAGGER := "res://systems/upgrades/weapons/daggers_unlock.tres"
const EMBER := "res://systems/upgrades/artifacts/identity/emberheart_unlock.tres"
const BuildSummary := preload("res://systems/global/build_summary.gd")

class MockPlayer:
	extends Node2D
	const ARMOR_SPEED_PENALTY: float = 0.01
	var stat_values := {
		"damage_increase": 1.331, "firerate": 0.909, "critical_hit_rate": 0.10,
		"critical_hit_damage": 0.50, "move_speed": 175.0, "luck": 1.0, "area_size": 1.0,
		"projectile_speed": 1.0, "projectile_count_multiplier": 1.4, "dot_damage_bonus": 1.0,
		"status_chance_bonus": 1.0, "pickup_radius": 150.0, "armor": 2.0,
	}
	func _init() -> void:
		var equipment := Node2D.new()
		equipment.name = "Equipment"
		add_child(equipment)
		var artifacts := Node2D.new()
		artifacts.name = "Artifacts"
		add_child(artifacts)
	func get_stat(key): return stat_values.get(key, 1.0)
	func notify_stats_changed() -> void: pass

func _ready() -> void:
	CurrentRun.selected_character = null
	CurrentRun.selected_pack_paths = []
	CurrentRun.max_loadout_slots = 5
	CurrentRun.reset_run_state()

	var player := MockPlayer.new()
	add_child(player)
	var um = load("res://systems/upgrades/upgrade_manager.gd").new()
	add_child(um)
	um.register_player(player)

	# --- 1. Stat formatting ---
	var m: Dictionary = BuildSummary.stat_map(player)
	var stats_ok: bool = m["damage"] == "Damage: +33%" \
		and m["attack_speed"] == "Attack Speed: +10%" \
		and m["crit_chance"] == "Crit Chance: 10%" \
		and m["projectile_count"] == "Projectile Count: x1.40" \
		and m["armor"] == "Armor: 2 (-2% speed)"
	print("UX stat_map: dmg='%s' atkspd='%s' projcount='%s' ok=%s" % [
		m["damage"], m["attack_speed"], m["projectile_count"], str(stats_ok)])

	# The compact line includes only what's active: DoT at +0% stays out, proj count x1.4 gets in.
	var compact: String = BuildSummary.compact_stat_line(player)
	var compact_ok: bool = not ("DoT" in compact) and ("x1.40" in compact) and ("+33%" in compact)
	print("UX compact: '%s' ok=%s" % [compact, str(compact_ok)])

	# --- 2. Loadout: tiers, evolution marker, granted marker, shared slot count ---
	um.apply_upgrade({"upgrade": load(DAGGER), "rarity": Upgrade.Rarity.RARE})
	um.apply_upgrade({"upgrade": load(EMBER), "rarity": Upgrade.Rarity.COMMON, "granted": true})
	var line: String = BuildSummary.loadout_line(um)
	var slots: String = BuildSummary.slot_line(um)
	var wname: String = BuildSummary._pretty_name(load(DAGGER).target_class_name)
	var loadout_ok: bool = ("%s (Rare)" % wname) in line and "Emberheart^" in line and slots == "Slots 1/5"
	um._owned_copies(load(DAGGER).target_class_name)[0].is_transformed = true
	var evolved_ok: bool = ("%s (Rare*)" % wname) in BuildSummary.loadout_line(um)
	print("UX loadout: '%s' | %s evolved_marker=%s ok=%s" % [line, slots, str(evolved_ok), str(loadout_ok)])

	# --- 3. Draft progress ---
	CurrentRun.deck_draft_counts = {"fire": 3, "lightning": 2}
	var draft: String = BuildSummary.draft_line()
	var draft_ok: bool = "fire 3" in draft and "lightning 2" in draft
	var pretty_ok: bool = BuildSummary._pretty_name("FireballStaffWeapon") == "Fireball Staff"
	print("UX draft: '%s' pretty='%s' ok=%s" % [draft, BuildSummary._pretty_name("FireballStaffWeapon"), str(draft_ok and pretty_ok)])

	# --- 4. Per-weapon detail: the ACTUAL numbers with player multipliers applied ---
	var dagger_node = um._owned_copies(load(DAGGER).target_class_name)[0]
	var detail: String = BuildSummary.weapon_detail_line(dagger_node, player)
	# Rare dagger 18 dmg x player 1.331 = 24; base 0.5s wait x firerate 0.909 = 2.2 atk/s.
	var detail_ok: bool = "24 dmg" in detail and "2.20 atk/s" in detail and "(Rare*" in detail
	print("UX weapon_detail: '%s' ok=%s" % [detail, str(detail_ok)])

	# --- 5. Concrete numbers on the merge preview: fill the loadout, offer the same tier ---
	for i in range(4):
		var filler := Node2D.new()
		filler.name = "Filler%d" % i
		um.player_artifacts.add_child(filler)
	var hint: String = um.describe_weapon_take(load(DAGGER), Upgrade.Rarity.RARE)
	# Rare 18 dmg -> Epic at ratio 3.2/1.8: 32. The card must SAY it.
	var hint_ok: bool = "merges into Epic" in hint and "18>32 dmg" in hint
	print("UX merge_preview: '%s' ok=%s" % [hint, str(hint_ok)])

	# --- 6. Persistent zones scale their duration with the owner's status_duration stat ---
	var cloud = load("res://items/effects/persistent_damage_effect.tscn").instantiate()
	cloud.stats = load("res://items/weapons/poison_cloud/poison_cloud_ground_stats.tres")
	cloud.allegiance = Projectile.Allegiance.PLAYER
	player.stat_values["status_duration"] = 2.0
	cloud.user = player
	add_child(cloud)
	var duration_ok: bool = absf(cloud.lifetime_timer.wait_time - cloud.stats.duration * 2.0) < 0.01
	print("UX cloud_duration: base=%.0f scaled=%.0f ok=%s" % [
		cloud.stats.duration, cloud.lifetime_timer.wait_time, str(duration_ok)])
	cloud.queue_free()

	var pass_all: bool = stats_ok and compact_ok and loadout_ok and evolved_ok and draft_ok \
		and pretty_ok and detail_ok and hint_ok and duration_ok
	print("UX RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()
