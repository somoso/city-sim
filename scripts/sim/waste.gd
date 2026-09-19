class_name Waste
extends RefCounted
## Refuse collection. Homes put out waste every month; landfills, incinerators and
## recycling centres take it away.
##
## Unlike power and water this is a city-wide service rather than a per-network one:
## collection lorries use the road network, so anything with road access is collected as
## long as the city has the capacity to process it. When it does not, the shortfall shows
## up as pollution and holds development back.

const B := Constants.Building
## Buildings that process refuse.
const PLANTS := [B.LANDFILL, B.INCINERATOR, B.RECYCLING_CENTRE]


## Fills state.waste_production, waste_capacity and waste_served (0..1).
static func run(grid: CityGrid, state) -> void:
	var production := 0.0
	for i in range(grid.size):
		production += tile_waste(grid, i)

	var capacity := 0.0
	for origin in grid.civic_origins():
		var type := grid.building[origin]
		var out := float(BuildingDefs.def_value(type, "waste_out", 0))
		if out <= 0.0 or grid.burning[origin] > 0:
			continue
		# A plant that needs power and has none runs at a crawl.
		if float(BuildingDefs.def_value(type, "power_use", 0)) > 0.0 and grid.powered[origin] == 0:
			out *= 0.25
		capacity += out

	state.waste_production = production
	state.waste_capacity = capacity
	state.waste_served = 1.0 if production <= 0.0 else clampf(capacity / production, 0.0, 1.0)


## Waste a single tile puts out per month, for the query panel.
static func tile_waste(grid: CityGrid, i: int) -> float:
	if grid.zone_type[i] != Constants.Zone.RES or grid.level[i] <= 0:
		return 0.0
	return Constants.zone_waste(grid.zone_density[i]) * float(grid.level[i])
