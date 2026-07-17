## persistent_effect_stats.gd
## A specialized resource for persistent AoE effects like auras or ground patches.
class_name PersistentEffectStats
extends ProjectileStats

# --- Persistent Effect Properties ---
# How often the effect applies its payload (damage/status) in seconds.
@export var tick_rate: float = 0.5
## Rolling Fog (Venom deck): zones with drift_speed > 0 creep toward the nearest enemy.
@export var drift_speed: float = 0.0
# The SpriteFrames resource for the aura's animation (e.g., a looping fire ring).
@export var animation: SpriteFrames
# How long the persistent effect lasts on the ground, in seconds.
@export var duration: float = 3.0
