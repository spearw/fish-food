## status_effect_manager.gd
## A generic component that hosts and executes any type of StatusEffect.
class_name StatusEffectManager
extends Node

# Key: status.id, Value: a dictionary containing the effect and its timer
var active_statuses: Dictionary = {}
var host: Node
var _cached_modulate_color: Color = Color.WHITE  # Incrementally tracked modulate

# Cached array of statuses that need per-frame processing (avoids dictionary iteration)
var _processing_statuses: Array = []  # Array of {effect, source} dicts
var _processing_cache_dirty: bool = false

func _ready():
	host = get_parent()
	# Idle by default. Most enemies have no active status at any moment, and a per-frame status (DOT)
	# turns processing back on in apply_status. Without this, every enemy's manager dispatches an empty
	# _physics_process every frame -- at hundreds of enemies that is the single most-multiplied cost in
	# the status system, for zero work. Duration expiry uses one-shot Timers, so it still fires while idle.
	set_physics_process(false)

func _physics_process(delta: float):
	# Rebuild processing cache if dirty
	if _processing_cache_dirty:
		_rebuild_processing_cache()
		# Nothing needs per-frame processing anymore -> go idle until the next processing status.
		if _processing_statuses.is_empty():
			set_physics_process(false)
			return

	# Fast iteration over pre-cached array (no dictionary lookups)
	for data in _processing_statuses:
		data.effect.on_process(self, delta, data.source)

## Rebuild the cached array of statuses for processing.
## Only includes statuses with needs_processing=true.
func _rebuild_processing_cache():
	_processing_statuses.clear()
	for status_id in active_statuses:
		var status_data = active_statuses[status_id]
		var effect = status_data["effect"]
		# Only cache statuses that need per-frame processing
		if effect.needs_processing:
			_processing_statuses.append({
				"effect": effect,
				"source": status_data["source"]
			})
	_processing_cache_dirty = false

func apply_status(status_resource: StatusEffect, source: Node, attribution_key: String = ""):
	if not status_resource: return

	# Duplicate the resource to create a unique instance for this enemy.
	var status_instance: StatusEffect = status_resource.duplicate(true)
	# Stamp the applier's identity so damaging ticks credit the right damage-report row.
	if attribution_key != "" and "attribution_key" in status_instance:
		status_instance.attribution_key = attribution_key

	if active_statuses.has(status_instance.id):
		# Status already exists: refresh its duration -- and stacking statuses (venom) gain a
		# stack per application, up to their cap. The FIRST application's instance (and its
		# attribution) persists; later duplicates only feed it.
		var existing = active_statuses[status_instance.id]["effect"]
		if "stacks" in existing and existing.max_stacks > 1:
			existing.stacks = mini(existing.stacks + 1, existing.max_stacks)
		active_statuses[status_instance.id]["timer"].start(status_instance.duration)
	else:
		# This is a new status.
		var duration = status_instance.duration
		if is_instance_valid(source):
			duration *= source.get_stat("status_duration")
		var duration_timer = Timer.new()
		duration_timer.one_shot = true
		duration_timer.wait_time = duration
		# Use Callable.bind() instead of lambda to avoid signal memory leaks
		duration_timer.timeout.connect(_on_status_expired.bind(status_instance.id, source))
		add_child(duration_timer)
		var vfx_instance = _apply_visuals(status_instance)
		
		active_statuses[status_instance.id] = {
			"effect": status_instance,
			"timer": duration_timer,
			"source": source,
			"vfx_instance": vfx_instance
		}

		# Mark cache dirty so _physics_process rebuilds it
		_processing_cache_dirty = true
		# Only take per-frame processing time if this status actually needs it (e.g. DOT). Statuses
		# like SLOW have needs_processing=false and expire via their one-shot Timer, staying idle.
		if status_instance.needs_processing:
			set_physics_process(true)

		duration_timer.start()
		status_instance.on_apply(self, source)
		
	# Emit signal whether new status or not.
	Events.emit_signal("status_applied_to_enemy", host, status_instance.id)

func _on_status_expired(status_id: String, source):
	if active_statuses.has(status_id):
		var status_instance = active_statuses[status_id]["effect"]
		var timer = active_statuses[status_id]["timer"]
		var vfx_instance = active_statuses[status_id]["vfx_instance"]
		_remove_visuals(status_instance, vfx_instance)

		active_statuses.erase(status_id)
		timer.queue_free()

		# Mark cache dirty so _physics_process rebuilds it
		_processing_cache_dirty = true

		status_instance.on_expire(self, source)
		
func _apply_visuals(status_instance: StatusEffect):
	var vfx_instance = null
	var host_sprite = host.get_node_or_null("AnimatedSprite2D")

	if status_instance.vfx_sprite_frames and GameSettings.show_status_vfx:
		# This status has a complex animated effect (an extra AnimatedSprite2D per afflicted enemy).
		# Optional under the performance setting; the cheap color tint below still conveys the status.
		vfx_instance = preload("res://items/effects/status_vfx/status_vfx.tscn").instantiate()
		vfx_instance.sprite_frames_resource = status_instance.vfx_sprite_frames
		host.add_child(vfx_instance) # Attach the VFX
	elif status_instance.modulate_color != Color.WHITE and host_sprite:
		# O(1) incremental color update instead of O(n) recalculation
		_cached_modulate_color = _cached_modulate_color * status_instance.modulate_color
		host_sprite.modulate = _cached_modulate_color
	return vfx_instance
	
func _remove_visuals(status_instance: StatusEffect, vfx_instance):
		if is_instance_valid(vfx_instance):
			# Remove vfx scene is it exists
			vfx_instance.queue_free()
		else:
			# Unapply color modulation by dividing out the removed color
			var host_sprite = host.get_node_or_null("AnimatedSprite2D")
			if host_sprite and status_instance.modulate_color != Color.WHITE:
				# O(1) incremental removal: divide out the color being removed
				var color = status_instance.modulate_color
				# Safely divide (avoid division by zero)
				if color.r > 0.001 and color.g > 0.001 and color.b > 0.001:
					_cached_modulate_color.r /= color.r
					_cached_modulate_color.g /= color.g
					_cached_modulate_color.b /= color.b
					_cached_modulate_color.a /= max(color.a, 0.001)
				else:
					# Fallback: full recalc if color has near-zero components
					_recalculate_modulate_cache()
				host_sprite.modulate = _cached_modulate_color

## Recalculates the cached modulate color from scratch (fallback for edge cases).
func _recalculate_modulate_cache():
	_cached_modulate_color = Color.WHITE
	for status_id in active_statuses:
		var status_effect = active_statuses[status_id]["effect"]
		_cached_modulate_color = _cached_modulate_color * status_effect.modulate_color
