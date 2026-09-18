class_name TerrainGenerator
extends RefCounted
## Procedural terrain: rolling elevation with lakes, a coast on one edge, forests and beaches.


static func generate(grid: CityGrid, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var elev_noise := FastNoiseLite.new()
	elev_noise.seed = seed_value
	elev_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	elev_noise.frequency = 0.045
	elev_noise.fractal_octaves = 4
	elev_noise.fractal_lacunarity = 2.0
	elev_noise.fractal_gain = 0.5

	var forest_noise := FastNoiseLite.new()
	forest_noise.seed = seed_value + 7919
	forest_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	forest_noise.frequency = 0.09
	forest_noise.fractal_octaves = 3

	# Choose one edge to be a coast so most cities have a shoreline.
	var coast_edge := rng.randi_range(0, 3)
	var coast_depth := 0.14

	for y in range(grid.height):
		for x in range(grid.width):
			var i := grid.idx(x, y)
			var n := elev_noise.get_noise_2d(float(x), float(y)) # -1..1
			var e := 0.5 + 0.5 * n
			# Coastal falloff toward the chosen edge.
			var t := 0.0
			match coast_edge:
				0: t = float(x) / float(grid.width)
				1: t = 1.0 - float(x) / float(grid.width)
				2: t = float(y) / float(grid.height)
				3: t = 1.0 - float(y) / float(grid.height)
			if t < coast_depth * 2.0:
				var f := clampf(t / (coast_depth * 2.0), 0.0, 1.0)
				e = lerpf(0.15, e, smoothstep(0.0, 1.0, f))
			grid.elevation[i] = clampf(e, 0.0, 1.0)

	for i in range(grid.size):
		var e := grid.elevation[i]
		var x := grid.x_of(i)
		var y := grid.y_of(i)
		if e < 0.34:
			grid.terrain[i] = Constants.Terrain.WATER
		elif e < 0.385:
			grid.terrain[i] = Constants.Terrain.SAND
		else:
			var fn := forest_noise.get_noise_2d(float(x), float(y))
			if fn > 0.22 and e > 0.42:
				grid.terrain[i] = Constants.Terrain.FOREST
			else:
				grid.terrain[i] = Constants.Terrain.GRASS

	# Remove isolated single water tiles that look like noise.
	for i in range(grid.size):
		if grid.terrain[i] == Constants.Terrain.WATER:
			var water_neighbors := 0
			for n in grid.neighbors4(i):
				if grid.terrain[n] == Constants.Terrain.WATER:
					water_neighbors += 1
			if water_neighbors == 0:
				grid.terrain[i] = Constants.Terrain.SAND
				grid.elevation[i] = 0.36


## Finds a reasonable starting camera focus: the land tile nearest the map centre.
static func find_start_tile(grid: CityGrid) -> Vector2i:
	var cx := grid.width / 2
	var cy := grid.height / 2
	for r in range(0, max(grid.width, grid.height)):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var x := cx + dx
				var y := cy + dy
				if grid.in_bounds(x, y) and grid.is_land(grid.idx(x, y)):
					return Vector2i(x, y)
	return Vector2i(cx, cy)
