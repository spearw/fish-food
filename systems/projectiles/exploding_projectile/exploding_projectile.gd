## exploding_projectile.gd
## A projectile that spawns an effect when it is destroyed.
## It expects its 'stats' property to be a MultiStageProjectileStats resource.
class_name ExplodingProjectile
extends Projectile

func _destroy():
	# Cast generic 'stats' property to the specific type we need.
	var multi_stage_data := stats as MultiStageProjectileStats
	
	# Check for the right data and that an on-death effect is defined.
	if multi_stage_data and multi_stage_data.on_death_effect_stats:
		var explosion_instance = multi_stage_data.on_death_effect_scene.instantiate()
		
		# Configure the explosion with the data from our stats.
		explosion_instance.stats = multi_stage_data.on_death_effect_stats
		explosion_instance.allegiance = self.allegiance
		explosion_instance.user = self.user
		if "attribution_key" in explosion_instance:
			explosion_instance.attribution_key = attribution_key
		
		get_tree().current_scene.add_child(explosion_instance)
		explosion_instance.global_position = self.global_position
		
	super._destroy()
