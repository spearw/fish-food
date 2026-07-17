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
const PROJECTILE := "res://systems/upgrades/packs/projectile_pack.tres"
const BuildSummary := preload("res://systems/global/build_summary.gd")

class MockPlayer:
	extends Node2D
	const ARMOR_SPEED_PENALTY: float = 0.01
	var stat_values := {
		"damage_increase": 1.331, "firerate": 0.909,
		# Two-layer crit: flat points + card multiplier (DamageUtils.compose_crit).
		"crit_flat": 0.10, "critical_hit_rate": 1.20,
		"crit_damage_flat": 0.50, "critical_hit_damage": 1.0,
		"move_speed": 175.0, "luck": 1.0, "area_size": 1.0,
		"projectile_speed": 1.0, "projectile_count_multiplier": 1.4, "dot_damage_bonus": 1.0,
		"status_chance_bonus": 1.0, "pickup_radius": 150.0, "armor": 2.0,
		"max_health": 120.0, "spark_count_bonus": 0.0, "spark_damage_bonus": 1.0,
		"spark_bounce_bonus": 0.0,
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
	# One real deck in the run so deck_tag has a pool-to-deck map to read (the dagger card is
	# projectile's; load() caching makes the pool's card and load(DAGGER) the same resource).
	CurrentRun.selected_pack_paths = [PROJECTILE] as Array[String]
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
		and m["crit_chance"] == "Crit: +10% base (x1.20 cards)" \
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
	# Rare dagger 18 dmg x player 1.331 = 24; base 0.5s wait x firerate 0.909 = 2.2 atk/s;
	# effective crit = (daggers' base 15% + flat 10%) x cards 1.20 = 30% -> "30% crit".
	var detail_ok: bool = "24 dmg" in detail and "2.20 atk/s" in detail and "(Rare*" in detail \
		and "30% crit" in detail
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

	# --- 7. Deck-economy legibility (UX pass, July 2026): manifests from card data, the combined
	#        pool preview (present/x2-gold/dim-missing stats), before->after card previews from the
	#        same routing apply_upgrade uses, and deck tags on cards ---
	var lightning: Deck = load("res://systems/upgrades/packs/lightning_pack.tres")
	var melee: Deck = load("res://systems/upgrades/packs/melee_pack.tres")
	var man_lines: String = "\n".join(BuildSummary.deck_manifest_lines(lightning))
	var manifest_ok: bool = "Spark Dagger" in man_lines and "Damage" in man_lines \
		and "Max Health" in man_lines and "Spark Surge" in man_lines
	var pool: String = BuildSummary.pool_preview([lightning, melee])
	var pool_ok: bool = "46 cards, 9 weapons" in pool \
		and "[color=gold]Damage x2[/color]" in pool and "Crit Chance x2" in pool \
		and "[color=#606060]Area Size[/color]" in pool
	var armor_prev: String = BuildSummary.stat_card_preview(player,
		load("res://systems/upgrades/upgrades/core/player_armor.tres"), Upgrade.Rarity.RARE)
	var split_prev: String = BuildSummary.stat_card_preview(player,
		load("res://systems/upgrades/upgrades/projectile/split_fire_upgrade.tres"), Upgrade.Rarity.COMMON)
	var dmg_prev: String = BuildSummary.stat_card_preview(player,
		load("res://systems/upgrades/upgrades/core/player_damage.tres"), Upgrade.Rarity.COMMON)
	var preview_ok: bool = armor_prev == "+1 (2 -> 3)" and split_prev == "+15% (+0% -> +15%)" \
		and dmg_prev == "+10% more (x1.00 -> x1.10)"
	var extras: String = BuildSummary.extras_line(player)
	var extras_ok: bool = "Max Health: 120" in extras and "Status Duration: +100%" in extras \
		and not "Sparks" in extras
	var tag: String = um.deck_tag(load(DAGGER))
	var tag_ok: bool = tag == "  [Projectile]"
	print("UX deck_economy: manifest=%s pool=%s previews(armor='%s' split='%s' dmg='%s')=%s extras=%s tag='%s'" % [
		str(manifest_ok), str(pool_ok), armor_prev, split_prev, dmg_prev,
		str(preview_ok), str(extras_ok), tag])

	var pass_all: bool = stats_ok and compact_ok and loadout_ok and evolved_ok and draft_ok \
		and pretty_ok and detail_ok and hint_ok and duration_ok \
		and manifest_ok and pool_ok and preview_ok and extras_ok and tag_ok
	print("UX RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()
