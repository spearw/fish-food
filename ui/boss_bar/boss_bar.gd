## boss_bar.gd
## Top-of-screen boss health bar plus an off-screen pointer. Listens to the boss events and tracks
## the live boss node; the pointer keeps ring-edge spawns findable (bosses are never recycled closer).
extends CanvasLayer

@onready var panel: VBoxContainer = $TopAnchor
@onready var name_label: Label = $TopAnchor/NameLabel
@onready var bar: ProgressBar = $TopAnchor/Bar
@onready var arrow: Node2D = $Arrow

## Pointer margin from the screen edge, px.
const EDGE_MARGIN := 56.0

var _boss: Node = null
## The anglerfish lure: pointed at (in gold) while no boss is up -- treasure reads as findable.
var _lure: Node = null

const BOSS_ARROW := Color(1, 0.35, 0.3, 0.9)
const LURE_ARROW := Color(1, 0.85, 0.4, 0.9)

func _ready() -> void:
	panel.visible = false
	arrow.visible = false
	Events.boss_spawned.connect(_on_boss_spawned)
	Events.boss_killed.connect(_on_boss_gone)
	Events.boss_left.connect(_on_boss_gone)
	Events.lure_spawned.connect(func(lure): _lure = lure)

func _on_boss_spawned(boss_node, stats) -> void:
	_boss = boss_node
	name_label.text = stats.display_name
	bar.max_value = stats.max_health
	bar.value = stats.max_health
	panel.visible = true

func _on_boss_gone(_stats) -> void:
	_boss = null
	panel.visible = false
	arrow.visible = false

func _process(_delta: float) -> void:
	if _boss != null:
		if not is_instance_valid(_boss) or _boss.is_dying:
			_on_boss_gone(null)
			return
		bar.value = _boss.current_health
		_update_arrow(_boss, BOSS_ARROW)
		return
	if _lure != null:
		if not is_instance_valid(_lure):
			_lure = null
			arrow.visible = false
			return
		_update_arrow(_lure, LURE_ARROW)

## Points at the target from the screen edge while it's off-screen; hides once it's visible.
func _update_arrow(target: Node2D, color: Color) -> void:
	arrow.modulate = color
	var vp_rect := get_viewport().get_visible_rect()
	var screen_pos: Vector2 = target.get_global_transform_with_canvas().origin
	if vp_rect.grow(-8.0).has_point(screen_pos):
		arrow.visible = false
		return
	var center := vp_rect.size * 0.5
	var to_target := screen_pos - center
	var clamped := center + to_target.limit_length(minf(center.x, center.y) * 2.0)
	clamped.x = clampf(clamped.x, EDGE_MARGIN, vp_rect.size.x - EDGE_MARGIN)
	clamped.y = clampf(clamped.y, EDGE_MARGIN, vp_rect.size.y - EDGE_MARGIN)
	arrow.position = clamped
	arrow.rotation = to_target.angle()
	arrow.visible = true
