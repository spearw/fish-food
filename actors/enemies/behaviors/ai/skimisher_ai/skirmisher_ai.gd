## skirmisher_ai.gd
## An AI that tries to maintain an optimal range from the player,
## grouping with allies before engaging.
class_name SkirmisherAI
extends AIController

# --- Configuration ---
# The range from which to move closer.
@export var maximum_range: float = 700.0
# The ideal range to start shooting from.
@export var optimal_range: float = 500.0
# The "danger zone". If the player enters this radius, we flee back to optimal.
@export var minimum_range: float = 300.0
# How many allies are needed before engaging.
@export var critical_mass: int = 4
# The radius to check for allies.
@export var grouping_radius: float = 250.0

# Cache squared range values (avoid sqrt every frame)
var _maximum_range_sq: float
var _optimal_range_sq: float
var _minimum_range_sq: float

func _ready():
	super._ready()
	enable_ally_detection()  # SkirmisherAI relies on get_nearby_allies()
	# Pre-calculate squared ranges
	_maximum_range_sq = maximum_range * maximum_range
	_optimal_range_sq = optimal_range * optimal_range
	_minimum_range_sq = minimum_range * minimum_range
	# --- Setup ---
	# Set the initial state.
	var initial_state_name = "findalliesbehavior"
	if states.has(initial_state_name):
		self.default_state_node = states[initial_state_name]
		set_state(self.default_state_node)
		_process_state_change()
	else:
		printerr("SkirmisherAI could not find its initial state: ", initial_state_name)

func _physics_process(delta):
	# Wait until AnimationController is no longer locked.
	if get_parent().get_node("AnimationController").is_locked or current_state == null:
		return
	# --- Decision-Making ---
	if not is_instance_valid(host.player_node): return

	# Use squared distance to avoid sqrt calculation
	var distance_sq = host.global_position.distance_squared_to(host.player_node.global_position)
	var nearby_ally_count = get_nearby_allies().size() + 1

	var new_state_name = ""

	match current_state.name.to_lower():
		"fleebehavior":
			# While fleeing, reposition to optimal range
			if distance_sq >= _optimal_range_sq:
				new_state_name = "shootbehavior"
			else:
				new_state_name = "fleebehavior"

		_:
			# Flee.
			if distance_sq < _minimum_range_sq:
				new_state_name = "fleebehavior"
			# Group.
			elif nearby_ally_count < self.critical_mass:
				new_state_name = "findalliesbehavior"
			# Engage.
			elif distance_sq > _maximum_range_sq:
				new_state_name = "chasebehavior"
			# Attack.
			else:
				new_state_name = "shootbehavior"

		
	# --- State Transition ---
	# We need to pass context for the Flee and FindAllies behaviors.
	var context = {}
	if new_state_name == "fleebehavior":
		context["target"] = host.player_node
	elif new_state_name == "findalliesbehavior":
		context["ignore_list"] = get_nearby_allies()
		states["findalliesbehavior"].update_context(context)
		
	var desired_state_node = states[new_state_name]
	if desired_state_node != current_state:
		set_state(desired_state_node, context)

	# --- Execute Active Behavior ---
	super._physics_process(delta)
