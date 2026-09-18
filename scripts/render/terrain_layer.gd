class_name TerrainLayer
extends ChunkedLayer
## Draws water, grass, sand and forest sprites.


func draw_chunk(chunk: Node2D, rect: Rect2i) -> void:
	for_each_tile_painter_order(rect, func(x: int, y: int) -> void:
		_draw_tile(chunk, x, y))


func _draw_tile(ci: CanvasItem, x: int, y: int) -> void:
	var i := grid.idx(x, y)
	var h := (i * 2654435761) & 0xFFFF
	var e := grid.elevation[i]
	match grid.terrain[i]:
		Constants.Terrain.WATER:
			var depth := clampf(e / 0.34, 0.0, 1.0)
			var tint := Color(0.75, 0.8, 0.9).lerp(Color.WHITE, depth)
			Sprites.draw(ci, "terrain_water_%d" % (h % 2), x, y, 1, tint)
		Constants.Terrain.SAND:
			Sprites.draw(ci, "terrain_sand", x, y)
		Constants.Terrain.GRASS:
			var t := clampf((e - 0.38) / 0.62, 0.0, 1.0)
			var tint := Color(0.82, 0.86, 0.78).lerp(Color(1.05, 1.05, 1.0), t)
			Sprites.draw(ci, "terrain_grass_%d" % (h % 3), x, y, 1, tint)
		Constants.Terrain.FOREST:
			Sprites.draw(ci, "terrain_forest_%d" % (h % 2), x, y)
