## balance_sweep_analyze.gd
## The counter-grid pipeline's math half (see .claude/balance/workflow.md). Reads the sweep CSV and
## runs the double normalization agreed Jul 2026:
##
##   R = dps / weapon's own baseline dps
##       -- removes WEAPON POWER. A strong weapon isn't "strong against everything" in counter terms;
##          transitive strength is a balance question, not a counter question.
##   Z = R / (per-column median of R across all measured weapons)
##       -- removes CATEGORY HARDNESS. Everything melts small soft targets; a weapon only counts as
##          weak/strong vs a category RELATIVE TO THE FIELD.
##
## Outliers (|Z - 1| >= THRESHOLD) become proposed grid entries, squashed into the matrix's working
## range. Tag-level proposals take the median Z of the weapons carrying that tag (attribution smears
## across co-occurring tags -- a known limit at ~19 weapons; the clean fix is per-weapon counter data).
##
## PROPOSES ONLY -- never writes the grid. Feel is law; a human reviews every entry.
##
## Run: godot --headless --path . res://balance_sweep_analyze.tscn -- --csv=bench_results/sweep.csv
## (A scene, NOT a -s script: -s runs without autoloads, so weapon scripts referencing Events/Logs
## fail to compile during tag reading and the attribution comes back unreliable.)
extends Node

const THRESHOLD := 0.3    # |Z-1| below this is noise/typical -- keep the grid SPARSE
const SQUASH_LO := 0.4    # hard-counter floor (Z near 0 rails here)
const SQUASH_HI := 1.8    # hard-answer ceiling (huge Z rails here)
const MEDIAN_FLOOR := 0.01  # a column median this low means most of the field is WALLED there

## Which behavior each swept column expresses (both armor columns -> ARMORED; Z averaged).
const COLUMN_BEHAVIOR := {"armor10": "ARMORED", "armor25": "ARMORED"}

