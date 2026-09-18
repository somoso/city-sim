class_name OverlayLayer
extends ChunkedLayer
## Translucent data views (power, water, land value, pollution, ...) drawn over the world.

var overlay: int = Constants.Overlay.NONE


func set_overlay(o: int) -> void:
	overlay = o
	visible = o != Constants.Overlay.NONE
	mark_all_dirty()


const PIPE_OK := Color(0.25, 0.65, 1.0, 0.95)
const PIPE_DRY := Color(0.95, 0.30, 0.25, 0.95)
const WIRE_OK := Color(1.0, 0.85, 0.2, 0.95)
const WIRE_DEAD := Color(0.95, 0.30, 0.25, 0.95)


func draw_chunk(chunk: Node2D, rect: Rect2i) -> void:
	if overlay == Constants.Overlay.NONE:
		return
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var i := grid.idx(x, y)
			var col := _color_for(i)
			if col.a > 0.01:
				chunk.draw_colored_polygon(IsoMath.diamond(x, y), col)
	if overlay == Constants.Overlay.WATER:
		_draw_network(chunk, rect, grid.watered, PIPE_OK, PIPE_DRY, "water_out")
	elif overlay == Constants.Overlay.POWER:
		_draw_network(chunk, rect, grid.powered, WIRE_OK, WIRE_DEAD, "power_out")


## Draws the utility network carried under roads: a pipe/wire from each road tile's centre
## toward every neighbouring tile that conducts, coloured by whether the road tile is served.
## Source buildings get a pulsing ring so players can see where supply comes from.
func _draw_network(ci: CanvasItem, rect: Rect2i, served: PackedInt32Array, ok: Color, bad: Color, out_key: String) -> void:
	var hw := IsoMath.HW
	var hh := IsoMath.HH
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var i := grid.idx(x, y)
			if not grid.is_road(i):
				continue
			var c := IsoMath.tile_center(x, y)
			var col := ok if served[i] == 1 else bad
			var ends: Array[Vector2] = []
			if y > 0 and grid.conducts(i - grid.width):
				ends.append(Vector2(c.x + hw * 0.5, c.y - hh * 0.5))
			if x < grid.width - 1 and grid.conducts(i + 1):
				ends.append(Vector2(c.x + hw * 0.5, c.y + hh * 0.5))
			if y < grid.height - 1 and grid.conducts(i + grid.width):
				ends.append(Vector2(c.x - hw * 0.5, c.y + hh * 0.5))
			if x > 0 and grid.conducts(i - 1):
				ends.append(Vector2(c.x - hw * 0.5, c.y - hh * 0.5))
			for e in ends:
				ci.draw_line(c, e, Color(0, 0, 0, 0.5), 10.0)
				ci.draw_line(c, e, col, 6.0)
			ci.draw_circle(c, 6.0, col)
			ci.draw_circle(c, 6.0, Color(0, 0, 0, 0.6), false, 1.5)
	# Source rings.
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var i := grid.idx(x, y)
			if not grid.has_civic(i) or grid.owner[i] != i:
				continue
			if float(BuildingDefs.def_value(grid.building[i], out_key, 0)) <= 0.0:
				continue
			var fsize := int(BuildingDefs.def_value(grid.building[i], "size", 1))
			var c := IsoMath.tile_center(x, y) + IsoMath.tile_to_screen(float(fsize - 1) * 0.5, float(fsize - 1) * 0.5)
			for k in range(3):
				var r := float(fsize) * 0.7 + float(k) * 0.35
				var pts := PackedVector2Array()
				for a in range(41):
					var t := float(a) / 40.0 * TAU
					pts.append(c + Vector2(cos(t) * r * hw, sin(t) * r * hh))
				var ring := ok
				ring.a = 0.9 - float(k) * 0.3
				ci.draw_polyline(pts, ring, 3.0)


func _color_for(i: int) -> Color:
	var none := Color(0, 0, 0, 0)
	if not grid.is_land(i) and overlay != Constants.Overlay.TRAFFIC:
		return none
	match overlay:
		Constants.Overlay.ZONES:
			var z := grid.zone_type[i]
			if z == Constants.Zone.NONE:
				return none
			var c: Color = Constants.ZONE_COLORS[z]
			c.a = 0.55
			return c
		Constants.Overlay.POWER:
			if not grid.conducts(i) or grid.is_road(i):
				return none
			return Color(1.0, 0.85, 0.2, 0.45) if grid.powered[i] == 1 else Color(0.95, 0.2, 0.2, 0.55)
		Constants.Overlay.WATER:
			if not grid.conducts(i) or grid.is_road(i):
				return none
			return Color(0.25, 0.6, 1.0, 0.45) if grid.watered[i] == 1 else Color(0.95, 0.2, 0.2, 0.55)
		Constants.Overlay.LAND_VALUE:
			var t := grid.land_value[i] / 100.0
			var c := IsoMath.ramp(Color(0.85, 0.15, 0.15), Color(0.15, 0.85, 0.25), t)
			c.a = 0.5
			return c
		Constants.Overlay.POLLUTION:
			var t := grid.pollution[i] / 100.0
			if t < 0.02:
				return none
			return Color(0.45, 0.30, 0.10, clampf(t * 0.9, 0.0, 0.85))
		Constants.Overlay.CRIME:
			var t := grid.crime[i] / 100.0
			if t < 0.02:
				return none
			return Color(0.85, 0.10, 0.25, clampf(t * 0.9, 0.0, 0.85))
		Constants.Overlay.TRAFFIC:
			if not grid.is_road(i):
				return none
			var t := grid.traffic[i] / 100.0
			var c := IsoMath.ramp(Color(0.2, 0.85, 0.3), Color(0.95, 0.15, 0.1), t)
			c.a = 0.75
			return c
		Constants.Overlay.FIRE_RISK:
			var t := grid.fire_risk[i] / 60.0
			if t < 0.02:
				return none
			var c := IsoMath.ramp(Color(1.0, 0.9, 0.2), Color(0.9, 0.1, 0.05), t)
			c.a = clampf(0.25 + t * 0.6, 0.0, 0.85)
			return c
		Constants.Overlay.POLICE:
			return _coverage_color(grid.cov_police[i], Color(0.25, 0.35, 0.95))
		Constants.Overlay.FIRE:
			return _coverage_color(grid.cov_fire[i], Color(0.95, 0.35, 0.20))
		Constants.Overlay.EDUCATION:
			return _coverage_color(grid.cov_school[i], Color(0.95, 0.65, 0.20))
		Constants.Overlay.HEALTH:
			return _coverage_color(grid.cov_health[i], Color(0.90, 0.90, 0.95))
	return none


func _coverage_color(v: float, base: Color) -> Color:
	if v <= 0.01:
		return Color(0.1, 0.1, 0.1, 0.25)
	base.a = clampf(0.2 + v * 0.55, 0.0, 0.8)
	return base
