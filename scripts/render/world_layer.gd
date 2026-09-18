class_name WorldLayer
extends ChunkedLayer
## Draws everything the player builds: zones, roads, developed lots, civic buildings,
## rubble, fires and the small warning icons for missing services.

const ROAD := Color(0.30, 0.30, 0.33)
const ROAD_LINE := Color(0.85, 0.80, 0.45)
const RUBBLE := Color(0.42, 0.37, 0.32)
const FLAME_A := Color(1.0, 0.55, 0.05)
const FLAME_B := Color(1.0, 0.85, 0.20)

const RES_COLORS := [Color(0, 0, 0), Color(0.78, 0.66, 0.50), Color(0.88, 0.80, 0.66), Color(0.93, 0.92, 0.88)]
const COM_COLORS := [Color(0, 0, 0), Color(0.55, 0.62, 0.72), Color(0.45, 0.60, 0.80), Color(0.60, 0.78, 0.92)]
const IND_COLORS := [Color(0, 0, 0), Color(0.60, 0.50, 0.35), Color(0.68, 0.62, 0.45), Color(0.70, 0.70, 0.60)]


func draw_chunk(chunk: Node2D, rect: Rect2i) -> void:
	for_each_tile_painter_order(rect, func(x: int, y: int) -> void:
		_draw_tile(chunk, x, y))


func _draw_tile(ci: CanvasItem, x: int, y: int) -> void:
	var i := grid.idx(x, y)
	var b := grid.building[i]
	if b == Constants.Building.ROAD:
		_draw_road(ci, x, y, i)
	elif b == Constants.Building.RUBBLE:
		_draw_rubble(ci, x, y, i)
	elif b != Constants.Building.NONE:
		_draw_civic(ci, x, y, i)
	elif grid.zone_type[i] != Constants.Zone.NONE:
		_draw_zone(ci, x, y, i)
	if grid.burning[i] > 0:
		_draw_fire(ci, x, y, i)


func _draw_road(ci: CanvasItem, x: int, y: int, i: int) -> void:
	var d := IsoMath.diamond(x, y)
	ci.draw_colored_polygon(d, ROAD)
	var c := IsoMath.tile_center(x, y)
	var hw := IsoMath.HW
	var hh := IsoMath.HH
	var ends: Array[Vector2] = []
	if y > 0 and grid.is_road(i - grid.width):
		ends.append(Vector2(c.x + hw * 0.5, c.y - hh * 0.5))
	if x < grid.width - 1 and grid.is_road(i + 1):
		ends.append(Vector2(c.x + hw * 0.5, c.y + hh * 0.5))
	if y < grid.height - 1 and grid.is_road(i + grid.width):
		ends.append(Vector2(c.x - hw * 0.5, c.y + hh * 0.5))
	if x > 0 and grid.is_road(i - 1):
		ends.append(Vector2(c.x - hw * 0.5, c.y - hh * 0.5))
	var busy := clampf(grid.traffic[i] / 100.0, 0.0, 1.0)
	var line := ROAD_LINE.lerp(Color(0.95, 0.35, 0.25), busy)
	if ends.is_empty():
		ci.draw_circle(c, 3.0, line)
	for e in ends:
		ci.draw_line(c, e, line, 1.5)
	# Kerb.
	ci.draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), Color(0.18, 0.18, 0.20, 0.9), 1.0)


func _draw_rubble(ci: CanvasItem, x: int, y: int, i: int) -> void:
	var d := IsoMath.diamond(x, y)
	ci.draw_colored_polygon(d, RUBBLE)
	var c := IsoMath.tile_center(x, y)
	var h := (i * 40503) & 0xFFFF
	for k in range(4):
		var o := Vector2(float((h >> (k * 3)) % 24) - 12.0, float((h >> (k * 2 + 1)) % 10) - 5.0)
		ci.draw_rect(Rect2(c + o, Vector2(4, 3)), RUBBLE.darkened(0.35))


