## build_summary.gd
## THE single source of truth for displaying the player's build -- stats, loadout, slots, draft
## progress. Both the stats panel and the level-up screen consume these, so the two can never
## disagree again (the old stats panel drifted: duplicate label writes, wrong keys, raw multipliers
## shown as percentages).
##
## No class_name on purpose (avoids the global-class-cache rebuild); consumers preload this script
## and call the statics:
##   const BuildSummary := preload("res://systems/global/build_summary.gd")

## Every player stat as a formatted display line, keyed for the stats panel's fixed labels.
## Presentation rules:
##  - Multipliers show as +X% relative to base (x1.33 -> "+33%").
##  - firerate is a WAIT multiplier (lower = better); players think in attack speed, so it shows as
##    +X% attack speed (1/mult - 1).
static func stat_map(player) -> Dictionary:
	var m := {}
	m["damage"] = "Damage: %+d%%" % roundi(100.0 * player.get_stat("damage_increase") - 100.0)
	var fr: float = maxf(player.get_stat("firerate"), 0.01)
	m["attack_speed"] = "Attack Speed: %+d%%" % roundi((1.0 / fr - 1.0) * 100.0)
	m["crit_chance"] = "Crit Chance: %d%%" % roundi(100.0 * player.get_stat("critical_hit_rate"))
	m["crit_damage"] = "Crit Damage: +%d%%" % roundi(100.0 * player.get_stat("critical_hit_damage"))
	m["move_speed"] = "Move Speed: %.0f" % player.get_stat("move_speed")
	m["luck"] = "Luck: %.2f" % player.get_stat("luck")
	m["area"] = "Area: %+d%%" % roundi(100.0 * player.get_stat("area_size") - 100.0)
	m["projectile_speed"] = "Projectile Speed: %+d%%" % roundi(100.0 * player.get_stat("projectile_speed") - 100.0)
	m["projectile_count"] = "Projectile Count: x%.2f" % player.get_stat("projectile_count_multiplier")
	m["dot"] = "DoT Damage: %+d%%" % roundi(100.0 * player.get_stat("dot_damage_bonus") - 100.0)
	m["status_chance"] = "Status Chance: %+d%%" % roundi(100.0 * player.get_stat("status_chance_bonus") - 100.0)
	m["pickup"] = "Pickup Radius: %.0f" % player.get_stat("pickup_radius")
	var armor: float = player.get_stat("armor")
	m["armor"] = "Armor: %d (-%.0f%% speed)" % [armor, armor * player.ARMOR_SPEED_PENALTY * 100.0]
	return m

## One dense line of the stats that drive draft decisions, for the level-up screen.
static func compact_stat_line(player) -> String:
	var m := stat_map(player)
	var parts: Array = [m["damage"], m["attack_speed"], m["crit_chance"], m["move_speed"]]
	# Extras only when they're doing something -- the compact line stays readable.
	if roundi(100.0 * player.get_stat("dot_damage_bonus") - 100.0) != 0:
		parts.append(m["dot"])
	if roundi(100.0 * player.get_stat("status_chance_bonus") - 100.0) != 0:
		parts.append(m["status_chance"])
	if player.get_stat("projectile_count_multiplier") != 1.0:
		parts.append(m["projectile_count"])
	if roundi(100.0 * player.get_stat("area_size") - 100.0) != 0:
		parts.append(m["area"])
	return " | ".join(parts)

## "Slots 3/5" -- the shared weapon+artifact pool (granted items don't count; they were never picks).
static func slot_line(um) -> String:
	return "Slots %d/%d" % [um.get_used_slots(), CurrentRun.max_loadout_slots]

