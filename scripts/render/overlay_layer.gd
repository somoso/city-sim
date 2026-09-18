class_name OverlayLayer
extends ChunkedLayer
## Translucent data views (power, water, land value, pollution, ...) drawn over the world.

var overlay: int = Constants.Overlay.NONE


func set_overlay(o: int) -> void:
	overlay = o
	visible = o != Constants.Overlay.NONE
	mark_all_dirty()


func draw_chunk(chunk: Node2D, rect: Rect2i) -> void:
	if overlay == Constants.Overlay.NONE:
		return
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var i := grid.idx(x, y)
			var col := _color_for(i)
			if col.a <= 0.01:
				continue
			chunk.draw_colored_polygon(IsoMath.diamond(x, y), col)


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
			if not grid.conducts(i):
				return none
			return Color(0.2, 0.9, 0.3, 0.5) if grid.powered[i] == 1 else Color(0.95, 0.2, 0.2, 0.55)
		Constants.Overlay.WATER:
			if not grid.conducts(i):
				return none
			return Color(0.3, 0.6, 1.0, 0.5) if grid.watered[i] == 1 else Color(0.95, 0.2, 0.2, 0.55)
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
