class_name CityGrid
extends RefCounted
## Flat-array data model for every tile in the city. All simulation systems read and
## write these arrays directly; the renderer only reads them.

var width: int = 0
var height: int = 0
var size: int = 0

# --- Static-ish layers -----------------------------------------------------------
var terrain := PackedInt32Array()      # Constants.Terrain
var elevation := PackedFloat32Array()  # 0..1

# --- Player-authored layers ------------------------------------------------------
var zone_type := PackedInt32Array()    # Constants.Zone
var zone_density := PackedInt32Array() # 1..3 (0 when unzoned)
var building := PackedInt32Array()     # Constants.Building
var owner := PackedInt32Array()        # origin tile index for multi-tile buildings, -1 otherwise

# --- Development state -----------------------------------------------------------
var level := PackedInt32Array()        # 0 = empty lot, 1..3 developed level
var wealth := PackedInt32Array()       # 1..3 for developed lots
var population := PackedInt32Array()
var jobs := PackedInt32Array()
var burning := PackedInt32Array()      # 0 = not burning, otherwise months on fire
var age := PackedInt32Array()          # months since last development change

# --- Service state (recomputed every tick) ----------------------------------------
var powered := PackedInt32Array()
var watered := PackedInt32Array()
var road_access := PackedInt32Array()
var road_comp := PackedInt32Array()    # road network component id, -1 if none
var commute := PackedFloat32Array()    # 0..1 job accessibility for residential tiles

var pollution := PackedFloat32Array()  # 0..100
var crime := PackedFloat32Array()      # 0..100
var traffic := PackedFloat32Array()    # 0..100+
var land_value := PackedFloat32Array() # 0..100
var fire_risk := PackedFloat32Array()  # 0..100

var cov_police := PackedFloat32Array()
var cov_fire := PackedFloat32Array()
var cov_school := PackedFloat32Array()
var cov_health := PackedFloat32Array()
var cov_park := PackedFloat32Array()


func _init(w: int = 64, h: int = 64) -> void:
	width = w
	height = h
	size = w * h
	for arr_name in int_layer_names():
		var arr := PackedInt32Array()
		arr.resize(size)
		arr.fill(0)
		set(arr_name, arr)
	for arr_name in float_layer_names():
		var arr := PackedFloat32Array()
		arr.resize(size)
		arr.fill(0.0)
		set(arr_name, arr)
	owner.fill(-1)
	road_comp.fill(-1)
	terrain.fill(Constants.Terrain.GRASS)


static func int_layer_names() -> Array[String]:
	return [
		"terrain", "zone_type", "zone_density", "building", "owner", "level", "wealth",
		"population", "jobs", "burning", "age", "powered", "watered", "road_access", "road_comp",
	]


static func float_layer_names() -> Array[String]:
	return [
		"elevation", "commute", "pollution", "crime", "traffic", "land_value", "fire_risk",
		"cov_police", "cov_fire", "cov_school", "cov_health", "cov_park",
	]


## Layers that must be persisted; the rest are derived every tick.
static func persisted_int_layers() -> Array[String]:
	return ["terrain", "zone_type", "zone_density", "building", "owner", "level", "wealth",
		"population", "jobs", "burning", "age"]


static func persisted_float_layers() -> Array[String]:
	return ["elevation", "pollution", "crime", "traffic", "land_value"]


func idx(x: int, y: int) -> int:
	return y * width + x


func x_of(i: int) -> int:
	return i % width


func y_of(i: int) -> int:
	return i / width


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


