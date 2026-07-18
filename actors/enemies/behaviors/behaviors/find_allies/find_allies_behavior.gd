## find_allies_behavior.gd
## Moves the host towards the nearest ally NOT in its immediate cluster.
class_name FindAlliesBehavior
extends MovementBehavior

var ally_name_to_find: String = ""
var allies_to_ignore: Array = []

func on_enter(host: Node, context: Dictionary = {}):
	super.on_enter(host, context)  # MovementBehavior handles animation
	if is_instance_valid(host_enemy):
		self.ally_name_to_find = host_enemy.stats.display_name

	# on_enter calls update_context to avoid duplicating code.
	update_context(context)

func update_context(context: Dictionary = {}):
	if context.has("ignore_list"):
		self.allies_to_ignore = context["ignore_list"]
	else:
		self.allies_to_ignore = []

func process_behavior(delta: float, host: CharacterBody2D):
	if ally_name_to_find.is_empty():
		host.velocity = Vector2.ZERO
		return

	# Find the nearest ally that is NOT in our ignore list.
	var nearest_ally = _find_nearest_ally(host)
	
	if is_instance_valid(nearest_ally):
		var direction = (nearest_ally.global_position - host.global_position).normalized()
		host.velocity = direction * host.get_effective_move_speed()
	else:
		# Chase the player as a fallback.
		if is_instance_valid(host.player_node):
			var direction = (host.player_node.global_position - host.global_position).normalized()
			host.velocity = direction * host.get_effective_move_speed()
		else:
			host.velocity = Vector2.ZERO

## Helper to find the closest valid ally, respecting the ignore list.
func _find_nearest_ally(host: Node) -> Node:
	var best_target = null
	var closest_dist_sq = INF

	# Use EntityRegistry for cached enemy list (avoids tree query every frame)
	for enemy in EntityRegistry.get_enemies():
		# The cached list can hold allies freed this frame -- touching one is an error per scan tick.
		if not is_instance_valid(enemy):
			continue
		# Standard checks: not ourself, is the right type, and not in our current group.
		if enemy == host or enemy.stats.display_name != self.ally_name_to_find or allies_to_ignore.has(enemy):
			continue

		var dist_sq = host.global_position.distance_squared_to(enemy.global_position)
		if dist_sq < closest_dist_sq:
			closest_dist_sq = dist_sq
			best_target = enemy

	return best_target
