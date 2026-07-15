extends Node
## Headless check of the walled-share cap. Run with --headless.
##   1. Weapon.get_damage_sources walks the full stats tree (the fireball's pen lives in its nested
##      explosion, and its DoT in the status it applies).
##   2. The wall test: dagger-tier hits are walled by 15 armor; epic hits, pen and DoT are not.
##   3. Candidates use their WORST-case size multiplier (a might-be-large enemy counts early).
##   4. The pick-time gate: under the cap a wall passes; at the cap it's re-picked from the open
##      candidates; if everything available is a wall, it stands (a starved wave is worse).

const DAGGER_UNLOCK := "res://systems/upgrades/weapons/daggers_unlock.tres"
const STAFF_UNLOCK := "res://systems/upgrades/weapons/fire/fireball_staff/fireball_staff_unlock.tres"

func _fake_enemy(armor: int, sizes: Array) -> EnemyStats:
	var stats := EnemyStats.new()
	stats.armor = armor
	stats.size_tags.assign(sizes)
	stats.challenge_rating = 1.0
	return stats

func _ready() -> void:
	# --- 1. Damage-source fingerprints off real weapon scenes (off-tree: reads authored stats) ---
	var dagger = load(DAGGER_UNLOCK).scene_to_unlock.instantiate()
	var staff = load(STAFF_UNLOCK).scene_to_unlock.instantiate()
	var dagger_sources: Array = dagger.get_damage_sources()
	var staff_sources: Array = staff.get_damage_sources()
	dagger.free()
	staff.free()

	var dagger_ok: bool = dagger_sources.size() == 1 \
		and dagger_sources[0]["damage"] == 10.0 and dagger_sources[0]["armor_pen"] == 0.0 \
		and not dagger_sources[0]["dot"]
	var staff_has_pen := false
	var staff_has_dot := false
	for s in staff_sources:
		staff_has_pen = staff_has_pen or s["armor_pen"] >= 0.5
		staff_has_dot = staff_has_dot or s["dot"]
	var staff_ok: bool = staff_sources.size() >= 2 and staff_has_pen and staff_has_dot
	print("ARMORCAP sources: dagger=%s (n=%d) staff=%s (n=%d pen=%s dot=%s)" % [
		str(dagger_ok), dagger_sources.size(), str(staff_ok), staff_sources.size(),
		str(staff_has_pen), str(staff_has_dot)])

	# --- 2. The wall test, on a bare director (helpers don't need the scene wiring) ---
	var d = load("res://systems/spawner/encounter_director.gd").new()
	var dagger_build := {"sources": [{"damage": 10.0, "armor_pen": 0.0, "dot": false}], "any_dot": false}
	var epic_build := {"sources": [{"damage": 32.0, "armor_pen": 0.0, "dot": false}], "any_dot": false}
	var pen_build := {"sources": [{"damage": 25.0, "armor_pen": 0.5, "dot": false}], "any_dot": false}
	var dot_build := {"sources": [{"damage": 1.0, "armor_pen": 0.0, "dot": true}], "any_dot": true}

	var wall_ok: bool = d._armor_walls_build(15.0, dagger_build) \
		and not d._armor_walls_build(7.5, dagger_build) \
		and not d._armor_walls_build(15.0, epic_build) \
		and not d._armor_walls_build(15.0, pen_build) \
		and not d._armor_walls_build(999.0, dot_build) \
		and not d._armor_walls_build(0.0, dagger_build)
	print("ARMORCAP wall_test=%s" % str(wall_ok))

	# --- 3. Candidate test uses the worst-case size multiplier ---
	# 7 armor, may spawn LARGE (armor x1.5 -> 10.5): 10 damage clears 7 (deals 3) but not 10.5, so the
	# maybe-large candidate counts as a wall while the always-medium one doesn't. (Two drafts of this
	# test got the arithmetic wrong: 10 vs 10 armor IS a wall -- max(0, 10-10) = 0 -- and 10 vs 9
	# armor is NOT -- it deals 1.)
	var maybe_large := _fake_enemy(7, [EnemyTags.Size.MEDIUM, EnemyTags.Size.LARGE])
	var always_medium := _fake_enemy(7, [EnemyTags.Size.MEDIUM])
	var soft := _fake_enemy(0, [EnemyTags.Size.MEDIUM])
	var size_ok: bool = d._is_walled_candidate(maybe_large, dagger_build) \
		and not d._is_walled_candidate(always_medium, dagger_build) \
		and not d._is_walled_candidate(soft, dagger_build)
	print("ARMORCAP size_conservative=%s" % str(size_ok))

	# --- 4. The pick-time gate (counter_mode defaults to NORMAL, so weighting is inert) ---
	var wall := _fake_enemy(20, [EnemyTags.Size.MEDIUM])
	var available: Array[EnemyStats] = [wall, soft]

	# Under the cap: the wall passes through.
	var under = d._apply_walled_cap(wall, available, dagger_build, 1, 10)
	# At the cap: re-picked, and the only open candidate is the soft one.
	var at = d._apply_walled_cap(wall, available, dagger_build, 4, 10)
	# Soft candidates are never touched, even at the cap.
	var soft_pass = d._apply_walled_cap(soft, available, dagger_build, 9, 10)
	# Everything available is a wall: the candidate stands rather than starving the wave.
	var all_walls: Array[EnemyStats] = [wall]
	var starved = d._apply_walled_cap(wall, all_walls, dagger_build, 9, 10)

	var gate_ok: bool = under == wall and at == soft and soft_pass == soft and starved == wall \
		and is_equal_approx(d.max_walled_share, 0.4)
	print("ARMORCAP gate: under=%s at_cap_repicks=%s soft_pass=%s starved_fallback=%s cap=%.2f" % [
		str(under == wall), str(at == soft), str(soft_pass == soft), str(starved == wall),
		d.max_walled_share])

	d.free()
	var pass_all: bool = dagger_ok and staff_ok and wall_ok and size_ok and gate_ok
	print("ARMORCAP RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()
