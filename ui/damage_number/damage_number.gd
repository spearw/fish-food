## damage_number.gd
## A label that displays a number, animates, and then returns to pool.
extends Label

# Pooling support
var _is_pooled: bool = false
var _current_tween: Tween = null

## The blocked-hit clink: armor ate the whole hit. A small gray mark instead of silence, so the
## player LEARNS armor is eating their hits instead of wondering where the numbers went.
func start_blocked(start_position: Vector2):
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	self.text = "0"
	self.global_position = start_position
	self.global_position.x += randf_range(-8.0, 8.0)
	self.modulate = Color(0.62, 0.66, 0.72, 0.9)
	add_theme_font_size_override("font_size", 13)
	_current_tween = create_tween()
	_current_tween.tween_property(self, "global_position", global_position + Vector2(0, -10), 0.45)\
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_current_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_current_tween.finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)

## Public function to initialize the damage number.
## @param damage_amount: int - The number to display.
## @param start_position: Vector2 - The world position to spawn at.
func start(damage_amount: int, start_position: Vector2, is_crit: bool):
	# Kill any existing tween from previous use
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	if is_crit:
		self.text = str(damage_amount) + "!"
	else:
		self.text = str(damage_amount)

	self.global_position = start_position

	# Add a little random horizontal offset to make numbers overlap less.
	self.global_position.x += randf_range(-8.0, 8.0)

	# Calculate a ratio based on the damage amount, capped at 100.
	var damage_ratio = clamp(float(damage_amount) / 100.0, 0.0, 1.0)

	# Interpolate the color from white to red based on the damage ratio.
	var text_color = Color(1.0, 1.0 - damage_ratio, 1.0 - damage_ratio)
	self.modulate = text_color

	# Set the font size based on the damage ratio.
	var min_font_size = 16
	var max_font_size = 32
	var new_font_size = min_font_size + (max_font_size - min_font_size) * damage_ratio
	add_theme_font_size_override("font_size", new_font_size)

	# Create a Tween to handle the animation.
	_current_tween = create_tween()

	# Animate the position property. Move up by 20 pixels over 0.6 seconds.
	_current_tween.tween_property(self, "global_position", global_position + Vector2(0, -20), 0.6)\
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	# Animate the modulate property's alpha channel to fade out at the same time.
	_current_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# After the tween finishes, return to pool or free
	_current_tween.finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)

## Called when the animation finishes - return to pool instead of freeing.
func _on_animation_finished():
	if _is_pooled:
		DamageNumberPool.return_damage_number(self)
	else:
		queue_free()
