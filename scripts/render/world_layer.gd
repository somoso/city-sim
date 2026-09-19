class_name WorldLayer
extends ChunkedLayer
## Draws everything the player builds using the generated sprites: zone lots, roads,
## developed buildings, civic buildings, rubble and fire.
##
## Warnings about missing road access, power or water are drawn by AlertsLayer instead,
## because they flash and this layer only redraws chunks that changed.


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
	if lvl == 0:
		Sprites.draw(ci, Sprites.lot_sprite(z, grid.zone_density[i]), x, y)
	else:
		Sprites.draw(ci, Sprites.zone_sprite(z, grid.zone_density[i], lvl, grid.wealth[i]), x, y)


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
	Sprites.draw(ci, Sprites.civic_sprite(type), ox, oy, fsize)
	if grid.burning[origin] > 0:
		_draw_fire(ci, ox, oy, origin, fsize)


func _draw_fire(ci: CanvasItem, x: int, y: int, i: int, fsize: int = 1) -> void:
	var frame := (grid.burning[i] + i) % 2
	# Flames sit on the centre tile of the footprint.
	var cx := x + (fsize - 1) / 2
	var cy := y + (fsize - 1) / 2
	Sprites.draw(ci, "fire_%d" % frame, cx, cy)
	var c := IsoMath.tile_center(cx, cy)
	Sprites.draw_centered(ci, "smoke", c + Vector2(10.0, -80.0))