## Four-connected neighbour indices of tile i.
func neighbors4(i: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var x := x_of(i)
	var y := y_of(i)
	if x > 0:
		out.append(i - 1)
	if x < width - 1:
		out.append(i + 1)
	if y > 0:
		out.append(i - width)
	if y < height - 1:
		out.append(i + width)
	return out


## Eight-connected neighbour indices of tile i.
func neighbors8(i: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var x := x_of(i)
	var y := y_of(i)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx := x + dx
			var ny := y + dy
			if in_bounds(nx, ny):
				out.append(idx(nx, ny))
	return out


func is_land(i: int) -> bool:
	return terrain[i] != Constants.Terrain.WATER


func is_road(i: int) -> bool:
	return building[i] == Constants.Building.ROAD


func is_developed(i: int) -> bool:
	return zone_type[i] != Constants.Zone.NONE and level[i] > 0


func has_civic(i: int) -> bool:
	var b := building[i]
	return b != Constants.Building.NONE and b != Constants.Building.ROAD and b != Constants.Building.RUBBLE


## A tile conducts power/water if anything is built on it.
func conducts(i: int) -> bool:
	return building[i] != Constants.Building.NONE or zone_type[i] != Constants.Zone.NONE


func has_water_neighbor(i: int) -> bool:
	for n in neighbors4(i):
		if terrain[n] == Constants.Terrain.WATER:
			return true
	return false


## Clears all development, buildings and zoning from a tile. Terrain is kept.
func clear_tile(i: int) -> void:
	zone_type[i] = Constants.Zone.NONE
	zone_density[i] = 0
	building[i] = Constants.Building.NONE
	owner[i] = -1
	level[i] = 0
	wealth[i] = 0
	population[i] = 0
	jobs[i] = 0
	burning[i] = 0
	age[i] = 0


## Removes any development on a zoned lot but keeps the zone designation.
func clear_development(i: int) -> void:
	level[i] = 0
	wealth[i] = 0
	population[i] = 0
	jobs[i] = 0
	age[i] = 0


## Returns true when every tile of the footprint can accept a new building.
func footprint_free(x: int, y: int, fsize: int) -> bool:
	for dy in range(fsize):
		for dx in range(fsize):
			var nx := x + dx
			var ny := y + dy
			if not in_bounds(nx, ny):
				return false
			var i := idx(nx, ny)
			if not is_land(i):
				return false
			if building[i] != Constants.Building.NONE:
				return false
			if level[i] > 0:
				return false
	return true


## Places a building whose origin (top-left in tile space) is (x, y).
func place_building(x: int, y: int, type: int, fsize: int) -> void:
	var origin := idx(x, y)
	for dy in range(fsize):
		for dx in range(fsize):
			var i := idx(x + dx, y + dy)
			zone_type[i] = Constants.Zone.NONE
			zone_density[i] = 0
			level[i] = 0
			population[i] = 0
			jobs[i] = 0
			burning[i] = 0
			building[i] = type
			owner[i] = origin
			if terrain[i] == Constants.Terrain.FOREST:
				terrain[i] = Constants.Terrain.GRASS


## Removes the building occupying tile i (all of its footprint). Returns affected tiles.
func remove_building_at(i: int) -> PackedInt32Array:
	var affected := PackedInt32Array()
	var origin := owner[i]
	if origin < 0:
		if building[i] != Constants.Building.NONE:
			building[i] = Constants.Building.NONE
			affected.append(i)
		return affected
	var type := building[origin]
	var fsize := int(BuildingDefs.def_value(type, "size", 1))
	var ox := x_of(origin)
	var oy := y_of(origin)
	for dy in range(fsize):
		for dx in range(fsize):
			var nx := ox + dx
			var ny := oy + dy
			if in_bounds(nx, ny):
				var j := idx(nx, ny)
				if owner[j] == origin:
					building[j] = Constants.Building.NONE
					owner[j] = -1
					affected.append(j)
	return affected


## Origin tiles of all civic buildings (excluding roads and rubble).
func civic_origins() -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in range(size):
		if has_civic(i) and owner[i] == i:
			out.append(i)
	return out


## Indices of the footprint of the building whose origin is `origin`.
func footprint_of(origin: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var fsize := int(BuildingDefs.def_value(building[origin], "size", 1))
	var ox := x_of(origin)
	var oy := y_of(origin)
	for dy in range(fsize):
		for dx in range(fsize):
			if in_bounds(ox + dx, oy + dy):
				out.append(idx(ox + dx, oy + dy))
	return out


## Sets a developed lot's level and recomputes its population/jobs.
func set_level(i: int, new_level: int) -> void:
	level[i] = clampi(new_level, 0, 3)
	age[i] = 0
	if level[i] == 0:
		population[i] = 0
		jobs[i] = 0
		wealth[i] = 0
		return
	var d := zone_density[i]
	match zone_type[i]:
		Constants.Zone.RES:
			population[i] = Constants.RES_POP_PER_LEVEL[d] * level[i]
			jobs[i] = 0
		Constants.Zone.COM:
			jobs[i] = Constants.COM_JOBS_PER_LEVEL[d] * level[i]
			population[i] = 0
		Constants.Zone.IND:
			jobs[i] = Constants.IND_JOBS_PER_LEVEL[d] * level[i]
			population[i] = 0
