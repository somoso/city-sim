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


## Cost of applying `tool` to a rectangle, counting only tiles where it is legal (and, for
## zone tools, reachable from a road).
func area_cost(tool: int, x0: int, y0: int, x1: int, y1: int) -> int:
	var per := BuildingDefs.tool_cost(tool)
	var count := 0
	if BuildingDefs.tool_is_zone(tool):
		for reachable in zone_reachability(tool, x0, y0, x1, y1).values():
			if reachable:
				count += 1
		return per * count
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		for x in range(mini(x0, x1), maxi(x0, x1) + 1):
			if can_apply_at(tool, x, y):
				count += 1
	return per * count


## For a zone tool over a rectangle, returns {tile index: bool} for every tile the tool
## could legally zone, where true means the lot would be within Constants.ACCESS_DEPTH
## tiles of a road (counting paths through lots of the same zone type, including the ones
## being zoned right now). Lots marked false are skipped by apply_area.
func zone_reachability(tool: int, x0: int, y0: int, x1: int, y1: int) -> Dictionary:
	var grid := _grid()
	var result := {}
	if grid == null or not BuildingDefs.tool_is_zone(tool):
		return result
	var zone: int = BuildingDefs.TOOL_ZONE[tool][0]
	var rx0 := mini(x0, x1)
	var rx1 := maxi(x0, x1)
	var ry0 := mini(y0, y1)
	var ry1 := maxi(y0, y1)
	for y in range(ry0, ry1 + 1):
		for x in range(rx0, rx1 + 1):
			if can_apply_at(tool, x, y):
				result[grid.idx(x, y)] = false
	if result.is_empty():
		return result

	var depth_limit := Constants.ACCESS_DEPTH
	# Search a margin around the rectangle so existing lots can bridge to a road.
	var ex0 := maxi(0, rx0 - depth_limit)
	var ex1 := mini(grid.width - 1, rx1 + depth_limit)
	var ey0 := maxi(0, ry0 - depth_limit)
	var ey1 := mini(grid.height - 1, ry1 + depth_limit)

	var depth := {}
	var frontier := PackedInt32Array()
	for y in range(ey0, ey1 + 1):
		for x in range(ex0, ex1 + 1):
			var i := grid.idx(x, y)
			if not _passable_for_zone(i, zone, result):
				continue
			for n in grid.neighbors4(i):
				if grid.is_road(n):
					depth[i] = 1
					frontier.append(i)
					break
	var d := 1
	while d < depth_limit and not frontier.is_empty():
		var next := PackedInt32Array()
		for i in frontier:
			for n in grid.neighbors4(i):
				if depth.has(n):
					continue
				var nx := grid.x_of(n)
				var ny := grid.y_of(n)
				if nx < ex0 or nx > ex1 or ny < ey0 or ny > ey1:
					continue
				if _passable_for_zone(n, zone, result):
					depth[n] = d + 1
					next.append(n)
		frontier = next
		d += 1
	for i in result.keys():
		result[i] = depth.has(i)
	return result


func _passable_for_zone(i: int, zone: int, candidates: Dictionary) -> bool:
	if candidates.has(i):
		return true
	var grid := _grid()
	return grid.zone_type[i] == zone and grid.building[i] == B.NONE


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
## Zone tools skip lots that could never be reached from a road.
func apply_area(tool: int, x0: int, y0: int, x1: int, y1: int) -> int:
	var changed := PackedInt32Array()
	var grid := _grid()
	var per := BuildingDefs.tool_cost(tool)
	var reach := {}
	var is_zone := BuildingDefs.tool_is_zone(tool)
	if is_zone:
		reach = zone_reachability(tool, x0, y0, x1, y1)
	var skipped := 0
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		for x in range(mini(x0, x1), maxi(x0, x1) + 1):
			if not can_apply_at(tool, x, y):
				continue
			if is_zone and not reach.get(grid.idx(x, y), false):
				skipped += 1
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
	if skipped > 0:
		GameState.post_message("%d lot%s skipped: zones must be within %d tiles of a road." % [
			skipped, "" if skipped == 1 else "s", Constants.ACCESS_DEPTH])
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
