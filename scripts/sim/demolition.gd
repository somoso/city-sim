class_name Demolition
extends RefCounted
## The demolition depot: standing crews that clear derelict lots and rubble without the
## player having to bulldoze each one by hand.

const BATCH := 100
const COOLDOWN_SECONDS := 30.0


static func batch_size() -> int:
	return Balance.int_val("auto_demolish.batch", BATCH)


static func cooldown_seconds() -> float:
	return Balance.num("auto_demolish.cooldown_seconds", COOLDOWN_SECONDS)


## True when the city has at least one depot that is able to work.
static func has_working_depot(grid: CityGrid) -> bool:
	for origin in grid.civic_origins():
		if grid.building[origin] != Constants.Building.DEMOLITION_DEPOT:
			continue
		if grid.burning[origin] > 0:
			continue
		if grid.powered[origin] == 1:
			return true
	return false


## Tiles the crews would clear: derelict lots first, then leftover rubble.
static func targets(grid: CityGrid, limit: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in range(grid.size):
		if out.size() >= limit:
			return out
		if grid.abandoned[i] == 1:
			out.append(i)
	for i in range(grid.size):
		if out.size() >= limit:
			return out
		if grid.building[i] == Constants.Building.RUBBLE:
			out.append(i)
	return out


## Clears up to `limit` tiles and returns the ones that changed.
static func sweep(grid: CityGrid, limit: int) -> PackedInt32Array:
	var cleared := targets(grid, limit)
	for i in cleared:
		if grid.building[i] == Constants.Building.RUBBLE:
			grid.building[i] = Constants.Building.NONE
			grid.owner[i] = -1
		grid.abandoned[i] = 0
		grid.age[i] = 0
	return cleared
