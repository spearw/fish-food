## goliath_artifact.gd
## An artifact that grants bonuses based on bonus max health.
class_name GoliathArtifact
extends ArtifactBase

# --- Configuration ---
# How much of each stat we get per point of BONUS max HP.
const SIZE_PER_HP = 0.005      # +0.5% size per bonus HP
const DAMAGE_PER_HP = 0.01     # +1% damage per bonus HP
const SPEED_PENALTY_PER_HP = -0.01 # -1% speed per bonus HP

# --- Helper ---
func _get_bonus_hp() -> float:
	if not is_instance_valid(user): return 0.0
	var base_hp = user.stats.max_health  # authored base; get_stat("max_health") is the modified max
	var current_max_hp = user.get_stat("max_health")
	return max(0, current_max_hp - base_hp)

# --- ArtifactBase Overrides ---

func get_size_modifier() -> float:
	return 1.0 + (_get_bonus_hp() * SIZE_PER_HP)

func get_damage_modifier() -> float:
	return 1.0 + (_get_bonus_hp() * DAMAGE_PER_HP)

func get_speed_modifier() -> float:
	return 1.0 + (_get_bonus_hp() * SPEED_PENALTY_PER_HP)
