class_name ChunkedLayer
extends Node2D
## Splits the map into chunks that are redrawn independently. Chunks are ordered row-major
## and each chunk draws its tiles in isometric painter order, which keeps overlapping
## buildings correct across chunk borders.

var grid: CityGrid = null
var chunks: Array = []
var chunks_x := 0
var chunks_y := 0
## Number of chunk draws performed since setup (useful for tests and profiling).
var draw_count := 0


class LayerChunk:
	extends Node2D
	var layer: ChunkedLayer
	var rect: Rect2i

	func _draw() -> void:
		if layer != null and layer.grid != null:
			layer.draw_count += 1
			layer.draw_chunk(self, rect)


func setup(g: CityGrid) -> void:
	for c in chunks:
		c.queue_free()
	chunks.clear()
	grid = g
	draw_count = 0
	var cs := Constants.CHUNK_SIZE
	chunks_x = int(ceil(float(grid.width) / float(cs)))
	chunks_y = int(ceil(float(grid.height) / float(cs)))
	for cy in range(chunks_y):
		for cx in range(chunks_x):
			var chunk := LayerChunk.new()
			chunk.layer = self
			chunk.rect = Rect2i(cx * cs, cy * cs, mini(cs, grid.width - cx * cs), mini(cs, grid.height - cy * cs))
			add_child(chunk)
			chunks.append(chunk)


func mark_tile_dirty(i: int) -> void:
	if grid == null:
		return
	var cs := Constants.CHUNK_SIZE
	var cx := grid.x_of(i) / cs
	var cy := grid.y_of(i) / cs
	var ci := cy * chunks_x + cx
	if ci >= 0 and ci < chunks.size():
		chunks[ci].queue_redraw()
	# Tall buildings and multi-tile footprints can spill into the chunk above-left.
	if cx > 0:
		chunks[ci - 1].queue_redraw()
	if cy > 0:
		chunks[ci - chunks_x].queue_redraw()
	if cx > 0 and cy > 0:
		chunks[ci - chunks_x - 1].queue_redraw()


func mark_tiles_dirty(indices: PackedInt32Array) -> void:
	for i in indices:
		mark_tile_dirty(i)


func mark_all_dirty() -> void:
	for c in chunks:
		c.queue_redraw()


## Calls `fn(x, y)` for every tile in `rect` in back-to-front isometric order.
func for_each_tile_painter_order(rect: Rect2i, fn: Callable) -> void:
	var rw := rect.size.x
	var rh := rect.size.y
	for s in range(0, rw + rh - 1):
		var lx_start := maxi(0, s - (rh - 1))
		var lx_end := mini(rw - 1, s)
		for lx in range(lx_start, lx_end + 1):
			var ly := s - lx
			fn.call(rect.position.x + lx, rect.position.y + ly)


## Override in subclasses.
func draw_chunk(_chunk: Node2D, _rect: Rect2i) -> void:
	pass
