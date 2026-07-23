## bestiary_list.gd  (class: BestiaryList)
## The Logbook's master roster: the encounter sets the world actually spawns from, plus the boss
## ladder. logbook_verify cross-checks all of it against world.tscn's EncounterDirector wiring, so
## a creature added to the game cannot silently miss the book.
class_name BestiaryList
extends Resource

## The same EncounterSet resources world.tscn wires into the director. The swarm roster is DERIVED
## from these (timeline order), so set membership is written once and the Logbook inherits it.
@export var encounter_sets: Array[EncounterSet] = []
@export var heralds: Array[EnemyStats] = []
@export var leviathans: Array[EnemyStats] = []
@export var secret: EnemyStats

## The swarm roster in timeline order (earliest set first, in-set order preserved), each entry
## carrying its first-appearance time: [{stats: EnemyStats, from_time: int}].
func swarm_entries() -> Array:
	var sets := encounter_sets.duplicate()
	sets.sort_custom(func(a, b): return a.time_start < b.time_start)
	var out: Array = []
	var seen: Array = []
	for encounter_set in sets:
		for stats in encounter_set.enemies:
			if stats == null or stats.display_name in seen:
				continue
			seen.append(stats.display_name)
			out.append({"stats": stats, "from_time": encounter_set.time_start})
	return out
