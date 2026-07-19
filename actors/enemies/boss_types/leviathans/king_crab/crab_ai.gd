## crab_ai.gd -- The King Crab: the armor exam, writ large.
## Plated at heavy flat armor. Crossing each HP third MOLTS the shell: armor drops to zero for a
## short window (the burst-damage opportunity), jellies swarm out of the broken shell, then it
## re-hardens. Claw slams run throughout on aimed telegraphs.
extends "res://actors/enemies/boss_types/leviathans/leviathan_ai_base.gd"

@export var plated_armor: int = 25
@export var molt_secs: float = 6.0
@export var slam_every: float = 4.0
@export var adds_per_molt: int = 2
@export var summon_stats: EnemyStats

var _slam_t: float = 0.0
var _molt_left: float = 0.0
var _plated: bool = false
var _director: Node = null

func _ready():
	super._ready()
	_slam_t = slam_every * 0.5

func _physics_process(delta):
	if not is_instance_valid(host) or host.is_dying or not is_instance_valid(host.player_node):
		super._physics_process(delta)
		return
	# The plate goes on at the first tick (the spawn-time stats are per-instance duplicates).
	if not _plated:
		_plated = true
		host.stats.armor = plated_armor
	_update_phase()

	if _molt_left > 0.0:
		_molt_left -= delta
		if _molt_left <= 0.0:
			host.stats.armor = plated_armor

	set_state(states["chasebehavior"])
	_slam_t -= delta
	if _slam_t <= 0.0:
		_slam_t = slam_every
		fire_named("ClawSlamWeapon")
		_after_attack()

	super._physics_process(delta)

## Each crossed third breaks the shell: the molt window is when the crab can actually be hurt
## by blunt builds -- and what crawls out keeps the pressure honest.
func _on_phase_transition() -> void:
	super._on_phase_transition()
	host.stats.armor = 0
	_molt_left = molt_secs
	_flash_molt()
	_summon_adds()

func _summon_adds() -> void:
	if summon_stats == null:
		return
	if _director == null or not is_instance_valid(_director):
		_director = host.get_tree().current_scene.find_child("EncounterDirector", true, false)
	if _director == null:
		return
	for i in range(adds_per_molt):
		var offset := Vector2.RIGHT.rotated(randf_range(0, TAU)) * randf_range(90.0, 150.0)
		_director.spawn_enemy(summon_stats, host.global_position + offset)

func _flash_molt() -> void:
	var tween := host.create_tween()
	tween.tween_property(host, "modulate", Color(1.8, 1.8, 1.8, 0.7), 0.25)
	tween.tween_property(host, "modulate", host.stats.modulate, 0.35)
