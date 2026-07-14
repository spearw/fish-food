## enemy_ai.gd
## A generic AI brain that manages and executes behavior states.
class_name AIController
extends Node

@onready var anim_controller: AnimationController
var states: Dictionary = {}
var current_state: EnemyBehavior = null
var default_state_node: EnemyBehavior = null
var host: Node

var proximity_detector: Area2D
var proximity_radius: float = 100.0

var _requested_state_node: EnemyBehavior = null
var _requested_context: Dictionary = {}

# Cached nearby allies (updated via signals instead of physics query)
var _cached_nearby_allies: Array[Node2D] = []
var _proximity_signals_connected: bool = false

func _ready():
	host = get_parent()
	var library = get_node("BehaviorLibrary")
	for child in library.get_children():
		if child is EnemyBehavior:
			var state_name = child.name.to_lower()
			states[state_name] = child
			child.enabled = false
	# Ally proximity detection is OPT-IN. Only AI types that call get_nearby_allies()
	# (HordeAI, SkirmisherAI) need it, so it stays disabled by default here -- otherwise
	# every enemy pays for O(n^2) Area2D overlap tracking. Those AIs call enable_ally_detection().
	self.proximity_detector = host.proximity_detector
	proximity_detector.monitoring = false
	proximity_detector.monitorable = false

	anim_controller = host.get_node("AnimationController")
	anim_controller.animation_lock_released.connect(_on_animation_lock_released)


## Opt-in ally detection for AI types that use get_nearby_allies() (HordeAI, SkirmisherAI).
## Enables the proximity Area2D and caches nearby same-type enemies via signals.
func enable_ally_detection() -> void:
	if _proximity_signals_connected:
		return
	var proximity_shape = proximity_detector.get_node("CollisionShape2D")
	proximity_shape.shape.radius = self.proximity_radius
	proximity_detector.collision_mask = 1 << 1 # enemy_body
	proximity_detector.monitoring = true
	proximity_detector.body_entered.connect(_on_proximity_body_entered)
	proximity_detector.body_exited.connect(_on_proximity_body_exited)
	_proximity_signals_connected = true

	

# This is called by the host Enemy from its _ready() function.
func initialize_ai(default_state_name: String):
	var key = default_state_name.to_lower()
	if states.has(key):
		self.default_state_node = states[key]
		set_state(self.default_state_node)
	else:
		printerr("AI Brain could not find default state named: ", key)
		# Fallback to the first available state if the name is wrong.
		if not states.is_empty():
			self.default_state_node = states.values()[0]
			set_state(self.default_state_node)

# Update context and set request for new state.
func set_state(new_state_node: EnemyBehavior, context: Dictionary = {}):
	if new_state_node != current_state:
		self._requested_state_node = new_state_node
		self._requested_context = context

func _on_animation_lock_released():
	# The animator says we're free. Check if there's a pending state change.
	_process_state_change(true)

func _physics_process(delta):
	# If the animator is busy, the AI brain does nothing.
	if anim_controller and anim_controller.is_locked:
		return

	# We're not locked, so first, process any pending state change.
	_process_state_change()

	# Then, execute the current behavior.
	if is_instance_valid(current_state):
		current_state.process_behavior(delta, host)
		
## The actual state transition logic.
func _process_state_change(is_finished=false):
	if not is_instance_valid(_requested_state_node):
		return # No request pending.

	# Skip exiting if we've already played it.
	if not is_finished:
		# Deactivate the old state and play its exit animation.
		if is_instance_valid(current_state):
			current_state.enabled = false
			if current_state.has_method("on_exit"):
				current_state.on_exit() # This might trigger an exit animation and re-lock.
				if anim_controller.is_locked:
					return # Wait for the exit animation to finish.
	
	# Execute the change.
	current_state = _requested_state_node
	_requested_state_node = null # Clear the request
	
	current_state.enabled = true
	if current_state.has_method("on_enter"):
		current_state.on_enter(host, _requested_context)

## Find nearby allies (uses cached list instead of physics query)
func get_nearby_allies() -> Array[Node2D]:
	# Filter cached allies to only include same-type enemies
	var my_name = host.stats.display_name
	var allies: Array[Node2D] = []
	for body in _cached_nearby_allies:
		if is_instance_valid(body) and body != host:
			if body.stats and body.stats.display_name == my_name:
				allies.append(body)
	return allies

## Called when a body enters the proximity detector.
func _on_proximity_body_entered(body: Node2D):
	if body != host and body not in _cached_nearby_allies:
		_cached_nearby_allies.append(body)

## Called when a body exits the proximity detector.
func _on_proximity_body_exited(body: Node2D):
	_cached_nearby_allies.erase(body)
