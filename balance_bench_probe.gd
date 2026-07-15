extends Node
## Balance probe (lives on the SceneTree root; survives the change into world.tscn).
##
## Measures what an item is WORTH, not what it costs to render -- the balance counterpart to the
## perf probes. See .claude/balance/workflow.md.
##
## Two modes, because they answer different questions:
##
##   IMMORTAL (default) -- director off, fixed enemy field, enemies given huge HP once. Reports raw
##     DAMAGE OUTPUT. Low variance, comparable across weapons. Use to ballpark a new weapon against a
##     reference and to verify rarity scaling. Overkill is impossible here, so this is a ceiling, not
##     a throughput number.
##
##   MORTAL -- the real population model runs and enemies actually die. Reports KILLS. This is the
##     only way to see the costs no published formula covers: overkill waste, and AoE thinning its own
##     cluster. Noisier (spawn variance), so run longer.
##
## The two-copy multiplier -- the number the rarity curve's whole premise rests on -- is only
## meaningful in MORTAL mode. In IMMORTAL mode two copies trivially measure 2.0x, because nothing can
## be wasted.

## The archetypes a weapon gets profiled against. Each entry is a real enemy already in the game,
## picked because it isolates one axis. STANDARD is the yardstick everything else is normalised to.
##
## The point of a profile over a single number: a weapon's own ratios across archetypes ARE the
## intransitive picture -- what it beats and what beats it. That's the shape WeaponTags.COUNTER_MATRIX
## encodes today from hand-authored guesses, and the shape this bench can measure instead.
## SYNTHETIC dummies -- the ones to trust. Each is dummy_baseline.tres (a fish clone) with EXACTLY ONE
## stat changed, so a measured ratio is attributable to that stat.
##
## Real enemies can't do this. They vary AI, speed, armor and size all at once -- fish is HORDE at 90
## speed, comb_jelly is RANGED+ARMORED at 40, garden_eel is a RANGED skirmisher whose behavior parks it
## despite a 250 speed stat. Their ratios are real but uninterpretable, and the first archetype table
## here was built from stats without reading the AI, which made its labels flatly wrong.
## Cloning one base holds behavior constant so it cancels out of the ratios.
const ARCHETYPES := {
	"baseline": "res://bench_dummies/dummy_baseline.tres",  # the control: fish, unmodified
	"armor10":  "res://bench_dummies/dummy_armor10.tres",   # +armor only
	"armor25":  "res://bench_dummies/dummy_armor25.tres",   # +armor only, further along the axis
	"fast":     "res://bench_dummies/dummy_fast.tres",      # move_speed 90 -> 250 only
	"slow":     "res://bench_dummies/dummy_slow.tres",      # move_speed 90 -> 30 only
	"tanky":    "res://bench_dummies/dummy_tanky.tres",     # max_health only (mortal mode only)
}

## REAL enemies. What the player actually faces, and what COUNTER_MATRIX is keyed on -- but every one
## confounds several axes, so use these for sanity, not attribution.
const REAL_ENEMIES := {
	"real_horde":    "res://actors/enemies/normal_enemy_types/fish/fish.tres",             # HORDE, 90spd
	"real_swarm":    "res://actors/enemies/normal_enemy_types/jelly/jelly.tres",           # SWARM, 8hp
	"real_ranged_armored": "res://actors/enemies/normal_enemy_types/comb_jelly/comb_jelly.tres",  # RANGED+ARMORED
	"real_skirmisher": "res://actors/enemies/normal_enemy_types/garden_eel/garden_eel.tres",      # RANGED+FAST
	"real_swarm_fast": "res://actors/enemies/normal_enemy_types/pike/pike.tres",           # SWARM+FAST
}

## Everything selectable via --archetype=.
static func all_fields() -> Dictionary:
	var merged := ARCHETYPES.duplicate()
	merged.merge(REAL_ENEMIES)
	return merged

