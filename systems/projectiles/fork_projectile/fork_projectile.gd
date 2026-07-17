## fork_projectile.gd -- a bolt that splits on its FIRST hit into fork_count children at
## fork_damage_ratio damage. Serves the lightning evolutions (Fork Lightning x2, Overcharged
## Capacitor x3) -- per-weapon counts live as scene export overrides (fork_bolt_x2/x3.tscn).
## Children are generation 1 and never fork again (no exponential chains). Custom-scene
## projectiles are never pooled, and children are plain instantiations too: low volume, no pool
## bookkeeping to leak (see the eel-bug pattern in CLAUDE.md).
class_name ForkProjectile
extends Projectile

@export var fork_count: int = 2
@export var fork_damage_ratio: float = 0.6
@export var fork_spread_radians: float = 0.65  # fallback fan when no other enemies are near

var generation: int = 0
var _forked := false

func _deal_damage(body: Node2D) -> float:
	var dealt: float = super._deal_damage(body)
	if generation == 0 and not _forked:
		_forked = true
		_fork(body)
	return dealt

func _fork(hit_body: Node2D) -> void:
	if not is_inside_tree():
		return
	var scene: PackedScene = load(scene_file_path)
	var candidates: Array = EntityRegistry.get_candidates_near(
		"enemies", hit_body.global_position, 260.0)
	candidates.erase(hit_body)
	for i in range(fork_count):
		var child = scene.instantiate()
		child.generation = 1
		# Children inherit the parent's stats (already weapon-localized and rarity-scaled) at
		# reduced damage; everything else -- sparks, statuses, pierce -- rides along.
		var child_stats = stats.duplicate(true)
		child_stats.damage = child_stats.damage * fork_damage_ratio
		child.stats = child_stats
		child.allegiance = allegiance
		child.user = user
		child.weapon = weapon
		child.attribution_key = attribution_key
		if i < candidates.size() and is_instance_valid(candidates[i]):
			child.direction = (candidates[i].global_position - hit_body.global_position).normalized()
		else:
			var side: float = fork_spread_radians * (1.0 if i % 2 == 0 else -1.0) * (1 + i / 2)
			child.direction = direction.rotated(side)
		get_tree().current_scene.add_child(child)
		child.global_position = hit_body.global_position + child.direction * 24.0
		child.rotation = child.direction.angle()
