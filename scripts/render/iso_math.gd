class_name IsoMath
extends RefCounted
## Conversions between tile coordinates and isometric screen space.

const HW := Constants.TILE_W / 2.0
const HH := Constants.TILE_H / 2.0


## Screen position of the top corner of tile (x, y).
static func tile_to_screen(x: float, y: float) -> Vector2:
	return Vector2((x - y) * HW, (x + y) * HH)


## Screen position of the centre of tile (x, y).
static func tile_center(x: int, y: int) -> Vector2:
	return Vector2((x - y) * HW, (x + y) * HH + HH)


## Tile containing a world-space point (may be out of bounds).
static func screen_to_tile(p: Vector2) -> Vector2i:
	var a := p.x / HW
	var b := p.y / HH
	return Vector2i(int(floor((a + b) * 0.5)), int(floor((b - a) * 0.5)))


## Diamond outline of a footprint from tile (x, y) with side `fsize`, shrunk by `inset`
## (0..0.5, fraction of a tile) toward its centre.
static func diamond(x: int, y: int, fsize: int = 1, inset: float = 0.0) -> PackedVector2Array:
	var u0 := float(x) + inset
	var v0 := float(y) + inset
	var u1 := float(x + fsize) - inset
	var v1 := float(y + fsize) - inset
	return PackedVector2Array([
		tile_to_screen(u0, v0), # top
		tile_to_screen(u1, v0), # right
		tile_to_screen(u1, v1), # bottom
		tile_to_screen(u0, v1), # left
	])


## Draws an extruded isometric box on `ci`. `base` is a diamond (top, right, bottom, left).
static func draw_box(ci: CanvasItem, base: PackedVector2Array, height: float, color: Color, outline: bool = true) -> void:
	var up := Vector2(0, -height)
	var top := PackedVector2Array([base[0] + up, base[1] + up, base[2] + up, base[3] + up])
	if height > 0.0:
		var left := PackedVector2Array([base[3], base[2], base[2] + up, base[3] + up])
		var right := PackedVector2Array([base[2], base[1], base[1] + up, base[2] + up])
		ci.draw_colored_polygon(left, color.darkened(0.30))
		ci.draw_colored_polygon(right, color.darkened(0.48))
	ci.draw_colored_polygon(top, color)
	if outline:
		var edge := color.darkened(0.6)
		edge.a = 0.8
		ci.draw_polyline(PackedVector2Array([top[0], top[1], top[2], top[3], top[0]]), edge, 1.0)
		if height > 0.0:
			ci.draw_line(base[3], base[3] + up, edge, 1.0)
			ci.draw_line(base[2], base[2] + up, edge, 1.0)
			ci.draw_line(base[1], base[1] + up, edge, 1.0)
			ci.draw_line(base[3], base[2], edge, 1.0)
			ci.draw_line(base[2], base[1], edge, 1.0)


## Colour ramp helper for overlays: t in 0..1 from `a` to `b`.
static func ramp(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, clampf(t, 0.0, 1.0))
