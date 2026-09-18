class_name RoadNetwork
extends RefCounted
## Computes road connectivity, per-component job access for residents, and traffic load.


static func run(grid: CityGrid) -> void:
	_label_components(grid)
	_compute_access_and_commute(grid)
	_compute_traffic(grid)


static func _label_components(grid: CityGrid) -> void:
	grid.road_comp.fill(-1)
	var next_id := 0
	var stack := PackedInt32Array()
	for i in range(grid.size):
		if not grid.is_road(i) or grid.road_comp[i] >= 0:
			continue
		stack.clear()
		stack.append(i)
		grid.road_comp[i] = next_id
		while stack.size() > 0:
			var cur := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			for n in grid.neighbors4(cur):
				if grid.is_road(n) and grid.road_comp[n] < 0:
					grid.road_comp[n] = next_id
					stack.append(n)
		next_id += 1


static func _compute_access_and_commute(grid: CityGrid) -> void:
	grid.road_access.fill(0)
	grid.commute.fill(0.0)
	var comp_pop := {}
	var comp_jobs := {}
	var tile_comp := PackedInt32Array()
	tile_comp.resize(grid.size)
	tile_comp.fill(-1)
	var depth := PackedInt32Array()
	depth.resize(grid.size)
	depth.fill(0)

	# Depth 1: directly adjacent to a road.
	for i in range(grid.size):
		if grid.zone_type[i] == Constants.Zone.NONE:
			continue
		for n in grid.neighbors4(i):
			if grid.is_road(n):
				grid.road_access[i] = 1
				depth[i] = 1
				tile_comp[i] = grid.road_comp[n]
				break

	# Deeper lots reach the road through a connected lot of the same zone type.
	for d in range(2, Constants.ACCESS_DEPTH + 1):
		for i in range(grid.size):
			if grid.zone_type[i] == Constants.Zone.NONE or grid.road_access[i] == 1:
				continue
			for n in grid.neighbors4(i):
				if depth[n] == d - 1 and grid.zone_type[n] == grid.zone_type[i]:
					grid.road_access[i] = 1
					depth[i] = d
					tile_comp[i] = tile_comp[n]
					break

	for i in range(grid.size):
		if grid.road_access[i] == 1:
			var c := tile_comp[i]
			comp_pop[c] = comp_pop.get(c, 0) + grid.population[i]
			comp_jobs[c] = comp_jobs.get(c, 0) + grid.jobs[i]

	for i in range(grid.size):
		if grid.zone_type[i] != Constants.Zone.RES or grid.road_access[i] == 0:
			continue
		var c := tile_comp[i]
		var workers := float(comp_pop.get(c, 0)) * 0.5
		var jobs := float(comp_jobs.get(c, 0))
		if jobs <= 0.0:
			grid.commute[i] = 0.0
		else:
			grid.commute[i] = clampf(jobs / maxf(workers, 1.0), 0.0, 1.0)


static func _compute_traffic(grid: CityGrid) -> void:
	var load := PackedFloat32Array()
	load.resize(grid.size)
	load.fill(0.0)
	for i in range(grid.size):
		var trips := float(grid.population[i]) * 0.5 + float(grid.jobs[i]) * 0.6
		if trips <= 0.0:
			continue
		var roads := PackedInt32Array()
		for n in grid.neighbors4(i):
			if grid.is_road(n):
				roads.append(n)
		if roads.is_empty():
			# Deeper lots send their trips through the roads next to neighbouring lots.
			for n in grid.neighbors4(i):
				if grid.zone_type[n] == Constants.Zone.NONE:
					continue
				for m in grid.neighbors4(n):
					if grid.is_road(m):
						roads.append(m)
		if roads.is_empty():
			continue
		var share := trips / float(roads.size())
		for r in roads:
			load[r] += share

	# Diffuse traffic along the road network so arterials fill up.
	for _pass in range(4):
		var next := PackedFloat32Array()
		next.resize(grid.size)
		next.fill(0.0)
		for i in range(grid.size):
			if not grid.is_road(i):
				continue
			var sum := 0.0
			var count := 0
			for n in grid.neighbors4(i):
				if grid.is_road(n):
					sum += load[n]
					count += 1
			if count > 0:
				next[i] = load[i] * 0.55 + (sum / float(count)) * 0.45
			else:
				next[i] = load[i]
		load = next

	for i in range(grid.size):
		grid.traffic[i] = 0.0
		if grid.is_road(i):
			grid.traffic[i] = clampf(load[i] * 0.35, 0.0, 100.0)
