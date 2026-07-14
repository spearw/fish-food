## projectile_stats.gd
## The BASE RESOURCE for moving projectiles.
class_name ProjectileStats
extends Resource

# --- Core Stats ---
@export var damage: int = 10
@export var speed: float = 300.0
@export var lifetime: float = 5.0 
@export var pierce: int = 0
@export var knockback_force: float = 0.0
@export_range(0.0, 1.0) var armor_penetration: float = 0.0
@export var critical_hit_rate: float = 0.05
@export var critical_hit_damage: float = .50 
@export var homing_strength: float = 0.0 # How much this projectile follows a target
@export var is_scaling: bool = false # Whether this projectile scales with area_size stat
## Cheap-placeholder hit detection: skip the Area2D (and thus the physics broadphase) and
## detect hits via the EntityRegistry spatial hash. Big win for high-fire-rate projectiles.
@export var use_spatial_hits: bool = false

# --- Stats set in runtime ---
var is_phasing: bool = false
var can_retarget: bool = false


# --- Effects ---
@export var status_to_apply: StatusEffect
@export_range(0.0, 1.0) var status_chance: float = 1.0

# --- Tag Bonuses (bonus damage vs specific enemy types) ---
# Dictionary mapping EnemyTags.Type -> float bonus (e.g., {EnemyTags.Type.FISH: 0.5} = +50% vs fish)
@export var bonus_vs_types: Dictionary = {}

# --- Effect Tags (mechanical behaviors) ---
# Which effects this projectile has (DOT, PIERCE, AOE, etc.)
@export var effects: Array[WeaponTags.Effect] = []
# Override specific effect parameters (merged with defaults from WeaponTagRegistry)
# Example: {WeaponTags.Effect.DOT: {"damage_per_tick": 8}} to override just DOT damage
@export var effect_overrides: Dictionary = {}

## Helper to check if this projectile has a specific effect.
func has_effect(effect: WeaponTags.Effect) -> bool:
	return effect in effects

## Gets merged effect data (defaults + overrides) for a specific effect.
func get_effect_data(effect: WeaponTags.Effect) -> Dictionary:
	if not has_effect(effect):
		return {}
	var overrides = effect_overrides.get(effect, {})
	return WeaponTagRegistry.get_effect_data(effect, overrides)

# --- Visuals ---
@export var texture: Texture2D
@export var scale: Vector2 = Vector2(1.0, 1.0)
@export var modulation: Color = Color.WHITE
