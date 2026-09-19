class_name BuildTools
extends RefCounted
## Applies player tools (zoning, roads, buildings, bulldozing) to the grid, charging costs
## and emitting change events. Pure logic: no rendering or input handling here.

const T := Constants.Tool
const B := Constants.Building
const Z := Constants.Zone


func _grid() -> CityGrid:
	return GameState.grid


## Whether a single-tile action of `tool` is legal at (x, y). Does not check funds.
func can_apply_at(tool: int, x: int, y: int) -> bool:
	var grid := _grid()
	if grid == null or not grid.in_bounds(x, y):
		return false
	var i := grid.idx(x, y)
	if BuildingDefs.tool_is_zone(tool):
		if not grid.is_land(i) or grid.building[i] != B.NONE or grid.level[i] > 0:
			return false
		var zd: Array = BuildingDefs.TOOL_ZONE[tool]
		# Re-zoning to the identical zone is a no-op, not a placement.
		return not (grid.zone_type[i] == zd[0] and grid.zone_density[i] == zd[1])
	match tool:
		T.ROAD:
			return grid.is_land(i) and grid.building[i] == B.NONE and grid.level[i] == 0
		T.BULLDOZE:
			return grid.is_land(i) and (grid.building[i] != B.NONE or grid.zone_type[i] != Z.NONE \
				or grid.terrain[i] == Constants.Terrain.FOREST)
		T.DEZONE:
			return grid.zone_type[i] != Z.NONE and grid.level[i] == 0 and grid.building[i] == B.NONE
	if BuildingDefs.tool_is_building(tool):
		var type: int = BuildingDefs.TOOL_BUILDING[tool]
		var fsize := int(BuildingDefs.def_value(type, "size", 1))
		return grid.footprint_free(x, y, fsize)
	return false


## Cost of applying `tool` to a rectangle. Zone tools include the service roads the game
## will lay for you.
func area_cost(tool: int, x0: int, y0: int, x1: int, y1: int) -> int:
	if BuildingDefs.tool_is_zone(tool):
		var plan := plan_zone_roads(tool, x0, y0, x1, y1)
		return BuildingDefs.tool_cost(tool) * plan["lots"].size() \
			+ BuildingDefs.tool_cost(T.ROAD) * plan["roads"].size()
	var per := BuildingDefs.tool_cost(tool)
	var count := 0
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		for x in range(mini(x0, x1), maxi(x0, x1) + 1):
			if can_apply_at(tool, x, y):
				count += 1
	return per * count


## Plans a zone drag: which tiles become lots, and which service roads have to be laid so
## that no block of lots is larger than the zone allows and every lot can reach the road
## network. Nothing is placed here, so the cursor can preview the result before committing.
##
## Roads are laid rather than refusing the lots, because a player dragging a big rectangle
## means "make this a district", not "give me an error".
func plan_zone_roads(tool: int, x0: int, y0: int, x1: int, y1: int) -> Dictionary:
	var grid := _grid()
	var empty := { "lots": PackedInt32Array(), "roads": PackedInt32Array() }
	if grid == null or not BuildingDefs.tool_is_zone(tool):
		return empty
	var zd: Array = BuildingDefs.TOOL_ZONE[tool]
	var zone: int = zd[0]
	var density: int = zd[1]
	var limits := Constants.block_limits(zone, density)
	var rx0 := clampi(mini(x0, x1), 0, grid.width - 1)
	var rx1 := clampi(maxi(x0, x1), 0, grid.width - 1)
	var ry0 := clampi(mini(y0, y1), 0, grid.height - 1)
	var ry1 := clampi(maxi(y0, y1), 0, grid.height - 1)

	var lots := {}
	for y in range(ry0, ry1 + 1):
		for x in range(rx0, rx1 + 1):
			if can_apply_at(tool, x, y):
				lots[grid.idx(x, y)] = true
	if lots.is_empty():
		return empty

	var roads := {}
	var w := rx1 - rx0 + 1
	var h := ry1 - ry0 + 1
	# The short limit belongs to whichever side of the drag is already the shorter one.
	var rows_are_short := h <= w
	var row_limit := limits.x if rows_are_short else limits.y
	var col_limit := limits.y if rows_are_short else limits.x
	_partition(grid, lots, roads, rx0, rx1, ry0, ry1, true, row_limit)
	_partition(grid, lots, roads, rx0, rx1, ry0, ry1, false, col_limit)

	# Safety net: anything still out of reach of a road gets one alongside it.
	for _pass in range(4):
		var stranded := _stranded_lots(grid, tool, lots, roads)
		if stranded.is_empty():
			break
		_road_beside(grid, lots, roads, stranded[0])

	_connect_to_network(grid, roads, rx0, rx1, ry0, ry1)

	var lot_list := PackedInt32Array()
	for i in lots.keys():
		lot_list.append(i)
	var road_list := PackedInt32Array()
	for i in roads.keys():
		# Tiles that are already road cost nothing and need no work.
		if not grid.is_road(i):
			road_list.append(i)
	return { "lots": lot_list, "roads": road_list }


