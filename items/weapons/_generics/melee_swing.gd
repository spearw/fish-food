## melee_swing.gd
## The controller for the melee swing effect. Plays the animation.
extends Node2D

## Damage-report identity, set by FireBehaviorComponent like any projectile; the child Hitbox
## passes this node as the damage source.
var attribution_key: String = ""

# Properties needed by FireBehaviorComponent (matching Projectile interface)
var stats: ProjectileStats
var allegiance: Projectile.Allegiance
var user: Node2D
var weapon: Node2D
var direction: Vector2 = Vector2.RIGHT
var target: Node2D  # Not used by melee, but required by FireBehaviorComponent

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hitbox: Area2D = $Hitbox
@onready var lifetime_timer: Timer = $LifetimeTimer

func _ready():
	# Pass configuration data down to the hitbox.
	hitbox.stats = stats
	hitbox.allegiance = allegiance
	hitbox.pierce_count = stats.pierce + 1 if stats.pierce != -1 else -1

	# Pass user and weapon if the hitbox needs them (e.g., for spawning sparks)
	if "user" in hitbox:
		hitbox.user = user
	if "weapon" in hitbox:
		hitbox.weapon = weapon

	# Configure and start the self-destruct timer.
	lifetime_timer.wait_time = stats.lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(queue_free)
	lifetime_timer.start()

	await get_tree().process_frame

	# Play the animation.
	animation_player.play("swing")
