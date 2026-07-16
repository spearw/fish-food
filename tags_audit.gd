extends Node
## Weapon tags audit: prints every weapon's AUTHORED effect tags beside its MEASURED mechanical
## facts (damage, fire rate, pierce, homing, knockback, pen, DoT, nested explosions/trails), so tag
## review is evidence against evidence. Tags feed BuildAnalyzer -> COUNTER_MATRIX -> the director's
## counter-spawning AND the sweep's tag attribution -- coverage quality IS attribution quality.
## Run: godot --headless --path . res://tags_audit.tscn
##
## Tagging philosophy (see .claude/balance/workflow.md): tag the IDENTITY -- the 2-4 things that
## define the weapon's combat role -- not every mechanical flag. An incidental pierce-2 on a cone
## doesn't make a flamethrower a PIERCE weapon; over-tagging smears the sweep's tag medians.

func _ready() -> void:
	var unlocks: Array = []
	_find_unlocks("res://systems/upgrades/weapons", unlocks)
	unlocks.sort()

	print("TAGSAUDIT %d weapons" % unlocks.size())
	print("%-26s %-38s %s" % ["weapon", "AUTHORED tags", "measured facts"])
	for path in unlocks:
		var upgrade = load(path)
		if upgrade == null or upgrade.scene_to_unlock == null:
			continue
		var node = upgrade.scene_to_unlock.instantiate()
		var authored: Array = []
		if "effects" in node:
			for e in node.effects:
				authored.append(WeaponTags.Effect.keys()[e])

		var facts: Array = []
		if "base_fire_rate" in node:
			facts.append("rate=%.2fs" % node.base_fire_rate)
		var seen: Array = []
		for prop in node.get_property_list():
			if prop["type"] == TYPE_OBJECT and node.get(prop["name"]) is ProjectileStats:
				_stat_facts(node.get(prop["name"]), facts, seen)
		node.free()

		print("%-26s %-38s %s" % [
			path.get_file().replace("_unlock.tres", ""),
			"[" + ", ".join(authored) + "]" if not authored.is_empty() else "[NONE]",
			" ".join(facts)])
	print("TAGSAUDIT done")
	get_tree().quit()

func _find_unlocks(dir_path: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path + "/" + entry
		if dir.current_is_dir() and not entry.begins_with("."):
			_find_unlocks(full, out)
		elif entry.contains("unlock") and entry.ends_with(".tres"):
			out.append(full)
		entry = dir.get_next()

func _stat_facts(stats, facts: Array, seen: Array) -> void:
	if stats == null or stats in seen:
		return
	seen.append(stats)
	var bits: Array = []
	if "damage" in stats and stats.damage != 0:
		bits.append("dmg=%d" % stats.damage)
	if "pierce" in stats and stats.pierce != 0:
		bits.append("pierce=%d" % stats.pierce)
	if "homing_strength" in stats and stats.homing_strength > 0:
		bits.append("homing=%.1f" % stats.homing_strength)
	if "knockback_force" in stats and stats.knockback_force > 0:
		bits.append("kb=%d" % int(stats.knockback_force))
	if "armor_penetration" in stats and stats.armor_penetration > 0:
		bits.append("pen=%.2f" % stats.armor_penetration)
	var status = stats.status_to_apply if "status_to_apply" in stats else null
	if status is DotStatusEffect:
		bits.append("DOT(%s)" % status.id)
	var cls: String = stats.get_script().get_global_name() if stats.get_script() else ""
	if cls != "" and cls != "ProjectileStats":
		bits.append("<%s>" % cls)
	if not bits.is_empty():
		facts.append("{" + " ".join(bits) + "}")
	for prop in stats.get_property_list():
		if prop["type"] == TYPE_OBJECT and stats.get(prop["name"]) is ProjectileStats:
			_stat_facts(stats.get(prop["name"]), facts, seen)
