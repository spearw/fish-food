## puffer_ai.gd -- The Bloom (herald): a phase boss built on the armor system.
## Deflated: quick chase, no armor, vulnerable -- the damage window.
## Inflated: slow drift, heavy armor, telegraphed spike rain -- your pen/DoT/chip answers matter.
## Each transition fires the spine nova. Scene-attached only (no class_name -> no cache rebuild).
extends AIController

@export var deflated_secs: float = 14.0
@export var inflated_secs: float = 9.0
@export var inflated_armor: int = 30
## Inflated drift speed as a share of the (size-scaled) chase speed.
@export var inflated_speed_mult: float = 0.25
## Seconds between spike-rain volleys while inflated.
@export var rain_every: float = 3.0

var _inflated: bool = false
var _phase_left: float = 0.0
var _rain_left: float = 0.0
var _chase_speed: float = 0.0
var _base_sprite_scale: Vector2 = Vector2.ONE

func _ready():
	super._ready()
	_phase_left = deflated_secs

func _physics_process(delta):
	if not is_instance_valid(host) or host.is_dying or not is_instance_valid(host.player_node):
		super._physics_process(delta)
		return
	# The size-scaled chase speed only exists after spawn, so it's captured lazily.
	if _chase_speed <= 0.0:
		_chase_speed = host.stats.move_speed
		_base_sprite_scale = host.animated_sprite.scale
		set_state(states["chasebehavior"])

	_phase_left -= delta
	if _phase_left <= 0.0:
		if _inflated:
			_deflate()
		else:
			_inflate()

	if _inflated:
		_rain_left -= delta
		if _rain_left <= 0.0:
			_rain_left = rain_every
			_fire_weapon("SpikeRainWeapon")

	super._physics_process(delta)

## Inflated: armor up, drift, and the nova punishes anything close when it pops.
func _inflate() -> void:
	_inflated = true
	_phase_left = inflated_secs
	_rain_left = rain_every * 0.5
	host.stats.armor = inflated_armor
	host.stats.move_speed = _chase_speed * inflated_speed_mult
	_tween_sprite(_base_sprite_scale * 1.25)
	_fire_weapon("SpineNovaWeapon")

func _deflate() -> void:
	_inflated = false
	_phase_left = deflated_secs
	host.stats.armor = 0
	host.stats.move_speed = _chase_speed
	_tween_sprite(_base_sprite_scale)
	_fire_weapon("SpineNovaWeapon")

func _tween_sprite(target: Vector2) -> void:
	var tween := host.create_tween()
	tween.tween_property(host.animated_sprite, "scale", target, 0.35)

## Fires ONE named weapon (fire_weapons() fires everything; the kit is phase-split).
func _fire_weapon(node_name: String) -> void:
	if not host.is_on_screen:
		return
	for w in host._cached_weapons:
		if is_instance_valid(w) and w.name == node_name and w.has_method("fire"):
			w.fire()
