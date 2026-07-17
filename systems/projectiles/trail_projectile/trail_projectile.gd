## trail_projectile.gd
## A projectile that leaves a persistent trail of effects as it travels.
class_name TrailProjectile
extends Projectile

@onready var trail_spawn_timer: Timer = Timer.new()

func _ready():
	# Run all the normal projectile setup first.
	super._ready()
	
	# Cast our stats to the specific type this class needs.
	var trail_data := stats as TrailProjectileStats
	if not trail_data:
		printerr("TrailProjectile requires a TrailProjectileStats resource!")
		return
	
	# Configure and start the trail-spawning timer.
	trail_spawn_timer.wait_time = trail_data.time_between_trail_drops
	trail_spawn_timer.timeout.connect(_on_trail_spawn_timer_timeout)
	add_child(trail_spawn_timer)
	trail_spawn_timer.start()

## Called by the timer to drop a segment of the trail.
func _on_trail_spawn_timer_timeout():
	var trail_data := stats as TrailProjectileStats
	if not trail_data or not trail_data.trail_scene: return
	
	var segment = trail_data.trail_scene.instantiate()
	
	# Configure the trail segment with its own data.
	segment.stats = trail_data.trail_stats
	segment.user = self.user
	segment.allegiance = self.allegiance
	if "attribution_key" in segment:
		segment.attribution_key = attribution_key
	
	# Spawn the segment in the world at current position.
	get_tree().current_scene.add_child(segment)
	segment.global_position = self.global_position