## The loadout, human-readable: weapons with tier (and * for evolved), artifacts (with a dagger mark
## for granted identity/combo pieces). "Dagger (Rare), Fireball Staff (Epic*) | Emberheart^"
static func loadout_line(um) -> String:
	var weapons: Array = []
	if is_instance_valid(um.player_equipment):
		for w in um.player_equipment.get_children():
			if not ("rarity" in w):
				continue
			var entry := "%s (%s%s)" % [
				_pretty_name(String(w.get_meta("weapon_type", w.name))),
				Upgrade.Rarity.keys()[w.rarity].capitalize(),
				"*" if w.is_transformed else ""]
			weapons.append(entry)
	var artifacts: Array = []
	if is_instance_valid(um.player_artifacts):
		for a in um.player_artifacts.get_children():
			artifacts.append(_pretty_name(String(a.name)) + ("^" if um.is_granted(a) else ""))
	var parts: Array = []
	if not weapons.is_empty():
		parts.append(", ".join(weapons))
	if not artifacts.is_empty():
		parts.append(", ".join(artifacts))
	return " | ".join(parts) if not parts.is_empty() else "(nothing equipped)"

## Combo-gate progress: "Drafted: fire 3, lightning 2". Empty string before any themed draft.
static func draft_line() -> String:
	if CurrentRun.deck_draft_counts.is_empty():
		return ""
	var parts: Array = []
	for deck_id in CurrentRun.deck_draft_counts:
		if String(deck_id) == "":
			continue
		parts.append("%s %d" % [deck_id, CurrentRun.deck_draft_counts[deck_id]])
	return "Drafted: " + ", ".join(parts) if not parts.is_empty() else ""

## Live numbers for ONE weapon: what it actually does with the player's multipliers applied.
## The global screen shows multipliers ("Damage +33%"); this shows the result ("24 dmg/hit") --
## per-weapon damage is otherwise invisible (playtest finding, Jul 2026).
static func weapon_detail_line(weapon, player) -> String:
	var bits: Array = []
	var dmg_mult: float = player.get_stat("damage_increase")
	var dot_mult: float = player.get_stat("dot_damage_bonus")

	if "base_fire_rate" in weapon and weapon.base_fire_rate > 0:
		var wait: float = weapon.base_fire_rate * maxf(player.get_stat("firerate"), 0.01)
		bits.append("%.2f atk/s" % (1.0 / wait))
	var stats_comp = weapon.get_node_or_null("WeaponStatsComponent")
	if stats_comp and stats_comp.has_method("get_final_projectile_count"):
		var count: int = stats_comp.get_final_projectile_count()
		if count > 1:
			bits.append("x%d proj" % count)

	if weapon.has_method("get_damage_sources"):
		for s in weapon.get_damage_sources():
			if s["damage"] > 0:
				var hit := "%d dmg" % roundi(s["damage"] * dmg_mult)
				if s["armor_pen"] > 0:
					hit += " (%d%% pen)" % roundi(s["armor_pen"] * 100)
				bits.append(hit)
			if s.get("dot_tick", 0.0) > 0:
				bits.append("%.1f/tick dot" % (s["dot_tick"] * dot_mult))

	var tier: String = Upgrade.Rarity.keys()[weapon.rarity].capitalize() if "rarity" in weapon else "?"
	return "%s (%s%s): %s" % [
		_pretty_name(String(weapon.get_meta("weapon_type", weapon.name))), tier,
		"*" if ("is_transformed" in weapon and weapon.is_transformed) else "",
		" | ".join(bits) if not bits.is_empty() else "no damage sources"]

## The weapon's headline numbers for upgrade previews: its biggest direct hit and biggest DoT tick.
static func weapon_numbers(weapon) -> Dictionary:
	var best_dmg := 0.0
	var best_tick := 0.0
	if weapon.has_method("get_damage_sources"):
		for s in weapon.get_damage_sources():
			best_dmg = maxf(best_dmg, s["damage"])
			best_tick = maxf(best_tick, s.get("dot_tick", 0.0))
	return {"dmg": best_dmg, "tick": best_tick}

## "FireballStaffWeapon" -> "Fireball Staff"; "EmberheartArtifact" -> "Emberheart".
static func _pretty_name(raw: String) -> String:
	var s := raw.trim_suffix("Weapon").trim_suffix("Artifact")
	var out := ""
	for i in range(s.length()):
		if i > 0 and s[i] == s[i].to_upper() and s[i] != s[i].to_lower():
			out += " "
		out += s[i]
	return out
