class_name FireSim
extends RefCounted
## Fire spread and suppression, plus random and manually triggered disasters.

const BURN_MONTHS := 3


static func run(grid: CityGrid, state, rng: RandomNumberGenerator) -> Array[String]:
	var news: Array[String] = []
	_advance_fires(grid, rng)
	_spread_fires(grid, rng)
	# Accidental fires are always possible; they scale with fire risk.
	for i in range(grid.size):
		if grid.burning[i] == 0 and _is_flammable(grid, i):
			if rng.randf() < grid.fire_risk[i] / 100.0 * 0.0012:
				ignite(grid, i)
				news.append("A fire has broken out at %d, %d!" % [grid.x_of(i), grid.y_of(i)])
	if state.disasters_enabled:
		var roll := rng.randf()
		if roll < 0.02:
			news.append(trigger_tornado(grid, rng))
		elif roll < 0.035:
			news.append(trigger_meteor(grid, rng))
		elif roll < 0.055:
			news.append(trigger_fire(grid, rng))
	return news


static func _is_flammable(grid: CityGrid, i: int) -> bool:
	if grid.is_developed(i):
		return true
	if grid.has_civic(i):
		return true
	if grid.terrain[i] == Constants.Terrain.FOREST and grid.building[i] == Constants.Building.NONE:
		return true
	return false


static func ignite(grid: CityGrid, i: int) -> void:
	if grid.burning[i] == 0 and _is_flammable(grid, i):
		grid.burning[i] = 1


static func _advance_fires(grid: CityGrid, rng: RandomNumberGenerator) -> void:
	for i in range(grid.size):
		if grid.burning[i] == 0:
			continue
		# Fire crews may put it out.
		if rng.randf() < grid.cov_fire[i] * 0.85:
			grid.burning[i] = 0
			continue
		grid.burning[i] += 1
		if grid.burning[i] > BURN_MONTHS:
			burn_down(grid, i)


## Destroys whatever is on tile i, leaving rubble. Zoning is preserved.
static func burn_down(grid: CityGrid, i: int) -> void:
	grid.burning[i] = 0
	if grid.has_civic(i):
		for t in grid.remove_building_at(i):
			grid.building[t] = Constants.Building.RUBBLE
			grid.burning[t] = 0
		return
	if grid.is_developed(i):
		grid.clear_development(i)
		grid.building[i] = Constants.Building.RUBBLE
		return
	if grid.terrain[i] == Constants.Terrain.FOREST:
		grid.terrain[i] = Constants.Terrain.GRASS


static func _spread_fires(grid: CityGrid, rng: RandomNumberGenerator) -> void:
	var new_fires := PackedInt32Array()
	for i in range(grid.size):
		if grid.burning[i] == 0:
			continue
		for n in grid.neighbors8(i):
			if grid.burning[n] > 0 or not _is_flammable(grid, n):
				continue
			var p := 0.22 * (1.0 - clampf(grid.cov_fire[n], 0.0, 1.0)) * clampf(grid.fire_risk[n] / 25.0 + 0.3, 0.2, 1.5)
			if rng.randf() < p:
				new_fires.append(n)
	for n in new_fires:
		ignite(grid, n)


## Flattens a tile outright (no fire). Roads survive tornadoes only by luck.
static func destroy(grid: CityGrid, i: int) -> void:
	grid.burning[i] = 0
	if grid.has_civic(i):
		for t in grid.remove_building_at(i):
			grid.building[t] = Constants.Building.RUBBLE
	elif grid.is_developed(i):
		grid.clear_development(i)
		grid.building[i] = Constants.Building.RUBBLE
	elif grid.is_road(i):
		grid.building[i] = Constants.Building.RUBBLE
		grid.owner[i] = -1
	elif grid.terrain[i] == Constants.Terrain.FOREST:
		grid.terrain[i] = Constants.Terrain.GRASS


static func _random_built_tile(grid: CityGrid, rng: RandomNumberGenerator) -> int:
	var candidates := PackedInt32Array()
	for i in range(grid.size):
		if grid.is_developed(i) or grid.has_civic(i):
			candidates.append(i)
	if candidates.is_empty():
		for _k in range(50):
			var i := rng.randi_range(0, grid.size - 1)
			if grid.is_land(i):
				return i
		return -1
	return candidates[rng.randi_range(0, candidates.size() - 1)]


static func trigger_fire(grid: CityGrid, rng: RandomNumberGenerator) -> String:
	var i := _random_built_tile(grid, rng)
	if i < 0:
		return "A fire fizzled out before it could start."
	ignite(grid, i)
	for n in grid.neighbors4(i):
		if rng.randf() < 0.5:
			ignite(grid, n)
	return "A major fire has erupted near %d, %d!" % [grid.x_of(i), grid.y_of(i)]


static func trigger_tornado(grid: CityGrid, rng: RandomNumberGenerator) -> String:
	var i := _random_built_tile(grid, rng)
	if i < 0:
		return "A tornado touched down harmlessly in open country."
	var x := grid.x_of(i)
	var y := grid.y_of(i)
	var dir := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
	var steps := rng.randi_range(10, 22)
	var pos := Vector2(float(x), float(y))
	for _s in range(steps):
		dir = (dir + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5))).normalized()
		pos += dir
		var tx := int(round(pos.x))
		var ty := int(round(pos.y))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if grid.in_bounds(tx + dx, ty + dy) and rng.randf() < 0.7:
					destroy(grid, grid.idx(tx + dx, ty + dy))
	return "A tornado has torn through the city near %d, %d!" % [x, y]


static func trigger_meteor(grid: CityGrid, rng: RandomNumberGenerator) -> String:
	var i := _random_built_tile(grid, rng)
	if i < 0:
		return "A meteor splashed into the sea."
	var x := grid.x_of(i)
	var y := grid.y_of(i)
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var d := Vector2(dx, dy).length()
			if not grid.in_bounds(x + dx, y + dy):
				continue
			var j := grid.idx(x + dx, y + dy)
			if d <= 2.0:
				destroy(grid, j)
			elif d <= 3.2 and rng.randf() < 0.6:
				ignite(grid, j)
	return "A meteor has struck the city at %d, %d!" % [x, y]
