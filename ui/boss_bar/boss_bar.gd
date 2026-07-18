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

func _ready() -> void:
	panel.visible = false
	arrow.visible = false
	Events.boss_spawned.connect(_on_boss_spawned)
	Events.boss_killed.connect(_on_boss_gone)
	Events.boss_left.connect(_on_boss_gone)

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
	if _boss == null:
		return
	if not is_instance_valid(_boss) or _boss.is_dying:
		_on_boss_gone(null)
		return
	bar.value = _boss.current_health
	_update_arrow()

## Points at the boss from the screen edge while it's off-screen; hides once it's visible.
func _update_arrow() -> void:
	var vp_rect := get_viewport().get_visible_rect()
	var screen_pos: Vector2 = _boss.get_global_transform_with_canvas().origin
	if vp_rect.grow(-8.0).has_point(screen_pos):
		arrow.visible = false
		return
	var center := vp_rect.size * 0.5
	var to_boss := screen_pos - center
	var clamped := center + to_boss.limit_length(minf(center.x, center.y) * 2.0)
	clamped.x = clampf(clamped.x, EDGE_MARGIN, vp_rect.size.x - EDGE_MARGIN)
	clamped.y = clampf(clamped.y, EDGE_MARGIN, vp_rect.size.y - EDGE_MARGIN)
	arrow.position = clamped
	arrow.rotation = to_boss.angle()
	arrow.visible = true
