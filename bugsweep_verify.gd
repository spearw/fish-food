extends Node
## Headless verification for the Phase-0 bug sweep. Confirms all three fixes. Run with --headless.
##   1. Core deck is guaranteed into the upgrade pool even with no packs selected.
##   2. Goliath artifact reads max_health correctly and scales with bonus HP.
##   3. A spark kill emits Events.chain_kill (so Static Discharge can react).

class MockStats:
	extends Resource
	var max_health: int = 100

class MockUser:
	extends Node
	var stats := MockStats.new()
	var current_max := 100
	func get_stat(key):
		if key == "max_health":
			return current_max
		return 1.0

class MockEnemy:
	extends Node2D
	var is_dying := false
	func take_damage(_amount, _pen = 0, _crit = false, _src = null) -> void:
		is_dying = true  # any hit kills this mock

func _ready() -> void:
	var pass_all := true

	# --- Bug 3: core deck is always in the pool, even with zero packs selected ---
	# UpgradeManager is NOT an autoload -- it's a scene node -- so instantiate the script directly;
	# its _ready() builds the pool from CurrentRun.selected_pack_paths (which we've emptied).
	CurrentRun.selected_pack_paths.clear()
	var um = load("res://systems/upgrades/upgrade_manager.gd").new()
	add_child(um)
	var pool_size: int = um.active_upgrade_pool.size()
	var pool_ok: bool = pool_size > 0
	pass_all = pass_all and pool_ok
	print("BUGSWEEP core_deck_guaranteed: %s (pool_size=%d)" % ["PASS" if pool_ok else "FAIL", pool_size])

	# --- Bug 2: Goliath reads max_health and scales with bonus HP ---
	var user := MockUser.new()
	add_child(user)
	user.current_max = 150  # +50 bonus HP over base 100
	var goliath := GoliathArtifact.new()
	goliath.user = user
	var dmg_mod: float = goliath.get_damage_modifier()   # 1 + 50*0.01  = 1.5
	var spd_mod: float = goliath.get_speed_modifier()     # 1 + 50*-0.01 = 0.5
	var goliath_ok: bool = abs(dmg_mod - 1.5) < 0.001 and abs(spd_mod - 0.5) < 0.001
	pass_all = pass_all and goliath_ok
	print("BUGSWEEP goliath_scales: %s (dmg=%.2f spd=%.2f)" % ["PASS" if goliath_ok else "FAIL", dmg_mod, spd_mod])

	# --- Bug 1: a spark kill emits Events.chain_kill ---
	var chain_fired := [false]
	Events.chain_kill.connect(func(_pos, _dmg): chain_fired[0] = true)
	var spark = preload("res://items/weapons/spark/spark_projectile.tscn").instantiate()
	spark.allegiance = SparkProjectile.Allegiance.PLAYER
	spark.base_damage = 100
	spark.bounce_count = 1
	spark.bounces_remaining = 1
	add_child(spark)
	var mock_enemy := MockEnemy.new()
	add_child(mock_enemy)
	mock_enemy.add_to_group("enemies")
	spark._on_body_entered(mock_enemy)
	var chain_ok: bool = chain_fired[0]
	pass_all = pass_all and chain_ok
	print("BUGSWEEP chain_kill_emitted: %s (fired=%s)" % ["PASS" if chain_ok else "FAIL", str(chain_ok)])

	# --- Deck restructure: renamed class + fields load, and id + composition helper work ---
	var fire_deck = load("res://systems/upgrades/packs/fire_pack.tres")
	var comp = fire_deck.get_composition() if fire_deck else {}
	var deck_ok: bool = fire_deck != null and fire_deck is Deck \
		and fire_deck.deck_name == "Fire" and fire_deck.id == "fire" and comp.get("weapons", 0) > 0
	pass_all = pass_all and deck_ok
	print("BUGSWEEP deck_restructure: %s (name=%s id=%s comp=%s)" % [
		"PASS" if deck_ok else "FAIL",
		str(fire_deck.deck_name) if fire_deck else "?", str(fire_deck.id) if fire_deck else "?", str(comp)])

	print("BUGSWEEP RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()
