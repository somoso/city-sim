class_name TerrainLayer
extends ChunkedLayer
## Draws water, grass, sand and forests.

const WATER_DEEP := Color(0.13, 0.32, 0.58)
const WATER_SHALLOW := Color(0.22, 0.50, 0.75)
const GRASS_LOW := Color(0.36, 0.58, 0.28)
const GRASS_HIGH := Color(0.52, 0.70, 0.36)
const SAND := Color(0.82, 0.76, 0.55)
const TREE_DARK := Color(0.12, 0.36, 0.16)
const TREE_LIGHT := Color(0.18, 0.48, 0.20)
const GRID_LINE := Color(0.0, 0.0, 0.0, 0.10)


func draw_chunk(chunk: Node2D, rect: Rect2i) -> void:
	for_each_tile_painter_order(rect, func(x: int, y: int) -> void:
		_draw_tile(chunk, x, y))


func _draw_tile(ci: CanvasItem, x: int, y: int) -> void:
	var i := grid.idx(x, y)
	var d := IsoMath.diamond(x, y)
	var e := grid.elevation[i]
	match grid.terrain[i]:
		Constants.Terrain.WATER:
			var t := clampf(e / 0.34, 0.0, 1.0)
			ci.draw_colored_polygon(d, WATER_DEEP.lerp(WATER_SHALLOW, t))
		Constants.Terrain.SAND:
			ci.draw_colored_polygon(d, SAND)
			ci.draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), GRID_LINE, 1.0)
		Constants.Terrain.GRASS:
			var t := clampf((e - 0.38) / 0.62, 0.0, 1.0)
			ci.draw_colored_polygon(d, GRASS_LOW.lerp(GRASS_HIGH, t))
			ci.draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), GRID_LINE, 1.0)
		Constants.Terrain.FOREST:
			var t := clampf((e - 0.38) / 0.62, 0.0, 1.0)
			ci.draw_colored_polygon(d, GRASS_LOW.lerp(GRASS_HIGH, t).darkened(0.12))
			_draw_trees(ci, x, y, i)


func _draw_trees(ci: CanvasItem, x: int, y: int, i: int) -> void:
	# Deterministic pseudo-random tree placement per tile.
	var h := (i * 2654435761) & 0xFFFF
	var c := IsoMath.tile_center(x, y)
	var offsets := [Vector2(-10, -2), Vector2(8, -6), Vector2(2, 4)]
	var count := 2 + (h % 2)
	for k in range(count):
		var o: Vector2 = offsets[k] + Vector2(float((h >> (k * 3)) % 5) - 2.0, float((h >> (k * 3 + 5)) % 3) - 1.0)
		var base := c + o
		var size := 7.0 + float((h >> (k * 2)) % 4)
		var col := TREE_DARK if (h >> k) % 2 == 0 else TREE_LIGHT
		ci.draw_colored_polygon(PackedVector2Array([
			base + Vector2(0, -size * 2.0),
			base + Vector2(size * 0.7, 0),
			base + Vector2(-size * 0.7, 0),
		]), col)
		ci.draw_line(base, base + Vector2(0, 3), Color(0.30, 0.20, 0.10), 2.0)
