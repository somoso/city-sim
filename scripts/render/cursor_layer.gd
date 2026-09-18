class_name CursorLayer
extends Node2D
## Hover highlight, drag previews and cost labels for the active tool.

var grid: CityGrid = null
var tools: BuildTools = null
var hover := Vector2i(-1, -1)
var drag_start := Vector2i(-1, -1)
var dragging := false
var draw_count := 0

const OK_FILL := Color(0.3, 1.0, 0.4, 0.35)
const BAD_FILL := Color(1.0, 0.3, 0.3, 0.40)
const HOVER := Color(1, 1, 1, 0.9)


func setup(g: CityGrid, t: BuildTools) -> void:
	grid = g
	tools = t
	queue_redraw()


func set_hover(tile: Vector2i) -> void:
	if tile != hover:
		hover = tile
		queue_redraw()


func begin_drag(tile: Vector2i) -> void:
	drag_start = tile
	dragging = true
	queue_redraw()


func end_drag() -> void:
	dragging = false
	drag_start = Vector2i(-1, -1)
	queue_redraw()


func _draw() -> void:
	draw_count += 1
	if grid == null or not grid.in_bounds(hover.x, hover.y):
		return
	var tool := GameState.current_tool
	var font := ThemeDB.fallback_font
	if dragging and BuildingDefs.tool_is_area(tool):
		var x0 := mini(drag_start.x, hover.x)
		var x1 := maxi(drag_start.x, hover.x)
		var y0 := mini(drag_start.y, hover.y)
		var y1 := maxi(drag_start.y, hover.y)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var ok := tools.can_apply_at(tool, x, y)
				draw_colored_polygon(IsoMath.diamond(x, y), OK_FILL if ok else BAD_FILL)
		var cost := tools.area_cost(tool, x0, y0, x1, y1)
		_draw_label(font, IsoMath.tile_center(hover.x, hover.y) + Vector2(0, -24), "$%d  (%dx%d)" % [cost, x1 - x0 + 1, y1 - y0 + 1])
	elif dragging and BuildingDefs.tool_is_line(tool):
		for p in tools.line_tiles(drag_start.x, drag_start.y, hover.x, hover.y):
			if not grid.in_bounds(p.x, p.y):
				continue
			var ok := tools.can_apply_at(tool, p.x, p.y)
			draw_colored_polygon(IsoMath.diamond(p.x, p.y), OK_FILL if ok else BAD_FILL)
		var cost := tools.line_cost(tool, drag_start.x, drag_start.y, hover.x, hover.y)
		_draw_label(font, IsoMath.tile_center(hover.x, hover.y) + Vector2(0, -24), "$%d" % cost)
	elif BuildingDefs.tool_is_building(tool):
		var type: int = BuildingDefs.TOOL_BUILDING[tool]
		var fsize := int(BuildingDefs.def_value(type, "size", 1))
		var ok := tools.can_apply_at(tool, hover.x, hover.y)
		var fill := OK_FILL if ok else BAD_FILL
		for dy in range(fsize):
			for dx in range(fsize):
				if grid.in_bounds(hover.x + dx, hover.y + dy):
					draw_colored_polygon(IsoMath.diamond(hover.x + dx, hover.y + dy), fill)
		var height := float(BuildingDefs.def_value(type, "height", 10))
		var ghost: Color = BuildingDefs.def_value(type, "color", Color.GRAY)
		ghost.a = 0.45
		IsoMath.draw_box(self, IsoMath.diamond(hover.x, hover.y, fsize, 0.12), height, ghost, false)
		if BuildingDefs.def_value(type, "coverage", "") != "":
			var r := float(BuildingDefs.def_value(type, "radius", 0))
			var c := IsoMath.tile_center(hover.x, hover.y)
			c += IsoMath.tile_to_screen(float(fsize - 1) * 0.5, float(fsize - 1) * 0.5)
			_draw_iso_ellipse(c, r, Color(1, 1, 1, 0.6))
		_draw_label(font, IsoMath.tile_center(hover.x, hover.y) + Vector2(0, -height - 30), "$%d" % BuildingDefs.tool_cost(tool))
	else:
		var d := IsoMath.diamond(hover.x, hover.y)
		draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), HOVER, 2.0)
		if BuildingDefs.tool_is_area(tool) or BuildingDefs.tool_is_line(tool):
			var ok := tools.can_apply_at(tool, hover.x, hover.y)
			draw_colored_polygon(d, OK_FILL if ok else BAD_FILL)


func _draw_iso_ellipse(c: Vector2, radius_tiles: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in range(49):
		var a := float(k) / 48.0 * TAU
		pts.append(c + Vector2(cos(a) * radius_tiles * IsoMath.HW, sin(a) * radius_tiles * IsoMath.HH))
	draw_polyline(pts, col, 1.5)


func _draw_label(font: Font, pos: Vector2, text: String) -> void:
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	var rect := Rect2(pos - Vector2(size.x * 0.5 + 6, size.y), size + Vector2(12, 6))
	draw_rect(rect, Color(0, 0, 0, 0.7))
	draw_string(font, pos + Vector2(-size.x * 0.5, -3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