var weapon_path := ""       # Upgrade .tres for the weapon under test
var rarity := 0             # Upgrade.Rarity index
var copies := 1
var enemy_count := 40
var seconds := 20.0
var immortal := true
var archetype := "standard"  # key into ARCHETYPES
var profile := false         # (unused; profiling is a shell loop over --archetype=)
## How the dummy field behaves. "orbit" (default) circles each enemy around the player at ITS OWN
## move_speed; "frozen" pins them in place.
##
## Orbit exists because a frozen dummy can't miss. Projectile speed, travel time, leading a target and
## homing are all real contributors to damage, and against a stationary target every one of them is
## free -- a slow projectile hits a frozen enemy exactly as reliably as a fast one. Freezing also made
## the "fast" archetype identical to "standard", which quietly made a whole axis unmeasurable.
##
## Orbiting keeps what freezing bought (the geometry is stationary in aggregate -- same radii, same
## density, no swarm collapsing onto the player mid-window) while restoring what it destroyed: a
## garden_eel at 250 speed sweeps ~6x faster than a comb_jelly at 40, so a slow projectile genuinely
## misses it. Same trick SimulationCraft uses -- scripted movement rather than a static dummy.
var motion := "orbit"

var _ready_to_measure := false
var _boot_frames := 0
var _frames := 0
var _kills := 0
var _player: Node = null
var _dir: Node = null
var _enemies: Array = []
var _baseline_hp := 0.0
var _queue: Array = []          # archetypes still to measure
var _current := ""              # archetype being measured
var _results: Dictionary = {}   # archetype -> measured value
var _orbits: Array = []         # {node, radius, angle, angular_speed} -- the moving dummy field
var _origin := Vector2.ZERO     # the field's centre (the player's position at spawn)

const BOOT_TIMEOUT := 1500
const IMMORTAL_HP := 1000000000.0
## Fixed seed: debug_spawn randomises position, enemy TYPE and size, and crits roll every hit. Without
## a seed the same config swings ~2.5x run to run and the bench measures the scenario, not the weapon.
const BENCH_SEED := 20260715
const WARMUP_FRAMES := 60  # let weapons acquire targets before the clock starts

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	seed(BENCH_SEED)
	Events.enemy_killed.connect(func(_e): _kills += 1)

func _process(_dt: float) -> void:
	get_tree().paused = false  # the run hands out a level-up that pauses; keep it running

	if not _ready_to_measure:
		_boot_frames += 1
		if _boot_frames > BOOT_TIMEOUT:
			print("BALANCEBENCH ERROR: world/player never became ready")
			get_tree().quit()
			return
		_try_setup()

## Timing runs on PHYSICS frames, not wall-clock. Headless dt is whatever the machine felt like, so a
## wall-clock window would sim a different amount of game time on every run -- and on every machine.
func _physics_process(_dt: float) -> void:
	if not _ready_to_measure:
		return

	# The player must never die, or the scenario stops being the one we're measuring.
	if is_instance_valid(_player) and "current_health" in _player:
		_player.current_health = IMMORTAL_HP

	_drive_orbits()
	_frames += 1
	if _frames < WARMUP_FRAMES:
		_kills = 0  # discard warm-up kills
		return
	if _frames >= _total_frames() + WARMUP_FRAMES:
		_finish_window()

func _total_frames() -> int:
	return int(seconds * Engine.physics_ticks_per_second)

## Sweeps the dummy field around the player at each enemy's own speed.
##
## Driven on a FIXED timestep, not the real delta: headless dt is arbitrary, and letting it in here
## would put the run-to-run variance straight back into the enemy positions -- which is exactly what
## the frozen field was there to prevent.
func _drive_orbits() -> void:
	if _orbits.is_empty():
		return
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	for o in _orbits:
		var node = o["node"]
		if not is_instance_valid(node):
			continue
		o["angle"] += o["angular_speed"] * dt
		node.global_position = _origin + Vector2.RIGHT.rotated(o["angle"]) * o["radius"]

