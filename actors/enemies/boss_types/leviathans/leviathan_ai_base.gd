## leviathan_ai_base.gd -- shared final-boss brain: HP-third phase tracking plus the herald rider.
## The rider is the slain herald's trait passed down the food chain, small and thematic:
##   Spined (Bloom): phase transitions release a spine burst.
##   Restless (Warden): telegraphs run 20% faster.
##   Quilled (Quillmother): each finished attack leaves a few drifting spines.
## Scene-attached only; the three leviathan AIs extend this by path (no class_name).
extends AIController

var rider: String = ""
## Multiplier on telegraph windows (Restless shrinks it).
var telegraph_scale: float = 1.0
## 0 = full health, 1 = below two thirds, 2 = below one third.
var _phase: int = 0

func _ready():
	super._ready()
	rider = CurrentRun.leviathan_rider()
	if rider == "Restless":
		telegraph_scale = 0.8

## Advances the phase when an HP third is crossed. Returns the new phase, or -1 if unchanged.
func _update_phase() -> int:
	var frac: float = float(host.current_health) / maxf(1.0, float(host.stats.max_health))
	var target := 0
	if frac <= 1.0 / 3.0:
		target = 2
	elif frac <= 2.0 / 3.0:
		target = 1
	if target > _phase:
		_phase = target
		_on_phase_transition()
		return target
	return -1

## Called on every crossed HP third. Subclasses chain with super.
func _on_phase_transition() -> void:
	if rider == "Spined":
		fire_named("SpineNovaWeapon")

## Called by subclasses when an attack sequence finishes.
func _after_attack() -> void:
	if rider == "Quilled":
		fire_named("SpineVolleyWeapon")

## Fires ONE named weapon; the leviathan kits split their weapons by role.
func fire_named(node_name: String) -> void:
	for w in host._cached_weapons:
		if is_instance_valid(w) and w.name == node_name and w.has_method("fire"):
			w.fire()
