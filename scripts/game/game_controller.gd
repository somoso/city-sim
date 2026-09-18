extends Node2D
## Root of the game scene: runs the simulation clock, routes input to tools and camera,
## and keeps the render layers in sync with the grid.

@onready var terrain_layer: TerrainLayer = $World/TerrainLayer
@onready var world_layer: WorldLayer = $World/WorldLayer
@onready var overlay_layer: OverlayLayer = $World/OverlayLayer
@onready var cursor_layer: CursorLayer = $World/CursorLayer
@onready var camera: CameraController = $Camera2D
@onready var hud = $HUD

var tools := BuildTools.new()
var _accum := 0.0
var _dragging := false
var _drag_start := Vector2i(-1, -1)
var _hover := Vector2i(-1, -1)


func _ready() -> void:
	if not GameState.has_city():
		GameState.new_city(64, 64, randi() % 1000000, "New City", false)
	_setup_city()
	Events.city_started.connect(_setup_city)
	Events.tiles_changed.connect(_on_tiles_changed)
	Events.world_changed.connect(_on_world_changed)
	Events.overlay_changed.connect(func(o: int) -> void: overlay_layer.set_overlay(o))
	Events.tool_changed.connect(func(_t: int) -> void:
		_dragging = false
		cursor_layer.end_drag())


func _setup_city() -> void:
	var grid := GameState.grid
	terrain_layer.setup(grid)
	world_layer.setup(grid)
	overlay_layer.setup(grid)
	overlay_layer.set_overlay(GameState.current_overlay)
	cursor_layer.setup(grid, tools)
	camera.set_map_bounds(grid)
	camera.focus_tile(TerrainGenerator.find_start_tile(grid))
	_accum = 0.0
	_dragging = false


func _process(delta: float) -> void:
	var s := GameState.speed
	if s > 0 and GameState.has_city():
		_accum += delta
		var period: float = Constants.MONTH_SECONDS[s]
		if _accum >= period:
			_accum -= period
			GameState.tick_month()


## Fraction of the current month that has elapsed (0..1), for the HUD day counter.
func month_progress() -> float:
	var s := GameState.speed
	if s <= 0:
		return 0.0
	var period: float = Constants.MONTH_SECONDS[s]
	return clampf(_accum / period, 0.0, 0.999)


func _unhandled_input(event: InputEvent) -> void:
	if camera.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if _handle_key(event as InputEventKey):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_hover = _tile_under_mouse()
		cursor_layer.set_hover(_hover)
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		_hover = _tile_under_mouse()
		cursor_layer.set_hover(_hover)
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_begin_press()
			else:
				_end_press()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed and not camera.was_drag():
			if _dragging:
				_dragging = false
				cursor_layer.end_drag()
			else:
				GameState.set_tool(Constants.Tool.NONE)
			get_viewport().set_input_as_handled()


func _handle_key(k: InputEventKey) -> bool:
	match k.keycode:
		KEY_ESCAPE:
			if hud.close_panels():
				return true
			GameState.set_tool(Constants.Tool.NONE)
			return true
		KEY_SPACE:
			if GameState.speed == 0:
				GameState.set_speed(1)
			else:
				GameState.set_speed(0)
			return true
		KEY_1:
			GameState.set_speed(1)
			return true
		KEY_2:
			GameState.set_speed(2)
			return true
		KEY_3:
			GameState.set_speed(3)
			return true
		KEY_B:
			GameState.set_tool(Constants.Tool.BULLDOZE)
			return true
		KEY_R:
			GameState.set_tool(Constants.Tool.ROAD)
			return true
		KEY_Q:
			GameState.set_tool(Constants.Tool.QUERY)
			return true
	return false


func _tile_under_mouse() -> Vector2i:
	return IsoMath.screen_to_tile(get_global_mouse_position())


func _begin_press() -> void:
	var tool := GameState.current_tool
	if not GameState.grid.in_bounds(_hover.x, _hover.y):
		return
	if BuildingDefs.tool_is_area(tool) or BuildingDefs.tool_is_line(tool):
		_dragging = true
		_drag_start = _hover
		cursor_layer.begin_drag(_hover)


func _end_press() -> void:
	var tool := GameState.current_tool
	var grid := GameState.grid
	if _dragging:
		_dragging = false
		cursor_layer.end_drag()
		var end := Vector2i(clampi(_hover.x, 0, grid.width - 1), clampi(_hover.y, 0, grid.height - 1))
		if BuildingDefs.tool_is_area(tool):
			tools.apply_area(tool, _drag_start.x, _drag_start.y, end.x, end.y)
		elif BuildingDefs.tool_is_line(tool):
			tools.apply_line(tool, _drag_start.x, _drag_start.y, end.x, end.y)
		return
	if not grid.in_bounds(_hover.x, _hover.y):
		return
	if BuildingDefs.tool_is_building(tool):
		tools.apply_point(tool, _hover.x, _hover.y)
	elif tool == Constants.Tool.QUERY or tool == Constants.Tool.NONE:
		Events.tile_selected.emit(grid.idx(_hover.x, _hover.y))


## Applies the current tool programmatically (used by tests).
func apply_tool_at(tool: int, x0: int, y0: int, x1: int, y1: int) -> void:
	if BuildingDefs.tool_is_area(tool):
		tools.apply_area(tool, x0, y0, x1, y1)
	elif BuildingDefs.tool_is_line(tool):
		tools.apply_line(tool, x0, y0, x1, y1)
	elif BuildingDefs.tool_is_building(tool):
		tools.apply_point(tool, x0, y0)


func _on_tiles_changed(indices: PackedInt32Array) -> void:
	world_layer.mark_tiles_dirty(indices)
	terrain_layer.mark_tiles_dirty(indices)
	if overlay_layer.visible:
		overlay_layer.mark_all_dirty()
	cursor_layer.queue_redraw()


func _on_world_changed() -> void:
	world_layer.mark_all_dirty()
	terrain_layer.mark_all_dirty()
	if overlay_layer.visible:
		overlay_layer.mark_all_dirty()
	cursor_layer.queue_redraw()