func _try_setup() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	_player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(_player):
		return

	# Level-ups pause the game and would hand out upgrades we didn't ask for, which would silently
	# contaminate the loadout under test.
	if _player.has_signal("leveled_up"):
		for c in _player.leveled_up.get_connections():
			_player.leveled_up.disconnect(c.callable)

	_dir = scene.find_child("EncounterDirector", true, false)
	# The director would keep changing what we're shooting at. In mortal mode we spawn the archetype
	# field ourselves too, so the profile compares like with like -- letting the director pick would
	# reintroduce the enemy-type randomness the seed exists to remove.
	if _dir:
		_dir.set_physics_process(false)
		var t = _dir.get_node_or_null("Timer")
		if t:
			t.stop()

	_equip_test_loadout()

	_queue = [archetype]
	_begin_window()

## Sets up one archetype's measurement window.
func _begin_window() -> void:
	_current = _queue.pop_front()
	var fields := all_fields()
	if not fields.has(_current):
		print("BALANCEBENCH ERROR: unknown archetype '%s' (have: %s)" % [
			_current, ", ".join(fields.keys())])
		get_tree().quit()
		return

	_spawn_dummy_field(fields[_current])

	_frames = 0
	_kills = 0
	_baseline_hp = 0.0
	_enemies = get_tree().get_nodes_in_group("enemies")
	if immortal:
		# A health pool nothing can chew through, so damage dealt = the sum of what's missing.
		# Note this erases the archetype's HP: in immortal mode only ARMOR (and hitbox) still
		# differentiates them. Kill throughput needs mortal mode.
		for e in _enemies:
			if is_instance_valid(e) and "current_health" in e:
				e.current_health = IMMORTAL_HP
				_baseline_hp += IMMORTAL_HP

	_ready_to_measure = true

## Records the finished window and reports.
##
## One archetype per process, on purpose. Tearing the field down in-process to run the next archetype
## leaves dangling references (the director's ledger and live projectiles both still hold enemies), and
## a bench that spams "previously freed" errors is a bench nobody trusts. Profiling is a shell loop over
## --archetype= instead -- same shape the perf benches already use.
func _finish_window() -> void:
	_ready_to_measure = false
	_results[_current] = _measure()
	_report()

## The window's result: damage dealt (immortal) or kills (mortal).
func _measure() -> float:
	if not immortal:
		return float(_kills)
	var remaining := 0.0
	var alive := 0
	for e in _enemies:
		if is_instance_valid(e) and "current_health" in e:
			remaining += e.current_health
			alive += 1
	# Enemies that despawned took their damage with them; discount them rather than silently
	# deflating the number.
	return _baseline_hp - remaining - (IMMORTAL_HP * (_enemies.size() - alive))