func _ready() -> void:
	var csv_path := "bench_results/sweep.csv"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--csv="):
			csv_path = arg.split("=", true, 1)[1]

	# --- Load measurements: dps[weapon_path][archetype] ---
	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		print("ANALYZE ERROR: no CSV at %s" % csv_path)
		get_tree().quit(1)
		return
	var dps: Dictionary = {}
	var columns: Array = []
	file.get_line()  # header
	while not file.eof_reached():
		var parts := file.get_line().strip_edges().split(",")
		if parts.size() != 3:
			continue
		if not dps.has(parts[0]):
			dps[parts[0]] = {}
		dps[parts[0]][parts[1]] = parts[2].to_float() if parts[2] != "NA" else -1.0
		if parts[1] != "baseline" and not parts[1] in columns:
			columns.append(parts[1])

	# --- R: each weapon vs its own baseline ---
	var r: Dictionary = {}
	var unmeasured: Array = []
	for w in dps:
		var base: float = dps[w].get("baseline", -1.0)
		if base <= 0.5:
			# Melee can't reach the bench's fixed ring, and a failed run parses as NA -- either way
			# the ratios are meaningless. Report rather than fake.
			unmeasured.append(w)
			continue
		r[w] = {}
		for a in columns:
			var v: float = dps[w].get(a, -1.0)
			r[w][a] = (v / base) if v >= 0.0 else -1.0

	# --- Z: each column vs the field's median ---
	var medians: Dictionary = {}
	for a in columns:
		var vals: Array = []
		for w in r:
			if r[w][a] >= 0.0:
				vals.append(r[w][a])
		medians[a] = _median(vals)
	var z: Dictionary = {}
	for w in r:
		z[w] = {}
		for a in columns:
			var med: float = maxf(medians[a], MEDIAN_FLOOR)
			z[w][a] = (r[w][a] / med) if r[w][a] >= 0.0 else -1.0

	# --- Report ---
	print("")
	print("SWEEP ANALYSIS  (R = vs own baseline, Z = vs field median; |Z-1| >= %.2f is an outlier)" % THRESHOLD)
	var header := "%-36s %8s" % ["weapon", "base"]
	for a in columns:
		header += " %10s %6s" % [a + " R", "Z"]
	print(header)
	var weapon_names: Array = r.keys()
	weapon_names.sort()
	for w in weapon_names:
		var row := "%-36s %8.1f" % [w.get_file().replace("_unlock.tres", ""), dps[w]["baseline"]]
		for a in columns:
			row += " %10.2f %6.2f" % [r[w][a], z[w][a]]
		print(row)
	for a in columns:
		var note := "  (median ~0: most of the field is WALLED here)" if medians[a] < MEDIAN_FLOOR else ""
		print("column median %-9s = %.3f%s" % [a, medians[a], note])
	if not unmeasured.is_empty():
		print("UNMEASURED (baseline ~0 -- melee can't reach the fixed ring, or the run failed):")
		for w in unmeasured:
			print("  " + w.get_file())

	# --- Proposals: per weapon, then per tag ---
	# DEGENERATE columns (median ~0: most of the field walled) are excluded from proposal means --
	# dividing by the floor rails every survivor to the ceiling and every railed zero drags typical
	# weapons to false 0.5s. The first sweep produced exactly that artifact for the axe.
	var usable_columns: Array = []
	for a in columns:
		if medians[a] >= MEDIAN_FLOOR:
			usable_columns.append(a)
	print("")
	print("PROPOSED GRID ENTRIES (squash = clamp(Z, %.1f, %.1f); mean Z over usable columns %s)" % [
		SQUASH_LO, SQUASH_HI, str(usable_columns)])
	var tag_z: Dictionary = {}  # tag name -> Array of per-weapon mean Z vs ARMORED
	for w in weapon_names:
		var zs: Array = []
		for a in usable_columns:
			if z[w][a] >= 0.0:
				zs.append(z[w][a])
		if zs.is_empty():
			continue
		var mean_z: float = 0.0
		for v in zs:
			mean_z += v
		mean_z /= zs.size()

		for tag in _weapon_tags(w):
			if not tag_z.has(tag):
				tag_z[tag] = []
			tag_z[tag].append(mean_z)

		if absf(mean_z - 1.0) >= THRESHOLD:
			print("  %-28s vs ARMORED: Z=%.2f -> eff %.2f%s" % [
				w.get_file().replace("_unlock.tres", ""), mean_z,
				clampf(mean_z, SQUASH_LO, SQUASH_HI),
				"  (hard-countered)" if mean_z < 0.5 else ("  (hard answer)" if mean_z > 2.0 else "")])

	print("BY TAG (median of member weapons' Z; compare against the current COUNTER_MATRIX):")
	var tags: Array = tag_z.keys()
	tags.sort()
	for tag in tags:
		var med_z: float = _median(tag_z[tag])
		if absf(med_z - 1.0) < THRESHOLD:
			continue
		var effect_idx: int = WeaponTags.Effect.keys().find(tag)
		var current: float = WeaponTags.get_counter_effectiveness(effect_idx, EnemyTags.Behavior.ARMORED) \
			if effect_idx >= 0 else 1.0
		print("  Effect.%-16s vs ARMORED: Z=%.2f -> proposed eff %.2f   (current grid: %.2f, n=%d)" % [
			tag, med_z, clampf(med_z, SQUASH_LO, SQUASH_HI), current, tag_z[tag].size()])
	print("")
	print("Reminder: PROPOSALS ONLY. Keep the grid sparse, hand-review every entry -- feel is law.")
	get_tree().quit()

## The effect tags authored on a weapon's scene root, as names.
func _weapon_tags(unlock_path: String) -> Array:
	var out: Array = []
	var upgrade = load(unlock_path)
	if upgrade == null or upgrade.scene_to_unlock == null:
		return out
	var node = upgrade.scene_to_unlock.instantiate()
	if "effects" in node:
		for e in node.effects:
			out.append(WeaponTags.Effect.keys()[e])
	node.free()
	return out

func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var mid := sorted.size() / 2
	if sorted.size() % 2 == 1:
		return sorted[mid]
	return (sorted[mid - 1] + sorted[mid]) / 2.0