## Walks the rectangle one line at a time and turns a line into road whenever the run of
## zoned lines since the last road would exceed `limit`. A limit of 0 means no limit.
func _partition(grid: CityGrid, lots: Dictionary, roads: Dictionary,
		rx0: int, rx1: int, ry0: int, ry1: int, by_row: bool, limit: int) -> void:
	if limit <= 0:
		return
	var outer_from := ry0 if by_row else rx0
	var outer_to := ry1 if by_row else rx1
	var inner_from := rx0 if by_row else ry0
	var inner_to := rx1 if by_row else ry1
	var span := inner_to - inner_from + 1
	var run := 0
	for a in range(outer_from, outer_to + 1):
		var road_tiles := 0
		var lot_tiles := 0
		for b in range(inner_from, inner_to + 1):
			var i := grid.idx(b, a) if by_row else grid.idx(a, b)
			if roads.has(i) or grid.is_road(i):
				road_tiles += 1
			elif lots.has(i):
				lot_tiles += 1
		if lot_tiles == 0:
			# Nothing to serve on this line; a solid road line also resets the run.
			if road_tiles > 0:
				run = 0
			continue
		if road_tiles >= maxi(1, int(float(span) * 0.6)):
			run = 0
			continue
		run += 1
		if run <= limit:
			continue
		# This line becomes a service road.
		for b in range(inner_from, inner_to + 1):
			var i := grid.idx(b, a) if by_row else grid.idx(a, b)
			if lots.has(i) or grid.is_road(i):
				lots.erase(i)
				roads[i] = true
			elif can_apply_at(T.ROAD, b, a) if by_row else can_apply_at(T.ROAD, a, b):
				roads[i] = true
		run = 0


## Lots that would still be too far from a road once the planned roads exist.
func _stranded_lots(grid: CityGrid, tool: int, lots: Dictionary, roads: Dictionary) -> PackedInt32Array:
	var reach := zone_reachability_for(tool, lots, roads)
	var out := PackedInt32Array()
	for i in lots.keys():
		if not reach.get(i, false):
			out.append(i)
	return out


## Lays a road line through the row of a stranded lot, so its block gains frontage.
func _road_beside(grid: CityGrid, lots: Dictionary, roads: Dictionary, tile: int) -> void:
	var y := grid.y_of(tile)
	var x := grid.x_of(tile)
	# Walk left and right along this row for as long as the lots continue.
	var from_x := x
	while from_x > 0 and lots.has(grid.idx(from_x - 1, y)):
		from_x -= 1
	var to_x := x
	while to_x < grid.width - 1 and lots.has(grid.idx(to_x + 1, y)):
		to_x += 1
	for bx in range(from_x, to_x + 1):
		var i := grid.idx(bx, y)
		lots.erase(i)
		if grid.is_road(i) or can_apply_at(T.ROAD, bx, y):
			roads[i] = true


## Makes sure the planned roads touch the existing network, so the new district is not an
## island with no way to reach the city's jobs.
func _connect_to_network(grid: CityGrid, roads: Dictionary, rx0: int, rx1: int, ry0: int, ry1: int) -> void:
	if roads.is_empty():
		return
	for i in roads.keys():
		if grid.is_road(i):
			return
		for n in grid.neighbors4(i):
			if grid.is_road(n):
				return
	# Find the nearest existing road to the middle of the drag.
	var cx := (rx0 + rx1) / 2
	var cy := (ry0 + ry1) / 2
	var best := -1
	var best_d := 1 << 30
	for i in range(grid.size):
		if not grid.is_road(i):
			continue
		var d := absi(grid.x_of(i) - cx) + absi(grid.y_of(i) - cy)
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return
	# Run an L-shaped link from the planned road closest to it.
	var tx := grid.x_of(best)
	var ty := grid.y_of(best)
	var from := -1
	var from_d := 1 << 30
	for i in roads.keys():
		var d := absi(grid.x_of(i) - tx) + absi(grid.y_of(i) - ty)
		if d < from_d:
			from_d = d
			from = i
	if from < 0:
		return
	for p in line_tiles(grid.x_of(from), grid.y_of(from), tx, ty):
		var i := grid.idx(p.x, p.y)
		if grid.is_road(i) or can_apply_at(T.ROAD, p.x, p.y):
			roads[i] = true