func _draw_zone(ci: CanvasItem, x: int, y: int, i: int) -> void:
	var z := grid.zone_type[i]
	var zc: Color = Constants.ZONE_COLORS[z]
	var lvl := grid.level[i]
	var d := IsoMath.diamond(x, y)
	if lvl == 0:
		var fill := zc
		fill.a = 0.30
		ci.draw_colored_polygon(d, fill)
		var edge := zc
		edge.a = 0.85
		ci.draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), edge, 1.0)
		# Density ticks in the tile centre.
		var c := IsoMath.tile_center(x, y)
		for k in range(grid.zone_density[i]):
			ci.draw_rect(Rect2(c + Vector2(-6.0 + float(k) * 5.0, -1.5), Vector2(3, 3)), edge)
		_draw_warnings(ci, x, y, i, 0.0)
		return

	# Lot surface (pavement/yard) then the building box.
	var lot := zc.darkened(0.55)
	lot.a = 0.9
	ci.draw_colored_polygon(d, lot)
	var density := grid.zone_density[i]
	var wealth := clampi(grid.wealth[i], 1, 3)
	var color: Color
	var height := 0.0
	var inset := 0.16
	match z:
		Constants.Zone.RES:
			color = RES_COLORS[wealth]
			height = [0.0, 8.0 + lvl * 4.0, 12.0 + lvl * 10.0, 22.0 + lvl * 18.0][density]
			if density == 1:
				inset = 0.24
		Constants.Zone.COM:
			color = COM_COLORS[wealth]
			height = [0.0, 10.0 + lvl * 5.0, 16.0 + lvl * 14.0, 28.0 + lvl * 26.0][density]
		Constants.Zone.IND:
			color = IND_COLORS[wealth]
			height = [0.0, 6.0 + lvl * 3.0, 10.0 + lvl * 6.0, 14.0 + lvl * 10.0][density]
			inset = 0.10
	var base := IsoMath.diamond(x, y, 1, inset)
	IsoMath.draw_box(ci, base, height, color)
	_draw_details(ci, z, base, height, density, lvl, i)
	_draw_warnings(ci, x, y, i, height)


func _draw_details(ci: CanvasItem, z: int, base: PackedVector2Array, height: float, density: int, lvl: int, i: int) -> void:
	match z:
		Constants.Zone.RES:
			if density == 1:
				# Pitched roof: a darker triangle on the top face.
				var up := Vector2(0, -height)
				var roof_col := Color(0.55, 0.28, 0.22) if (i % 3) != 0 else Color(0.30, 0.35, 0.45)
				var mid := (base[0] + base[2]) * 0.5 + up + Vector2(0, -5)
				ci.draw_colored_polygon(PackedVector2Array([base[0] + up, base[1] + up, mid]), roof_col)
				ci.draw_colored_polygon(PackedVector2Array([base[1] + up, base[2] + up, mid]), roof_col.darkened(0.25))
				ci.draw_colored_polygon(PackedVector2Array([base[2] + up, base[3] + up, mid]), roof_col.darkened(0.4))
				ci.draw_colored_polygon(PackedVector2Array([base[3] + up, base[0] + up, mid]), roof_col.darkened(0.15))
			elif height > 20.0:
				_draw_windows(ci, base, height, Color(0.25, 0.25, 0.30, 0.55))
		Constants.Zone.COM:
			if height > 18.0:
				_draw_windows(ci, base, height, Color(0.85, 0.95, 1.0, 0.45))
		Constants.Zone.IND:
			if lvl >= 2:
				# Smokestack.
				var top := (base[0] + base[1]) * 0.5 + Vector2(0, -height)
				ci.draw_rect(Rect2(top + Vector2(-2, -14), Vector2(4, 14)), Color(0.35, 0.33, 0.32))
				ci.draw_circle(top + Vector2(0, -17), 3.0, Color(0.7, 0.7, 0.7, 0.5))


func _draw_windows(ci: CanvasItem, base: PackedVector2Array, height: float, col: Color) -> void:
	var rows := int(height / 8.0)
	for r in range(1, rows):
		var yoff := -float(r) * 8.0 + 2.0
		# Left face: between base[3] (left) and base[2] (bottom).
		for k in range(1, 3):
			var t := float(k) / 3.0
			var p := base[3].lerp(base[2], t) + Vector2(0, yoff)
			ci.draw_rect(Rect2(p + Vector2(-1.5, -3), Vector2(3, 4)), col)
			var q := base[2].lerp(base[1], t) + Vector2(0, yoff)
			ci.draw_rect(Rect2(q + Vector2(-1.5, -3), Vector2(3, 4)), col)


