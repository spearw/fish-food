## horde_ai.gd
## An AI that groups up before attacking.
class_name HordeAI
extends AIController

@export var grouping_radius: float = 200.0
@export var critical_mass: int = 5

func _ready():
	super._ready()
	enable_ally_detection()  # HordeAI relies on get_nearby_allies()
	# --- Setup ---
	# Set the initial state.
	var initial_state_name = "findalliesbehavior"
	if states.has(initial_state_name):
		self.default_state_node = states[initial_state_name]
		set_state(self.default_state_node)
		_process_state_change()
	else:
		printerr("HordeAI could not find its initial state: ", initial_state_name)

func _physics_process(delta):
	# Wait until AnimationController is no longer locked.
	if get_parent().get_node("AnimationController").is_locked or current_state == null:
		return
	# Get list of nearby allies
	var nearby_allies = get_nearby_allies()
	
	if nearby_allies.size() + 1 >= self.critical_mass:
		# We have a big enough group! Attack!
		set_state(states["chasebehavior"])
	else:
		# Not enough allies. Group up.
		# Tell the FindAllies behavior to ignore the allies already found.
		var context = { "ignore_list": nearby_allies }

		if current_state.name.to_lower() != "findalliesbehavior":
			# Change to find allies.
			set_state(states["findalliesbehavior"], context)
		else:
			# Update state with current surrounding allies.
			states["findalliesbehavior"].update_context(context)
			
	super._physics_process(delta)
