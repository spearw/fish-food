## game_settings.gd
## Player-facing options, including PERFORMANCE toggles that disable non-essential VISUAL effects for
## weaker hardware. Autoload singleton "GameSettings". Persisted to user://settings.cfg.
##
## Philosophy (see .claude/performance/): gameplay cost is bounded by design, so it never has to be
## sacrificed for FPS. These toggles only trade away *cosmetic* cost -- damage numbers, health bars,
## status tints/VFX -- for a player whose machine still struggles. Nothing here changes mechanics.
## All default to ON (full fidelity); a settings menu can flip them, or GameSettings.set_performance_mode().
extends Node

const SETTINGS_PATH := "user://settings.cfg"

# --- Performance / visual toggles (all default ON = full fidelity) ---
var show_damage_numbers: bool = true
var show_health_bars: bool = true
var show_status_vfx: bool = true

func _ready() -> void:
	load_settings()

## Convenience preset: turn cosmetic effects off (on) for weaker hardware and persist.
func set_performance_mode(enabled: bool) -> void:
	show_damage_numbers = not enabled
	show_health_bars = not enabled
	show_status_vfx = not enabled
	save_settings()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("performance", "show_damage_numbers", show_damage_numbers)
	cfg.set_value("performance", "show_health_bars", show_health_bars)
	cfg.set_value("performance", "show_status_vfx", show_status_vfx)
	cfg.save(SETTINGS_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return  # no saved settings yet -> keep defaults
	show_damage_numbers = cfg.get_value("performance", "show_damage_numbers", show_damage_numbers)
	show_health_bars = cfg.get_value("performance", "show_health_bars", show_health_bars)
	show_status_vfx = cfg.get_value("performance", "show_status_vfx", show_status_vfx)
