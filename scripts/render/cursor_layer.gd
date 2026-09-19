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
## Tiles the game will turn into service road as part of a zone drag.
const ROAD_FILL := Color(0.22, 0.22, 0.26, 0.85)
const ROAD_EDGE := Color(0.90, 0.82, 0.40, 0.9)
const HOVER := Color(1, 1, 1, 0.9)
const FONT_SIZE := 18


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


## Inverse camera zoom, so labels keep a constant on-screen size.
func _ui_scale() -> float:
	var cam := get_viewport().get_camera_2d()
	if cam == null or cam.zoom.x <= 0.0:
		return 1.0
	return 1.0 / cam.zoom.x


func _draw() -> void:
	draw_count += 1
	if grid == null or not grid.in_bounds(hover.x, hover.y):
		return
	var tool := GameState.current_tool
	var font := ThemeDB.fallback_font
	var d_hover := IsoMath.diamond(hover.x, hover.y)
	var outline_w := 2.0 * _ui_scale()
	if dragging and BuildingDefs.tool_is_area(tool):
		var x0 := mini(drag_start.x, hover.x)
		var x1 := maxi(drag_start.x, hover.x)
		var y0 := mini(drag_start.y, hover.y)
		var y1 := maxi(drag_start.y, hover.y)
		# Zone drags also show the service roads that will be laid to reach the lots.
		var planned_roads := {}
		var planned_lots := {}
		if BuildingDefs.tool_is_zone(tool):
			var plan := tools.plan_zone_roads(tool, x0, y0, x1, y1)
			for i in plan["roads"]:
				planned_roads[i] = true
			for i in plan["lots"]:
				planned_lots[i] = true
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var i := grid.idx(x, y)
				var d := IsoMath.diamond(x, y)
				if planned_roads.has(i):
					draw_colored_polygon(d, ROAD_FILL)
					draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), ROAD_EDGE, outline_w)
					continue
				var ok := planned_lots.has(i) if BuildingDefs.tool_is_zone(tool) else tools.can_apply_at(tool, x, y)
				draw_colored_polygon(d, OK_FILL if ok else BAD_FILL)
		var cost := tools.area_cost(tool, x0, y0, x1, y1)
		var text := "$%d  (%dx%d)" % [cost, x1 - x0 + 1, y1 - y0 + 1]
		if not planned_roads.is_empty():
			text += "\n%d lots + %d road tiles" % [planned_lots.size(), planned_roads.size()]
		_draw_label(font, IsoMath.tile_center(hover.x, hover.y) + Vector2(0, -40), text)
	elif dragging and BuildingDefs.tool_is_line(tool):
		for p in tools.line_tiles(drag_start.x, drag_start.y, hover.x, hover.y):
			if not grid.in_bounds(p.x, p.y):
				continue
			var ok := tools.can_apply_at(tool, p.x, p.y)
			draw_colored_polygon(IsoMath.diamond(p.x, p.y), OK_FILL if ok else BAD_FILL)
		var cost := tools.line_cost(tool, drag_start.x, drag_start.y, hover.x, hover.y)
		_draw_label(font, IsoMath.tile_center(hover.x, hover.y) + Vector2(0, -40), "$%d" % cost)
	elif BuildingDefs.tool_is_building(tool):
		var type: int = BuildingDefs.TOOL_BUILDING[tool]
		var fsize := int(BuildingDefs.def_value(type, "size", 1))
		var ok := tools.can_apply_at(tool, hover.x, hover.y)
		var fill := OK_FILL if ok else BAD_FILL
		for dy in range(fsize):
			for dx in range(fsize):
				if grid.in_bounds(hover.x + dx, hover.y + dy):
					draw_colored_polygon(IsoMath.diamond(hover.x + dx, hover.y + dy), fill)
		var ghost_rect := Sprites.draw(self, Sprites.civic_sprite(type), hover.x, hover.y, fsize,
			Color(1, 1, 1, 0.6) if ok else Color(1, 0.5, 0.5, 0.5))
		var label_y := ghost_rect.position.y - 8.0 if ghost_rect.size.y > 0.0 else IsoMath.tile_center(hover.x, hover.y).y - 60.0
		if BuildingDefs.def_value(type, "coverage", "") != "":
			var r := float(BuildingDefs.def_value(type, "radius", 0))
			var c := IsoMath.tile_center(hover.x, hover.y)
			c += IsoMath.tile_to_screen(float(fsize - 1) * 0.5, float(fsize - 1) * 0.5)
			_draw_iso_ellipse(c, r, Color(1, 1, 1, 0.6))
		_draw_label(font, Vector2(IsoMath.tile_center(hover.x, hover.y).x + IsoMath.HW * (fsize - 1), label_y), "$%d" % BuildingDefs.tool_cost(tool))
	else:
		draw_polyline(PackedVector2Array([d_hover[0], d_hover[1], d_hover[2], d_hover[3], d_hover[0]]), HOVER, outline_w)
		if BuildingDefs.tool_is_area(tool) or BuildingDefs.tool_is_line(tool):
			var ok := tools.can_apply_at(tool, hover.x, hover.y)
			draw_colored_polygon(d_hover, OK_FILL if ok else BAD_FILL)


func _draw_iso_ellipse(c: Vector2, radius_tiles: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in range(49):
		var a := float(k) / 48.0 * TAU
		pts.append(c + Vector2(cos(a) * radius_tiles * IsoMath.HW, sin(a) * radius_tiles * IsoMath.HH))
	draw_polyline(pts, col, 1.5)


func _draw_label(font: Font, pos: Vector2, text: String) -> void:
	var k_scale := _ui_scale()
	var font_size := int(round(FONT_SIZE * k_scale))
	var lines := text.split("\n")
	var line_h := font.get_height(font_size) + 2.0 * k_scale
	var width := 0.0
	for l in lines:
		width = maxf(width, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var total_h := line_h * lines.size()
	var pad := 8.0 * k_scale
	var rect := Rect2(pos - Vector2(width * 0.5 + pad, total_h + pad * 0.5), Vector2(width + pad * 2, total_h + pad))
	draw_rect(rect, Color(0, 0, 0, 0.72))
	for k in range(lines.size()):
		var y := rect.position.y + pad * 0.5 + line_h * (k + 1) - 5.0 * k_scale
		draw_string(font, Vector2(pos.x - width * 0.5, y), lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