## Builds a deterministic target-dummy field: one enemy type, placed on fixed concentric rings, frozen
## in place.
##
## The director's own debug_spawn randomises position, type AND size, and live enemies then swarm --
## so the same weapon measured ~2.5x apart run to run. A raid-sim dummy is the right shape here: hold
## the scenario still so the only variable is the item under test.
##
## Cost of this choice, worth knowing: a fixed ring flatters range and punishes melee, so cross-weapon
## numbers are a ballpark only. Same-weapon comparisons (rarity, copies) are what this is for.
func _spawn_dummy_field(stats_path: String) -> void:
	if not _dir or not _dir.has_method("spawn_enemy"):
		print("BALANCEBENCH ERROR: no EncounterDirector.spawn_enemy")
		get_tree().quit()
		return

	var stats = load(stats_path)
	if stats == null:
		print("BALANCEBENCH ERROR: no enemy stats at %s" % stats_path)
		get_tree().quit()
		return

	# Re-seed HERE, not at probe start. Booting the world consumes random numbers over a variable
	# number of frames, so a seed set in _ready() has already drifted by the time we spawn.
	# Re-seeding per window also means every archetype in a profile faces the same rolls.
	seed(BENCH_SEED)

	# Concentric rings from just outside melee reach to typical projectile range.
	const RINGS := [80.0, 140.0, 200.0, 260.0]
	_origin = _player.global_position
	_orbits.clear()
	var placed: Array = []
	for i in range(enemy_count):
		var ring: float = RINGS[i % RINGS.size()]
		var step: int = i / RINGS.size()
		var per_ring: float = ceil(float(enemy_count) / RINGS.size())
		var angle: float = TAU * (float(step) / per_ring)
		_dir.spawn_enemy(stats, _origin + Vector2.RIGHT.rotated(angle) * ring)
		placed.append({"ring": ring, "angle": angle})

	# Take the enemies' own AI offline: a swarm collapsing onto the player mid-window changes the
	# geometry, which was the single biggest source of run-to-run swing. We drive them instead.
	# Deferred: we're inside a physics flush here, and Godot refuses state changes mid-query.
	var enemies := get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		e.call_deferred("set_physics_process", false)
		var ai = e.get_node_or_null("AI")
		if ai:
			ai.call_deferred("set_physics_process", false)
			ai.call_deferred("set_process", false)

	if motion != "orbit":
		return

	# Record each enemy's orbit, sweeping at ITS OWN move_speed so the "fast" archetype is genuinely
	# harder to hit. angular_speed = linear speed / radius, so a garden_eel at 250 covers ground ~6x
	# faster than a comb_jelly at 40 and a slow projectile will trail behind it.
	for i in range(min(enemies.size(), placed.size())):
		var e = enemies[i]
		if not is_instance_valid(e):
			continue
		var speed := 0.0
		if "stats" in e and e.stats and "move_speed" in e.stats:
			speed = e.stats.move_speed
		var radius: float = placed[i]["ring"]
		_orbits.append({
			"node": e,
			"radius": radius,
			"angle": placed[i]["angle"],
			"angular_speed": speed / maxf(radius, 1.0),
		})

## Strips whatever the character came with and equips exactly the weapon under test, so the number
## measures that weapon and nothing else.
func _equip_test_loadout() -> void:
	var equipment := _player.get_node_or_null("Equipment")
	if not equipment:
		print("BALANCEBENCH ERROR: player has no Equipment node")
		get_tree().quit()
		return
	for child in equipment.get_children():
		equipment.remove_child(child)
		child.queue_free()

	var upgrade = load(weapon_path)
	if upgrade == null or upgrade.scene_to_unlock == null:
		print("BALANCEBENCH ERROR: no weapon at %s" % weapon_path)
		get_tree().quit()
		return

	var um = get_tree().current_scene.find_child("UpgradeManager", true, false)
	for i in range(copies):
		var weapon = um.create_weapon(upgrade.scene_to_unlock.instantiate(), upgrade, rarity)
		# Names must differ or Godot renames them and the inventory scan sees only one.
		weapon.name = "%s_%d" % [upgrade.target_class_name, i]
		equipment.add_child(weapon)

func _report() -> void:
	var rarity_name: String = Upgrade.Rarity.keys()[clampi(rarity, 0, Upgrade.Rarity.size() - 1)]
	var unit := "dps" if immortal else "kills_per_sec"

	print("BALANCEBENCH weapon=%s rarity=%s copies=%d mode=%s enemies=%d secs=%.0f" % [
		weapon_path.get_file(), rarity_name, copies,
		"immortal" if immortal else "mortal", enemy_count, seconds])

	# Loop this over --archetype= and divide each result by the "standard" one. Those ratios are the
	# same shape WeaponTags.COUNTER_MATRIX encodes by hand: >1 means the weapon is better than usual
	# into that archetype, <1 means that archetype counters it.
	print("BALANCEBENCH   archetype=%-9s %s=%.1f" % [_current, unit, _results[_current] / seconds])
	get_tree().quit()
