class_name EnvironmentSim
extends RefCounted
## Pollution, crime, land value and fire risk maps.


static func run(grid: CityGrid, state = null) -> void:
	_pollution(grid, state)
	_crime(grid)
	_land_value(grid)
	_fire_risk(grid)


static func _blur(grid: CityGrid, src: PackedFloat32Array, passes: int) -> PackedFloat32Array:
	var cur := src.duplicate()
	for _p in range(passes):
		var next := PackedFloat32Array()
		next.resize(grid.size)
		for y in range(grid.height):
			for x in range(grid.width):
				var i := grid.idx(x, y)
				var sum := cur[i] * 4.0
				var wsum := 4.0
				if x > 0:
					sum += cur[i - 1]
					wsum += 1.0
				if x < grid.width - 1:
					sum += cur[i + 1]
					wsum += 1.0
				if y > 0:
					sum += cur[i - grid.width]
					wsum += 1.0
				if y < grid.height - 1:
					sum += cur[i + grid.width]
					wsum += 1.0
				next[i] = sum / wsum
		cur = next
	return cur


static func _pollution(grid: CityGrid, state) -> void:
	# Refuse the city cannot process rots where it was produced.
	var uncollected := 0.0
	if state != null:
		uncollected = clampf(1.0 - state.waste_served, 0.0, 1.0)
	var src := PackedFloat32Array()
	src.resize(grid.size)
	src.fill(0.0)
	for i in range(grid.size):
		var v := 0.0
		if grid.zone_type[i] == Constants.Zone.IND and grid.level[i] > 0:
			v += 6.0 * float(grid.level[i]) * float(grid.zone_density[i])
		if grid.has_civic(i):
			v += float(BuildingDefs.def_value(grid.building[i], "pollution", 0))
		if grid.is_road(i):
			v += grid.traffic[i] * 0.25
		if grid.burning[i] > 0:
			v += 30.0
		if grid.building[i] == Constants.Building.RUBBLE:
			v += 2.0
		if uncollected > 0.0:
			v += Waste.tile_waste(grid, i) * uncollected * 1.4
		src[i] = v
	var spread := _blur(grid, src, 3)
	for i in range(grid.size):
		var p := spread[i] * 2.2
		if grid.terrain[i] == Constants.Terrain.FOREST:
			p -= 6.0
		p -= grid.cov_park[i] * 12.0
		# Pollution lingers: blend with last month's value.
		grid.pollution[i] = clampf(grid.pollution[i] * 0.4 + maxf(p, 0.0) * 0.6, 0.0, 100.0)


static func _crime(grid: CityGrid) -> void:
	var src := PackedFloat32Array()
	src.resize(grid.size)
	src.fill(0.0)
	for i in range(grid.size):
		var v := 0.0
		if grid.is_developed(i):
			var density := float(grid.zone_density[i])
			var poverty := float(4 - grid.wealth[i]) # 3 for low wealth, 1 for high
			match grid.zone_type[i]:
				Constants.Zone.RES:
					v = 6.0 * density * poverty * 0.6 + (1.0 - grid.commute[i]) * 10.0
				Constants.Zone.COM:
					v = 5.0 * density * poverty * 0.5
				Constants.Zone.IND:
					v = 4.0 * density
		if grid.building[i] == Constants.Building.RUBBLE:
			v += 8.0
		src[i] = v
	var spread := _blur(grid, src, 2)
	for i in range(grid.size):
		var c := spread[i] * 1.8
		c -= grid.cov_police[i] * 45.0
		c -= grid.cov_school[i] * 8.0
		grid.crime[i] = clampf(grid.crime[i] * 0.3 + maxf(c, 0.0) * 0.7, 0.0, 100.0)


static func _land_value(grid: CityGrid) -> void:
	# Precompute water and industry proximity masks.
	var near_water := PackedFloat32Array()
	near_water.resize(grid.size)
	near_water.fill(0.0)
	var near_ind := PackedFloat32Array()
	near_ind.resize(grid.size)
	near_ind.fill(0.0)
	for i in range(grid.size):
		if grid.terrain[i] == Constants.Terrain.WATER:
			near_water[i] = 1.0
		if grid.zone_type[i] == Constants.Zone.IND:
			near_ind[i] = 1.0
	near_water = _blur(grid, near_water, 3)
	near_ind = _blur(grid, near_ind, 2)

	var raw := PackedFloat32Array()
	raw.resize(grid.size)
	for i in range(grid.size):
		var v := 28.0
		v += grid.elevation[i] * 22.0
		v += near_water[i] * 40.0
		if grid.terrain[i] == Constants.Terrain.FOREST:
			v += 6.0
		v += grid.cov_park[i] * 26.0
		v += grid.cov_school[i] * 10.0
		v += grid.cov_health[i] * 10.0
		v += grid.cov_police[i] * 6.0
		v -= grid.pollution[i] * 0.55
		v -= grid.crime[i] * 0.45
		v -= grid.traffic[i] * 0.15
		v -= near_ind[i] * 25.0
		if grid.zone_type[i] == Constants.Zone.COM and grid.level[i] > 0:
			v += 4.0 * float(grid.level[i])
		raw[i] = v
	var smooth := _blur(grid, raw, 1)
	for i in range(grid.size):
		grid.land_value[i] = clampf(smooth[i], 0.0, 100.0)


static func _fire_risk(grid: CityGrid) -> void:
	for i in range(grid.size):
		var r := 0.0
		if grid.is_developed(i):
			match grid.zone_type[i]:
				Constants.Zone.RES: r = 8.0
				Constants.Zone.COM: r = 10.0
				Constants.Zone.IND: r = 22.0
			r += 3.0 * float(grid.level[i])
			r += float(3 - grid.wealth[i]) * 3.0
		elif grid.has_civic(i):
			r = float(BuildingDefs.def_value(grid.building[i], "fire_risk", 3))
		elif grid.terrain[i] == Constants.Terrain.FOREST:
			r = 5.0
		r *= (1.0 - 0.85 * clampf(grid.cov_fire[i], 0.0, 1.0))
		if grid.is_developed(i) and grid.watered[i] == 0:
			r *= 1.5
		grid.fire_risk[i] = clampf(r, 0.0, 100.0)
