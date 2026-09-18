class_name Utilities
extends RefCounted
## Power and water distribution. Supply propagates from plants through any built tile.
## If a network's demand exceeds supply, tiles furthest from the sources go dark first.


static func run(grid: CityGrid, state) -> void:
	var power := _distribute(grid, "power_out", "power_use", Constants.ZONE_POWER_USE, grid.powered)
	var water := _distribute(grid, "water_out", "water_use", Constants.ZONE_WATER_USE, grid.watered)
	state.power_supply = power[0]
	state.power_demand = power[1]
	state.water_supply = water[0]
	state.water_demand = water[1]


static func _source_output(grid: CityGrid, origin: int, out_key: String) -> float:
	var type := grid.building[origin]
	var out := float(BuildingDefs.def_value(type, out_key, 0))
	if out <= 0.0 or grid.burning[origin] > 0:
		return 0.0
	if out_key == "water_out" and BuildingDefs.def_value(type, "needs_water", false):
		var ok := false
		for i in grid.footprint_of(origin):
			if grid.has_water_neighbor(i):
				ok = true
				break
		if not ok:
			return 0.0
	return out


static func _tile_use(grid: CityGrid, i: int, use_key: String, zone_table: Array) -> float:
	if grid.is_developed(i):
		return float(zone_table[grid.zone_density[i]]) * float(grid.level[i])
	if grid.has_civic(i) and grid.owner[i] == i:
		return float(BuildingDefs.def_value(grid.building[i], use_key, 0))
	return 0.0


## Returns [total_supply, total_demand] and fills `result` with 1 for served tiles.
static func _distribute(grid: CityGrid, out_key: String, use_key: String, zone_table: Array, result: PackedInt32Array) -> Array:
	result.fill(0)
	var net_id := PackedInt32Array()
	net_id.resize(grid.size)
	net_id.fill(-1)

	var total_supply := 0.0
	var total_demand := 0.0
	var networks: Array = [] # each: { "supply": float, "demand": float, "tiles": PackedInt32Array }

	# Seed BFS from every producing building.
	for origin in grid.civic_origins():
		var out := _source_output(grid, origin, out_key)
		if out <= 0.0:
			continue
		if net_id[origin] >= 0:
			networks[net_id[origin]]["supply"] += out
			total_supply += out
			continue
		var id := networks.size()
		var tiles := PackedInt32Array()
		var demand := 0.0
		total_supply += out
		var head := 0
		for f in grid.footprint_of(origin):
			net_id[f] = id
			tiles.append(f)
		# `tiles` doubles as the BFS queue; BFS order is kept for the rationing pass below.
		while head < tiles.size():
			var cur := tiles[head]
			head += 1
			demand += _tile_use(grid, cur, use_key, zone_table)
			for n in grid.neighbors4(cur):
				if net_id[n] < 0 and grid.conducts(n):
					net_id[n] = id
					tiles.append(n)
		networks.append({ "supply": out, "demand": demand, "tiles": tiles })

	for net in networks:
		total_demand += net["demand"]
		var budget: float = net["supply"]
		var tiles: PackedInt32Array = net["tiles"]
		if net["demand"] <= net["supply"]:
			for t in tiles:
				result[t] = 1
		else:
			# BFS order: tiles nearest the source are served first.
			for t in tiles:
				var use := _tile_use(grid, t, use_key, zone_table)
				if use <= budget:
					budget -= use
					result[t] = 1
				elif use == 0.0:
					result[t] = 1

	# Count demand of unconnected consumers too, so the HUD reflects real need.
	for i in range(grid.size):
		if net_id[i] < 0:
			total_demand += _tile_use(grid, i, use_key, zone_table)

	return [total_supply, total_demand]
