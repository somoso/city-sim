class_name CameraController
extends Camera2D
## Keyboard and mouse camera: WASD/arrows pan, wheel zooms, middle or right drag pans.

const PAN_SPEED := 900.0
const ZOOM_MIN := 0.35
const ZOOM_MAX := 3.0

var _drag_button := -1
var _drag_moved := false
var bounds := Rect2()


func set_map_bounds(grid: CityGrid) -> void:
	var top := IsoMath.tile_to_screen(0, 0)
	var right := IsoMath.tile_to_screen(grid.width, 0)
	var bottom := IsoMath.tile_to_screen(grid.width, grid.height)
	var left := IsoMath.tile_to_screen(0, grid.height)
	bounds = Rect2(Vector2(left.x, top.y), Vector2(right.x - left.x, bottom.y - top.y)).grow(200.0)


func focus_tile(tile: Vector2i) -> void:
	position = IsoMath.tile_center(tile.x, tile.y)


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if dir != Vector2.ZERO:
		position += dir.normalized() * PAN_SPEED * delta / zoom.x
		_clamp_position()


## Returns true if the event was consumed. Called by the game controller from _unhandled_input.
func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(1.15, mb.position)
			return true
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(1.0 / 1.15, mb.position)
			return true
		if mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_drag_button = mb.button_index
				_drag_moved = false
			elif _drag_button == mb.button_index:
				_drag_button = -1
				# A right click without dragging is left for the tool controller to cancel with.
				return _drag_moved or mb.button_index == MOUSE_BUTTON_MIDDLE
			return mb.button_index == MOUSE_BUTTON_MIDDLE
	elif event is InputEventMouseMotion and _drag_button != -1:
		var mm := event as InputEventMouseMotion
		if mm.relative.length() > 0.0:
			_drag_moved = true
		position -= mm.relative / zoom.x
		_clamp_position()
		return true
	return false


func was_drag() -> bool:
	return _drag_moved


func _zoom_at(factor: float, screen_pos: Vector2) -> void:
	var half := get_viewport_rect().size * 0.5
	var before := position + (screen_pos - half) / zoom.x
	var z := clampf(zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(z, z)
	# Keep the world point under the cursor fixed.
	position = before - (screen_pos - half) / z
	_clamp_position()


func _clamp_position() -> void:
	if bounds.size == Vector2.ZERO:
		return
	position.x = clampf(position.x, bounds.position.x, bounds.end.x)
	position.y = clampf(position.y, bounds.position.y, bounds.end.y)
