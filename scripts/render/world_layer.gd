class_name WorldLayer
extends ChunkedLayer
## Draws everything the player builds using the generated sprites: zone lots, roads,
## developed buildings, civic buildings, rubble, fire, and the status icons that flag lots
## missing road access, power or water.

const ICON_SPACING := 46.0


func draw_chunk(chunk: Node2D, rect: Rect2i) -> void:
	for_each_tile_painter_order(rect, func(x: int, y: int) -> void:
		_draw_tile(chunk, x, y))


func _draw_tile(ci: CanvasItem, x: int, y: int) -> void:
	var i := grid.idx(x, y)
	var b := grid.building[i]
	if b == Constants.Building.ROAD:
		_draw_road(ci, x, y, i)
	elif b == Constants.Building.RUBBLE:
		Sprites.draw(ci, "rubble", x, y)
	elif b != Constants.Building.NONE:
		_draw_civic(ci, x, y, i)
	elif grid.zone_type[i] != Constants.Zone.NONE:
		_draw_zone(ci, x, y, i)
	if grid.burning[i] > 0 and not grid.has_civic(i):
		_draw_fire(ci, x, y, i)


func _road_mask(x: int, y: int, i: int) -> int:
	var mask := 0
	if y > 0 and grid.is_road(i - grid.width):
		mask |= 1
	if x < grid.width - 1 and grid.is_road(i + 1):
		mask |= 2
	if y < grid.height - 1 and grid.is_road(i + grid.width):
		mask |= 4
	if x > 0 and grid.is_road(i - 1):
		mask |= 8
	return mask


func _draw_road(ci: CanvasItem, x: int, y: int, i: int) -> void:
	# Heavy traffic darkens the asphalt slightly.
	var busy := clampf(grid.traffic[i] / 100.0, 0.0, 1.0)
	var tint := Color.WHITE.lerp(Color(0.8, 0.72, 0.7), busy)
	Sprites.draw(ci, "road_%02d" % _road_mask(x, y, i), x, y, 1, tint)


func _draw_zone(ci: CanvasItem, x: int, y: int, i: int) -> void:
	var z := grid.zone_type[i]
	var lvl := grid.level[i]
	var rect: Rect2
	if lvl == 0:
		rect = Sprites.draw(ci, Sprites.lot_sprite(z, grid.zone_density[i]), x, y)
	else:
		rect = Sprites.draw(ci, Sprites.zone_sprite(z, grid.zone_density[i], lvl, grid.wealth[i]), x, y)
	_draw_status_icons(ci, x, y, i, rect)


func _draw_civic(ci: CanvasItem, x: int, y: int, i: int) -> void:
	var origin := grid.owner[i]
	if origin < 0:
		origin = i
	var type := grid.building[origin]
	var fsize := int(BuildingDefs.def_value(type, "size", 1))
	var ox := grid.x_of(origin)
	var oy := grid.y_of(origin)
	# Draw the whole footprint once, when the painter reaches its front-most tile.
	if x != ox + fsize - 1 or y != oy + fsize - 1:
		return
	var rect := Sprites.draw(ci, Sprites.civic_sprite(type), ox, oy, fsize)
	if grid.burning[origin] > 0:
		_draw_fire(ci, ox, oy, origin, fsize)
	var icons: Array[String] = []
	if BuildingDefs.def_value(type, "power_use", 0) > 0 and grid.powered[origin] == 0:
		icons.append("icon_no_power")
	if BuildingDefs.def_value(type, "water_use", 0) > 0 and grid.watered[origin] == 0:
		icons.append("icon_no_water")
	if BuildingDefs.def_value(type, "needs_water", false):
		var ok := false
		for f in grid.footprint_of(origin):
			if grid.has_water_neighbor(f):
				ok = true
		if not ok:
			icons.append("icon_no_water")
	if not icons.is_empty():
		# The footprint diamond is horizontally centred on its origin tile's top corner.
		var top := IsoMath.tile_to_screen(ox, oy)
		_draw_icon_row(ci, icons, Vector2(top.x, rect.position.y + 10.0))


func _draw_status_icons(ci: CanvasItem, x: int, y: int, i: int, rect: Rect2) -> void:
	var icons: Array[String] = []
	if grid.road_access[i] == 0:
		icons.append("icon_no_road")
	if grid.level[i] > 0:
		if grid.powered[i] == 0:
			icons.append("icon_no_power")
		if grid.watered[i] == 0:
			icons.append("icon_no_water")
	if icons.is_empty():
		return
	var top := IsoMath.tile_to_screen(x, y)
	var icon_y := rect.position.y + 6.0 if rect.size.y > 0.0 else top.y - 20.0
	if grid.level[i] == 0:
		icon_y = top.y + IsoMath.HH - 14.0
	_draw_icon_row(ci, icons, Vector2(top.x, icon_y))


func _draw_icon_row(ci: CanvasItem, icons: Array[String], center: Vector2) -> void:
	var n := icons.size()
	for k in range(n):
		var offset := (float(k) - float(n - 1) * 0.5) * ICON_SPACING
		Sprites.draw_centered(ci, icons[k], center + Vector2(offset, 0.0))


func _draw_fire(ci: CanvasItem, x: int, y: int, i: int, fsize: int = 1) -> void:
	var frame := (grid.burning[i] + i) % 2
	# Flames sit on the centre tile of the footprint.
	var cx := x + (fsize - 1) / 2
	var cy := y + (fsize - 1) / 2
	Sprites.draw(ci, "fire_%d" % frame, cx, cy)
	var c := IsoMath.tile_center(cx, cy)
	Sprites.draw_centered(ci, "smoke", c + Vector2(10.0, -80.0))