func _draw_civic(ci: CanvasItem, x: int, y: int, i: int) -> void:
	var origin := grid.owner[i]
	if origin < 0:
		origin = i
	var type := grid.building[origin]
	var def := BuildingDefs.get_def(type)
	var fsize := int(def.get("size", 1))
	var ox := grid.x_of(origin)
	var oy := grid.y_of(origin)
	# Draw the whole footprint once, when the painter reaches its front-most tile.
	if x != ox + fsize - 1 or y != oy + fsize - 1:
		return
	var color: Color = def.get("color", Color.GRAY)
	var height := float(def.get("height", 10))
	var lot := IsoMath.diamond(ox, oy, fsize)
	ci.draw_colored_polygon(lot, Color(0.55, 0.55, 0.55))
	match type:
		Constants.Building.PARK:
			ci.draw_colored_polygon(lot, Color(0.30, 0.62, 0.28))
			var c := IsoMath.tile_center(ox, oy)
			for k in range(3):
				var o := Vector2([-10.0, 8.0, 0.0][k], [0.0, -4.0, 5.0][k])
				ci.draw_colored_polygon(PackedVector2Array([c + o + Vector2(0, -14), c + o + Vector2(5, 0), c + o + Vector2(-5, 0)]), Color(0.15, 0.42, 0.18))
			ci.draw_circle(c + Vector2(0, 2), 3.0, Color(0.45, 0.65, 0.95))
		Constants.Building.POWER_WIND:
			var base := IsoMath.diamond(ox, oy, 1, 0.38)
			IsoMath.draw_box(ci, base, height, color)
			var top := (base[0] + base[2]) * 0.5 + Vector2(0, -height)
			for k in range(3):
				var ang := float(k) * TAU / 3.0
				ci.draw_line(top, top + Vector2(cos(ang), sin(ang)) * 14.0, Color(0.95, 0.95, 0.97), 2.0)
		Constants.Building.WATER_TOWER:
			var base := IsoMath.diamond(ox, oy, 1, 0.3)
			IsoMath.draw_box(ci, base, height * 0.5, color.darkened(0.3))
			var tank := IsoMath.diamond(ox, oy, 1, 0.18)
			for k in range(4):
				tank[k] += Vector2(0, -height * 0.5)
			IsoMath.draw_box(ci, tank, height * 0.5, color)
		Constants.Building.POWER_COAL:
			var base := IsoMath.diamond(ox, oy, fsize, 0.15)
			IsoMath.draw_box(ci, base, height * 0.6, color)
			var stack := (base[0] + base[3]) * 0.5 + Vector2(0, -height * 0.6)
			ci.draw_rect(Rect2(stack + Vector2(-4, -height * 0.7), Vector2(8, height * 0.7)), Color(0.5, 0.48, 0.47))
			ci.draw_circle(stack + Vector2(0, -height * 0.7 - 6), 6.0, Color(0.6, 0.6, 0.6, 0.55))
			ci.draw_circle(stack + Vector2(4, -height * 0.7 - 14), 8.0, Color(0.6, 0.6, 0.6, 0.35))
		Constants.Building.POWER_NUCLEAR:
			var base := IsoMath.diamond(ox, oy, fsize, 0.15)
			IsoMath.draw_box(ci, base, height * 0.4, color)
			var c := (base[0] + base[2]) * 0.5 + Vector2(0, -height * 0.4)
			ci.draw_circle(c + Vector2(0, -12), 22.0, color.lightened(0.1))
			ci.draw_circle(c + Vector2(0, -12), 22.0, color.darkened(0.5), false, 1.5)
		_:
			var base := IsoMath.diamond(ox, oy, fsize, 0.12)
			IsoMath.draw_box(ci, base, height, color)
			# Roof marker so services are recognisable at a glance.
			var c := (base[0] + base[2]) * 0.5 + Vector2(0, -height)
			match type:
				Constants.Building.HOSPITAL:
					ci.draw_rect(Rect2(c + Vector2(-9, -3), Vector2(18, 6)), Color(0.9, 0.2, 0.2))
					ci.draw_rect(Rect2(c + Vector2(-3, -9), Vector2(6, 18)), Color(0.9, 0.2, 0.2))
				Constants.Building.POLICE:
					ci.draw_circle(c, 6.0, Color(0.95, 0.85, 0.3))
				Constants.Building.FIRE_STATION:
					ci.draw_rect(Rect2(c + Vector2(-8, -4), Vector2(16, 8)), Color(1.0, 0.9, 0.8))
				Constants.Building.SCHOOL:
					ci.draw_line(c + Vector2(0, 2), c + Vector2(0, -16), Color(0.9, 0.9, 0.9), 2.0)
					ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -16), c + Vector2(10, -13), c + Vector2(0, -10)]), Color(0.9, 0.2, 0.2))
	# Warning icons for services lacking power.
	if def.get("power_use", 0) > 0 and grid.powered[origin] == 0:
		_draw_no_power_icon(ci, IsoMath.tile_center(ox, oy) + Vector2(0, -height - 14))
	if grid.burning[origin] > 0:
		_draw_fire(ci, ox, oy, origin)


