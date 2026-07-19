## events.gd
## A global event bus (Singleton) for decoupled communication between game systems.
extends Node

# --- Gameplay Events ---
# Emitted when a treasure chest is collected.
signal boss_reward_requested

# Batched enemy_hit signal - emitted once per frame with all hits
signal enemy_hit_batch(hits: Array)
# Legacy single-hit signal (still available for simple use cases)
signal enemy_hit(hit_details: Dictionary)
signal status_applied_to_enemy(enemy_node, status_id)
signal enemy_killed(enemy_node)
signal magnet_collected(player_node)
signal player_was_hit(source_node)  # Emitted when player is hit (before armor calculation)
signal chain_kill(position: Vector2, damage: float)  # Emitted when enemy killed by chain projectile
signal spark_hit_enemy(enemy_node)  # Emitted whenever a spark (chain lightning) hits an enemy

# --- Boss events (see EncounterDirector herald machinery) ---
signal boss_spawned(boss_node, stats)  # A boss entered the field (HP bar + pointer listen)
signal boss_killed(stats)              # A boss died (the herald kill is the combo trigger)
signal boss_left(stats)                # A boss left unkilled (combo falls back to the level trigger)
signal leviathan_killed(stats)         # The final boss died -- the world's win trigger

# --- Secret boss events (the Anglerfish lure; see EncounterDirector) ---
signal lure_spawned(lure_node)     # The false chest surfaced (pointer targets it)
signal secret_fight_started        # Lure touched -- the world dims
signal secret_fight_ended          # The fight resolved -- light returns
signal secret_boss_killed(stats)   # Rewards: second combo capacity + the third deck

# --- Hit Batching System ---
var _hit_queue: Array = []  # Queued hits for this frame
var _batch_scheduled: bool = false  # Whether we've scheduled emission

## Queue a hit to be emitted in batch at end of frame.
func queue_enemy_hit(hit_details: Dictionary):
	_hit_queue.append(hit_details)
	if not _batch_scheduled:
		_batch_scheduled = true
		# Use call_deferred to emit all hits at end of frame
		call_deferred("_flush_hit_batch")

## Emit all queued hits as a batch, then clear.
func _flush_hit_batch():
	if _hit_queue.size() > 0:
		# Emit batch signal for listeners that want all hits
		enemy_hit_batch.emit(_hit_queue.duplicate())
		# Also emit individual signals for backwards compatibility
		for hit in _hit_queue:
			enemy_hit.emit(hit)
		_hit_queue.clear()
	_batch_scheduled = false

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Tell GameData to save before the game quits.
		GameData.save_data()
		get_tree().quit() # Manually quit after saving
