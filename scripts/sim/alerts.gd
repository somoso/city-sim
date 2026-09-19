class_name Alerts
extends RefCounted
## Works out which lots and buildings are missing a service, so the renderer can flash a
## warning over them and the HUD can summarise the problem. Derived state only: nothing
## here changes the simulation.

const NONE := 0
const NO_ROAD := 1
const NO_POWER := 2
const NO_WATER := 4
const ABANDONED := 8

const KINDS := ["road", "power", "water", "abandoned"]


static func mask_for(kind: String) -> int:
	match kind:
		"road": return NO_ROAD
		"power": return NO_POWER
		"water": return NO_WATER
		"abandoned": return ABANDONED
	return NONE


## Returns { "flags": PackedByteArray of NO_* bits per tile, "counts": {kind: int} }.
##
## A zoned lot with no road access reports only that, because road access is what the
## player has to fix first and power and water travel along roads anyway. Lots that are
## zoned but not yet developed are included: they are exactly the ones a player is most
## likely to misread as "nothing is happening here".
static func compute(grid: CityGrid) -> Dictionary:
	var flags := PackedByteArray()
	var counts := { "road": 0, "power": 0, "water": 0, "abandoned": 0 }
	if grid == null:
		return { "flags": flags, "counts": counts }
	flags.resize(grid.size)
	flags.fill(0)

	for i in range(grid.size):
		var f := NONE
		if grid.zone_type[i] != Constants.Zone.NONE:
			if grid.road_access[i] == 0:
				f = NO_ROAD
			else:
				if grid.powered[i] == 0:
					f |= NO_POWER
				if grid.watered[i] == 0:
					f |= NO_WATER
			if grid.abandoned[i] == 1:
				f |= ABANDONED
		elif grid.has_civic(i) and grid.owner[i] == i:
			var type := grid.building[i]
			if int(BuildingDefs.def_value(type, "power_use", 0)) > 0 and grid.powered[i] == 0:
				f |= NO_POWER
			if int(BuildingDefs.def_value(type, "water_use", 0)) > 0 and grid.watered[i] == 0:
				f |= NO_WATER
			if bool(BuildingDefs.def_value(type, "needs_water", false)) and not _touches_water(grid, i):
				f |= NO_WATER
		if f == NONE:
			continue
		flags[i] = f
		if f & NO_ROAD:
			counts["road"] += 1
		if f & NO_POWER:
			counts["power"] += 1
		if f & NO_WATER:
			counts["water"] += 1
		if f & ABANDONED:
			counts["abandoned"] += 1
	return { "flags": flags, "counts": counts }


static func _touches_water(grid: CityGrid, origin: int) -> bool:
	for f in grid.footprint_of(origin):
		if grid.has_water_neighbor(f):
			return true
	return false