func _draw_warnings(ci: CanvasItem, x: int, y: int, i: int, height: float) -> void:
	var c := IsoMath.tile_center(x, y) + Vector2(0, -height - 12)
	var shown := 0
	if grid.road_access[i] == 0:
		_draw_no_road_icon(ci, c + Vector2(float(shown) * 12.0, 0))
		shown += 1
	if grid.powered[i] == 0 and grid.level[i] > 0:
		_draw_no_power_icon(ci, c + Vector2(float(shown) * 12.0, 0))
		shown += 1
	if grid.watered[i] == 0 and grid.level[i] > 0:
		_draw_no_water_icon(ci, c + Vector2(float(shown) * 12.0, 0))


func _draw_no_power_icon(ci: CanvasItem, p: Vector2) -> void:
	ci.draw_circle(p, 6.0, Color(0.1, 0.1, 0.1, 0.7))
	ci.draw_polyline(PackedVector2Array([p + Vector2(1, -5), p + Vector2(-2, 0), p + Vector2(1, 0), p + Vector2(-1, 5)]), Color(1.0, 0.9, 0.2), 1.5)


func _draw_no_water_icon(ci: CanvasItem, p: Vector2) -> void:
	ci.draw_circle(p, 6.0, Color(0.1, 0.1, 0.1, 0.7))
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(3.5, 2), p + Vector2(0, 4.5), p + Vector2(-3.5, 2)]), Color(0.3, 0.7, 1.0))


func _draw_no_road_icon(ci: CanvasItem, p: Vector2) -> void:
	ci.draw_circle(p, 6.0, Color(0.1, 0.1, 0.1, 0.7))
	ci.draw_circle(p, 4.5, Color(0.95, 0.3, 0.3), false, 1.5)
	ci.draw_line(p + Vector2(-3, 3), p + Vector2(3, -3), Color(0.95, 0.3, 0.3), 1.5)


func _draw_fire(ci: CanvasItem, x: int, y: int, i: int) -> void:
	var c := IsoMath.tile_center(x, y)
	var h := (i * 7919 + grid.burning[i] * 131) & 0xFFFF
	for k in range(3):
		var o := Vector2(float((h >> (k * 4)) % 20) - 10.0, float((h >> (k * 2)) % 6) - 3.0)
		var size := 10.0 + float((h >> k) % 8)
		var base := c + o
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-6, 0), base + Vector2(6, 0), base + Vector2(1, -size * 1.6)]), FLAME_A)
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-3, 0), base + Vector2(3, 0), base + Vector2(0, -size)]), FLAME_B)
	var smoke := Color(0.2, 0.2, 0.2, 0.45)
	ci.draw_circle(c + Vector2(4, -26), 7.0, smoke)
	ci.draw_circle(c + Vector2(-3, -34), 9.0, smoke)
