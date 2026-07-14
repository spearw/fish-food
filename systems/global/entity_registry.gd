## entity_registry.gd
## A singleton that maintains cached lists of entities for efficient querying.
## Updates via signals instead of tree queries every frame.
## Note: No class_name needed - accessed as autoload "EntityRegistry"
extends Node

# --- Cached Entity Lists ---
var _enemies: Array[Node] = []
var _alive_enemies: Array[Node] = []  # Pre-filtered list of non-dying enemies
var _players: Array[Node] = []

# --- Quick Access ---
var player: Node = null  # Single player reference for common case

# --- Spatial hash (rebuilt each physics frame) for O(local) targeting queries ---
const CELL_SIZE := 256.0
var _grid: Dictionary = {}  # Vector2i -> Array[Node]

func _physics_process(_delta: float) -> void:
	_rebuild_grid()

func _rebuild_grid() -> void:
	_grid.clear()
	for e in _alive_enemies:
		if not is_instance_valid(e):
			continue
		var cell := Vector2i(int(floor(e.global_position.x / CELL_SIZE)), int(floor(e.global_position.y / CELL_SIZE)))
		var arr = _grid.get(cell)
		if arr == null:
			arr = []
			_grid[cell] = arr
		arr.append(e)

## Alive enemies in the cells overlapping pos +/- radius (cell-granular; caller should still
## do an exact distance check). O(local density) instead of O(all enemies).
func get_enemies_near(pos: Vector2, radius: float) -> Array:
	var result: Array = []
	var min_x := int(floor((pos.x - radius) / CELL_SIZE))
	var max_x := int(floor((pos.x + radius) / CELL_SIZE))
	var min_y := int(floor((pos.y - radius) / CELL_SIZE))
	var max_y := int(floor((pos.y + radius) / CELL_SIZE))
	for cx in range(min_x, max_x + 1):
		for cy in range(min_y, max_y + 1):
			var arr = _grid.get(Vector2i(cx, cy))
			if arr:
				result.append_array(arr)
	return result

## Alive enemies whose CENTRE is within `radius` of `pos` (exact circle, not just cell-granular).
## This is the shared building block for off-broadphase (spatial-hash) hit detection: both
## Projectile._check_spatial_hits and SparkProjectile._check_spatial_hit call it, so the scan lives in
## ONE place -- each caller then applies its own hit handling (pierce-through vs bounce). Enemy grid
## only, so spatial hits are for player-allegiance projectiles (enemy projectiles keep the Area2D path).
func get_enemies_within(pos: Vector2, radius: float) -> Array:
	var result: Array = []
	var r_sq := radius * radius
	for e in get_enemies_near(pos, radius):
		if is_instance_valid(e) and pos.distance_squared_to(e.global_position) <= r_sq:
			result.append(e)
	return result

## Group-aware nearby query: spatial grid for enemies, small cached list otherwise (player).
func get_candidates_near(target_group: String, pos: Vector2, radius: float) -> Array:
	if target_group == "enemies":
		return get_enemies_near(pos, radius)
	return get_candidates(target_group)

func _ready() -> void:
	# Connect to enemy lifecycle signals
	Events.enemy_killed.connect(_on_enemy_killed)

	# We'll need to populate initial lists after scene is ready
	call_deferred("_initialize_lists")

func _initialize_lists() -> void:
	# One-time population at game start
	_enemies.assign(get_tree().get_nodes_in_group("enemies"))
	_alive_enemies.assign(_enemies.filter(func(e): return is_instance_valid(e) and not e.is_dying))
	var players = get_tree().get_nodes_in_group("player")
	_players.assign(players)
	if players.size() > 0:
		player = players[0]

## Called when a new enemy spawns. Should be called by the spawner.
func register_enemy(enemy: Node) -> void:
	if enemy not in _enemies:
		_enemies.append(enemy)
		_alive_enemies.append(enemy)

## Called when an enemy starts dying (remove from alive list immediately).
## Call this when enemy.is_dying is set to true.
func mark_enemy_dying(enemy_node: Node) -> void:
	_alive_enemies.erase(enemy_node)

## Called when an enemy dies (connected to Events.enemy_killed).
func _on_enemy_killed(enemy_node: Node) -> void:
	_enemies.erase(enemy_node)
	_alive_enemies.erase(enemy_node)  # Redundant if mark_enemy_dying was called, but safe

## Called when player spawns.
func register_player(player_node: Node) -> void:
	if player_node not in _players:
		_players.append(player_node)
	player = player_node

## Get all enemies (returns cached array - do not modify!)
func get_enemies() -> Array[Node]:
	return _enemies

## Get all players (returns cached array - do not modify!)
func get_players() -> Array[Node]:
	return _players

## Get filtered candidates for targeting (returns pre-filtered alive list)
func get_enemy_candidates() -> Array[Node]:
	return _alive_enemies

## Get player candidates
func get_player_candidates() -> Array:
	return _players.filter(func(p): return is_instance_valid(p) and not p.get("is_dying"))

## Get candidates by group name (for compatibility with existing code)
func get_candidates(target_group: String) -> Array:
	match target_group:
		"enemies":
			return _alive_enemies
		"player":
			return get_player_candidates()
		_:
			# Fallback to tree query for unknown groups
			return get_tree().get_nodes_in_group(target_group).filter(
				func(e): return e is CharacterBody2D and not e.get("is_dying")
			)

## Get enemy count (useful for performance checks)
func get_enemy_count() -> int:
	return _enemies.size()

## Get alive enemy count
func get_alive_enemy_count() -> int:
	return _alive_enemies.size()
