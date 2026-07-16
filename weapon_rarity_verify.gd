extends Node
## Headless check of per-instance weapon rarity. Run with --headless.
##   1. A weapon's damage scales by its rarity tier.
##   2. DoT tick damage scales too (a DoT weapon carries damage outside projectile_stats.damage).
##   3. THE BIG ONE: scaling stays per-instance. It must not leak into the shared resource, or one
##      Epic drop silently buffs every copy of that weapon in the game.
##   4. Weapons are drawable at every rarity (luck = "find a better one in the wild"); artifacts,
##      which are rules rather than numbers, are not.

const FIRE := "res://systems/upgrades/packs/fire_pack.tres"
const STAFF_UNLOCK := "res://systems/upgrades/weapons/fire/fireball_staff/fireball_staff_unlock.tres"
## Cinder Volley applies a burning DotStatusEffect, so it exercises the status-carried damage path.
const DOT_WEAPON_UNLOCK := "res://systems/upgrades/weapons/fire/cinder_volley/cinder_volley_unlock.tres"

class MockPlayer:
	extends Node2D
	func _init() -> void:
		var equipment := Node2D.new()
		equipment.name = "Equipment"
		add_child(equipment)
		var artifacts := Node2D.new()
		artifacts.name = "Artifacts"
		add_child(artifacts)
	func get_stat(_key): return 1.0
	func notify_stats_changed() -> void: pass

var _um

## Builds a weapon at a rarity via the real creation path and returns the live instance.
func _spawn(unlock_path: String, rarity: int):
	var upgrade = load(unlock_path)
	var weapon = _um.create_weapon(upgrade.scene_to_unlock.instantiate(), upgrade, rarity)
	_um.player_equipment.add_child(weapon)  # _ready() duplicates stats, then bakes rarity in
	return weapon

## The tick damage of the DoT this weapon applies, or 0 if it doesn't apply one.
func _dot_tick(weapon) -> float:
	var status = weapon.projectile_stats.status_to_apply
	return status.damage_per_tick if status is DotStatusEffect else 0.0

func _rarities_offering(bucket_owner, target: String) -> int:
	var count := 0
	for r in Upgrade.Rarity.values():
		for u in bucket_owner._unlock_buckets[r]:
			if u.target_class_name == target:
				count += 1
				break
	return count