## Reachability for an explicit set of candidate lots against the roads that exist plus a
## set of planned ones. Returns {tile index: bool}.
func zone_reachability_for(tool: int, lots: Dictionary, extra_roads: Dictionary) -> Dictionary:
	var grid := _grid()
	var result := {}
	if grid == null or not BuildingDefs.tool_is_zone(tool):
		return result
	var zd: Array = BuildingDefs.TOOL_ZONE[tool]
	var zone: int = zd[0]
	var limit := Constants.access_depth(zone, zd[1])
	var depth := {}
	var frontier := PackedInt32Array()
	for i in lots.keys():
		result[i] = false
		for n in grid.neighbors4(i):
			if grid.is_road(n) or extra_roads.has(n):
				depth[i] = 1
				frontier.append(i)
				break
	var d := 1
	while d < limit and not frontier.is_empty():
		var next := PackedInt32Array()
		for i in frontier:
			for n in grid.neighbors4(i):
				if depth.has(n):
					continue
				if lots.has(n) or (grid.zone_type[n] == zone and grid.building[n] == B.NONE):
					depth[n] = d + 1
					next.append(n)
		frontier = next
		d += 1
	for i in result.keys():
		result[i] = depth.has(i)
	return result


## Tiles an L-shaped road drag would touch (horizontal first, then vertical).
func line_tiles(x0: int, y0: int, x1: int, y1: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var step_x := 1 if x1 >= x0 else -1
	var step_y := 1 if y1 >= y0 else -1
	var x := x0
	while true:
		out.append(Vector2i(x, y0))
		if x == x1:
			break
		x += step_x
	var y := y0
	while y != y1:
		y += step_y
		out.append(Vector2i(x1, y))
	return out


func line_cost(tool: int, x0: int, y0: int, x1: int, y1: int) -> int:
	var per := BuildingDefs.tool_cost(tool)
	var count := 0
	for p in line_tiles(x0, y0, x1, y1):
		if can_apply_at(tool, p.x, p.y):
			count += 1
	return per * count


## Applies an area tool over a rectangle. Returns the number of tiles changed.
## Zone tools first lay whatever service roads the district needs.
func apply_area(tool: int, x0: int, y0: int, x1: int, y1: int) -> int:
	if BuildingDefs.tool_is_zone(tool):
		return _apply_zone_area(tool, x0, y0, x1, y1)
	var changed := PackedInt32Array()
	var grid := _grid()
	var per := BuildingDefs.tool_cost(tool)
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		for x in range(mini(x0, x1), maxi(x0, x1) + 1):
			if not can_apply_at(tool, x, y):
				continue
			if per > 0 and GameState.funds < per:
				GameState.post_message("Not enough funds.")
				_finish(changed)
				return changed.size()
			var i := grid.idx(x, y)
			_apply_single(tool, i)
			if per > 0:
				GameState.spend(per)
			changed.append(i)
	_finish(changed)
	return changed.size()


func _apply_zone_area(tool: int, x0: int, y0: int, x1: int, y1: int) -> int:
	var grid := _grid()
	var plan := plan_zone_roads(tool, x0, y0, x1, y1)
	var changed := PackedInt32Array()
	var road_cost := BuildingDefs.tool_cost(T.ROAD)
	var zone_cost := BuildingDefs.tool_cost(tool)
	var roads_laid := 0
	var out_of_funds := false

	for i in plan["roads"]:
		if GameState.funds < road_cost:
			out_of_funds = true
			break
		_apply_single(T.ROAD, i)
		GameState.spend(road_cost)
		changed.append(i)
		roads_laid += 1
	if not out_of_funds:
		for i in plan["lots"]:
			if zone_cost > 0 and GameState.funds < zone_cost:
				out_of_funds = true
				break
			# A planned road may have taken this tile.
			if grid.is_road(i):
				continue
			_apply_single(tool, i)
			if zone_cost > 0:
				GameState.spend(zone_cost)
			changed.append(i)

	if out_of_funds:
		GameState.post_message("Not enough funds.")
	elif roads_laid > 0:
		GameState.post_message("Laid %d road tile%s to serve the new zone." % [roads_laid, "" if roads_laid == 1 else "s"])
	_finish(changed)
	return changed.size()


## Applies a line tool (roads) along an L-shaped path. Returns tiles changed.
func apply_line(tool: int, x0: int, y0: int, x1: int, y1: int) -> int:
	var changed := PackedInt32Array()
	var grid := _grid()
	var per := BuildingDefs.tool_cost(tool)
	for p in line_tiles(x0, y0, x1, y1):
		if not can_apply_at(tool, p.x, p.y):
			continue
		if per > 0 and GameState.funds < per:
			GameState.post_message("Not enough funds.")
			break
		var i := grid.idx(p.x, p.y)
		_apply_single(tool, i)
		if per > 0:
			GameState.spend(per)
		changed.append(i)
	_finish(changed)
	return changed.size()


## Places a building with its origin at (x, y). Returns true on success.
func apply_point(tool: int, x: int, y: int) -> bool:
	var grid := _grid()
	if not BuildingDefs.tool_is_building(tool):
		return false
	if not can_apply_at(tool, x, y):
		GameState.post_message("Cannot build there.")
		return false
	var type: int = BuildingDefs.TOOL_BUILDING[tool]
	var cost := BuildingDefs.tool_cost(tool)
	if GameState.funds < cost:
		GameState.post_message("Not enough funds for a %s." % BuildingDefs.def_value(type, "name", "building"))
		return false
	var fsize := int(BuildingDefs.def_value(type, "size", 1))
	grid.place_building(x, y, type, fsize)
	GameState.spend(cost)
	if BuildingDefs.def_value(type, "needs_water", false):
		var ok := false
		for i in grid.footprint_of(grid.idx(x, y)):
			if grid.has_water_neighbor(i):
				ok = true
		if not ok:
			GameState.post_message("This pump is not next to water and will produce nothing.")
	_finish(grid.footprint_of(grid.idx(x, y)))
	return true


func _apply_single(tool: int, i: int) -> void:
	var grid := _grid()
	if BuildingDefs.tool_is_zone(tool):
		var zd: Array = BuildingDefs.TOOL_ZONE[tool]
		grid.zone_type[i] = zd[0]
		grid.zone_density[i] = zd[1]
		grid.level[i] = 0
		grid.age[i] = 0
		grid.abandoned[i] = 0
		if grid.terrain[i] == Constants.Terrain.FOREST:
			grid.terrain[i] = Constants.Terrain.GRASS
		return
	match tool:
		T.ROAD:
			grid.zone_type[i] = Z.NONE
			grid.zone_density[i] = 0
			grid.building[i] = B.ROAD
			grid.owner[i] = -1
			if grid.terrain[i] == Constants.Terrain.FOREST:
				grid.terrain[i] = Constants.Terrain.GRASS
		T.DEZONE:
			grid.zone_type[i] = Z.NONE
			grid.zone_density[i] = 0
			grid.abandoned[i] = 0
		T.BULLDOZE:
			_bulldoze(i)


func _bulldoze(i: int) -> void:
	var grid := _grid()
	grid.burning[i] = 0
	grid.abandoned[i] = 0
	if grid.has_civic(i):
		grid.remove_building_at(i)
		return
	if grid.building[i] != B.NONE:
		grid.building[i] = B.NONE
		grid.owner[i] = -1
		return
	if grid.level[i] > 0:
		grid.clear_development(i)
		return
	if grid.zone_type[i] != Z.NONE:
		grid.zone_type[i] = Z.NONE
		grid.zone_density[i] = 0
		return
	if grid.terrain[i] == Constants.Terrain.FOREST:
		grid.terrain[i] = Constants.Terrain.GRASS


func _finish(changed: PackedInt32Array) -> void:
	if changed.is_empty():
		return
	# Utilities and road access respond immediately so the player gets feedback.
	Simulation.refresh(GameState.grid, GameState)
	Events.tiles_changed.emit(changed)
	Events.world_changed.emit()
