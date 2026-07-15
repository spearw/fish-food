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

var weapon_path := ""       # Upgrade .tres for the weapon under test
var rarity := 0             # Upgrade.Rarity index
var copies := 1
var enemy_count := 40
var seconds := 20.0
var immortal := true

var _ready_to_measure := false
var _boot_frames := 0
var _frames := 0
var _kills := 0
var _player: Node = null
var _dir: Node = null
var _enemies: Array = []
var _baseline_hp := 0.0

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

	_frames += 1
	if _frames < WARMUP_FRAMES:
		_kills = 0  # discard warm-up kills
		return
	if _frames >= _total_frames() + WARMUP_FRAMES:
		_report()

func _total_frames() -> int:
	return int(seconds * Engine.physics_ticks_per_second)

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

	if immortal:
		# Fixed field, no churn: the director would otherwise keep changing what we're shooting at.
		if _dir:
			_dir.set_physics_process(false)
			var t = _dir.get_node_or_null("Timer")
			if t:
				t.stop()
		_spawn_dummy_field()
	# In mortal mode the director is left running on purpose -- its population model IS the scenario.

	_equip_test_loadout()

	# Snapshot the field. In immortal mode, give it a health pool nothing can chew through, and record
	# the baseline so damage dealt = the sum of what's missing.
	_enemies = get_tree().get_nodes_in_group("enemies")
	if immortal:
		for e in _enemies:
			if is_instance_valid(e) and "current_health" in e:
				e.current_health = IMMORTAL_HP
				_baseline_hp += IMMORTAL_HP

	_ready_to_measure = true

## Builds a deterministic target-dummy field: one enemy type, placed on fixed concentric rings, frozen
## in place.
##
## The director's own debug_spawn randomises position, type AND size, and live enemies then swarm --
## so the same weapon measured ~2.5x apart run to run. A raid-sim dummy is the right shape here: hold
## the scenario still so the only variable is the item under test.
##
## Cost of this choice, worth knowing: a fixed ring flatters range and punishes melee, so cross-weapon
## numbers are a ballpark only. Same-weapon comparisons (rarity, copies) are what this is for.
func _spawn_dummy_field() -> void:
	if not _dir or not _dir.has_method("spawn_enemy"):
		print("BALANCEBENCH ERROR: no EncounterDirector.spawn_enemy")
		get_tree().quit()
		return

	var pool: Array = []
	for es in _dir.encounter_sets:
		pool.append_array(es.enemies)
	if pool.is_empty():
		print("BALANCEBENCH ERROR: no enemies in the biome's encounter sets")
		get_tree().quit()
		return
	var stats = pool[0]  # first, not random: the type must not change between runs

	# Re-seed HERE, not at probe start. Booting the world consumes random numbers over a variable
	# number of frames, so a seed set in _ready() has already drifted by the time we spawn.
	seed(BENCH_SEED)

	# Concentric rings from just outside melee reach to typical projectile range.
	const RINGS := [80.0, 140.0, 200.0, 260.0]
	var origin: Vector2 = _player.global_position
	for i in range(enemy_count):
		var ring: float = RINGS[i % RINGS.size()]
		var step: int = i / RINGS.size()
		var per_ring: float = ceil(float(enemy_count) / RINGS.size())
		var angle: float = TAU * (float(step) / per_ring)
		_dir.spawn_enemy(stats, origin + Vector2.RIGHT.rotated(angle) * ring)

	# Freeze them: a swarm closing on the player changes the geometry mid-measurement, which is the
	# single biggest source of run-to-run swing.
	# Deferred: we're inside a physics flush here, and Godot refuses state changes mid-query.
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		e.call_deferred("set_physics_process", false)
		var ai = e.get_node_or_null("AI")
		if ai:
			ai.call_deferred("set_physics_process", false)
			ai.call_deferred("set_process", false)

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
	var damage := 0.0
	if immortal:
		var remaining := 0.0
		var alive := 0
		for e in _enemies:
			if is_instance_valid(e) and "current_health" in e:
				remaining += e.current_health
				alive += 1
		# Enemies that despawned took their damage with them; report alive count so a big shortfall
		# is visible rather than silently deflating the number.
		damage = _baseline_hp - remaining - (IMMORTAL_HP * (_enemies.size() - alive))

	var dps := damage / seconds
	var kps := float(_kills) / seconds
	var rarity_name: String = Upgrade.Rarity.keys()[clampi(rarity, 0, Upgrade.Rarity.size() - 1)]

	print("BALANCEBENCH weapon=%s rarity=%s copies=%d mode=%s enemies=%d secs=%.0f" % [
		weapon_path.get_file(), rarity_name, copies,
		"immortal" if immortal else "mortal", enemy_count, seconds])
	if immortal:
		print("BALANCEBENCH damage=%.0f dps=%.1f dps_per_copy=%.1f" % [damage, dps, dps / maxf(copies, 1)])
	else:
		print("BALANCEBENCH kills=%d kills_per_sec=%.2f kps_per_copy=%.2f" % [
			_kills, kps, kps / maxf(copies, 1)])
	get_tree().quit()