func _ready() -> void:
	CurrentRun.selected_character = null
	CurrentRun.selected_pack_paths = [FIRE]
	CurrentRun.max_loadout_slots = 99  # not testing the cap here

	var player := MockPlayer.new()
	add_child(player)
	_um = load("res://systems/upgrades/upgrade_manager.gd").new()
	add_child(_um)
	_um.register_player(player)

	# --- 1. Damage scales with the tier ---
	var common = _spawn(STAFF_UNLOCK, Upgrade.Rarity.COMMON)
	var epic = _spawn(STAFF_UNLOCK, Upgrade.Rarity.EPIC)
	var curve: Array = common.rarity_scaling
	var base_dmg: int = common.projectile_stats.damage
	var expected_epic: int = int(round(base_dmg * curve[Upgrade.Rarity.EPIC] / curve[Upgrade.Rarity.COMMON]))
	var scales_ok: bool = epic.projectile_stats.damage == expected_epic and epic.projectile_stats.damage > base_dmg
	print("WPNRARITY scale: common=%d epic=%d expected=%d ok=%s (curve=%s)" % [
		base_dmg, epic.projectile_stats.damage, expected_epic, str(scales_ok), str(curve)])

	# --- 3. Per-instance: the Epic above must NOT have altered the shared resource ---
	# A freshly built Common has to still read base damage. If it doesn't, _apply_rarity_scaling ran
	# against the shared ProjectileStats and every fireball staff in the game just got buffed.
	var common_after = _spawn(STAFF_UNLOCK, Upgrade.Rarity.COMMON)
	var no_leak: bool = common_after.projectile_stats.damage == base_dmg \
		and common.projectile_stats.damage == base_dmg
	# And the resource on disk is untouched.
	var on_disk = load(STAFF_UNLOCK).scene_to_unlock.instantiate()
	var disk_dmg: int = on_disk.projectile_stats.damage
	var disk_clean: bool = disk_dmg == base_dmg
	on_disk.queue_free()
	print("WPNRARITY no_leak=%s (fresh common=%d, first common=%d, on-disk=%d)" % [
		str(no_leak and disk_clean), common_after.projectile_stats.damage,
		common.projectile_stats.damage, disk_dmg])

	# --- 2. DoT damage scales too. A fire weapon keeps most of its damage in the status it applies,
	#        so if this didn't scale, rarity would barely move it and merging one would feel pointless.
	var dot_common = _spawn(DOT_WEAPON_UNLOCK, Upgrade.Rarity.COMMON)
	var dot_epic = _spawn(DOT_WEAPON_UNLOCK, Upgrade.Rarity.EPIC)
	var tick_c := _dot_tick(dot_common)
	var tick_e := _dot_tick(dot_epic)
	# Fail loudly rather than pass vacuously if the chosen weapon turns out not to carry a DoT.
	var has_dot: bool = tick_c > 0.0
	var expected_ratio: float = dot_epic.get_rarity_multiplier() / dot_common.get_rarity_multiplier()
	var dot_ok: bool = has_dot and is_equal_approx(tick_e / tick_c, expected_ratio)
	print("WPNRARITY dot: has_dot=%s tick_common=%.2f tick_epic=%.2f ratio=%.2f expected=%.2f ok=%s" % [
		str(has_dot), tick_c, tick_e, tick_e / max(tick_c, 0.0001), expected_ratio, str(dot_ok)])

	# The status is a sub-resource: if duplicate(true) didn't deep-copy it, the Epic above just buffed
	# every burn in the game -- including the shared burning.tres on disk.
	var dot_fresh = _spawn(DOT_WEAPON_UNLOCK, Upgrade.Rarity.COMMON)
	var dot_no_leak: bool = is_equal_approx(_dot_tick(dot_fresh), tick_c)
	print("WPNRARITY dot_no_leak=%s (fresh common tick=%.2f, expected %.2f)" % [
		str(dot_no_leak), _dot_tick(dot_fresh), tick_c])

	# --- 5. NESTED stats scale too. This is the one that shipped broken: the fireball staff's own
	#        damage is 10 but its on-death explosion is a nested stats resource doing 25 -- the bigger
	#        half -- and checking only the root passed while the weapon barely scaled. Verify the
	#        whole tree, and that the shared resource on disk is untouched.
	var nested_common = _spawn(STAFF_UNLOCK, Upgrade.Rarity.COMMON)
	var nested_epic = _spawn(STAFF_UNLOCK, Upgrade.Rarity.EPIC)
	var boom_c = nested_common.projectile_stats.get("on_death_effect_stats")
	var boom_e = nested_epic.projectile_stats.get("on_death_effect_stats")
	var has_nested: bool = boom_c != null and boom_e != null
	var nested_ratio: float = (float(boom_e.damage) / float(boom_c.damage)) if has_nested and boom_c.damage > 0 else 0.0
	var expected_nested: float = nested_epic.get_rarity_multiplier() / nested_common.get_rarity_multiplier()
	var nested_ok: bool = has_nested and absf(nested_ratio - expected_nested) < 0.15
	var nested_disk = load(STAFF_UNLOCK).scene_to_unlock.instantiate()
	var nested_disk_ok: bool = nested_disk.projectile_stats.get("on_death_effect_stats").damage == boom_c.damage
	nested_disk.queue_free()
	print("WPNRARITY nested: explosion common=%s epic=%s ratio=%.2f expected=%.2f ok=%s disk_clean=%s" % [
		str(boom_c.damage) if has_nested else "?", str(boom_e.damage) if has_nested else "?",
		nested_ratio, expected_nested, str(nested_ok), str(nested_disk_ok)])

	# --- 6. WEIGHTED rarity scaling: the gas cloud's tiers grow its POISON harder than its slap.
	#        direct_rarity_weight 0.5 / status_rarity_weight 1.3 (authored on the weapon): at EPIC
	#        (x3.2) the zone's direct damage scales by 3.2^0.5 while the poison tick scales 3.2^1.3.
	var poison_c = _spawn("res://systems/upgrades/weapons/poison_cloud_unlock.tres", Upgrade.Rarity.COMMON)
	var poison_e = _spawn("res://systems/upgrades/weapons/poison_cloud_unlock.tres", Upgrade.Rarity.EPIC)
	var zone_c = poison_c.projectile_stats.get("on_death_effect_stats")
	var zone_e = poison_e.projectile_stats.get("on_death_effect_stats")
	var mult: float = poison_e.get_rarity_multiplier() / poison_c.get_rarity_multiplier()
	var want_dmg: int = int(round(zone_c.damage * pow(mult, poison_c.direct_rarity_weight)))
	var want_tick: float = zone_c.status_to_apply.damage_per_tick * pow(mult, poison_c.status_rarity_weight)
	# The claim is about GROWTH RATES, not absolute values (tick and zone hit run on different
	# timescales): the poison must have scaled by a larger factor than the direct hit.
	var tick_growth: float = zone_e.status_to_apply.damage_per_tick / zone_c.status_to_apply.damage_per_tick
	var dmg_growth: float = float(zone_e.damage) / float(zone_c.damage)
	var weighted_ok: bool = zone_e.damage == want_dmg \
		and absf(zone_e.status_to_apply.damage_per_tick - want_tick) < 0.01 \
		and tick_growth > dmg_growth
	print("WPNRARITY weighted: zone dmg %d->%d (want %d) tick %.1f->%.2f (want %.2f) ok=%s" % [
		zone_c.damage, zone_e.damage, want_dmg, zone_c.status_to_apply.damage_per_tick,
		zone_e.status_to_apply.damage_per_tick, want_tick, str(weighted_ok)])

	# --- 4. Weapons draw at every rarity; artifacts stay at their own ---
	var weapon_tiers := _rarities_offering(_um, "FireballStaffWeapon")
	var artifact_tiers := _rarities_offering(_um, "PyrophobiaArtifact")
	var buckets_ok: bool = weapon_tiers == Upgrade.Rarity.size() and artifact_tiers == 1
	print("WPNRARITY buckets: weapon_in=%d/%d tiers, artifact_in=%d tier ok=%s" % [
		weapon_tiers, Upgrade.Rarity.size(), artifact_tiers, str(buckets_ok)])

	var pass_all: bool = scales_ok and no_leak and disk_clean and dot_ok and dot_no_leak \
		and nested_ok and nested_disk_ok and buckets_ok and weighted_ok
	print("WPNRARITY RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()
