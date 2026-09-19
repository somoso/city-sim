class_name CivicStats
extends RefCounted
## Utilisation figures for the civic services: how much of the population each one actually
## reaches, what it costs, and what that works out at per resident.

## Service groups in the order the panel lists them: id, label, coverage grid field, and
## the budget line it is funded from.
const GROUPS := [
	["police", "Police", "cov_police", "police"],
	["fire", "Fire", "cov_fire", "fire"],
	["health", "Health", "cov_health", "health"],
	["nursery", "Nurseries", "cov_nursery", "school"],
	["school", "High schools", "cov_school", "school"],
	["university", "Universities", "cov_university", "school"],
]


## Returns { id: { label, coverage (0..1), buildings, cost, per_person } }.
static func compute(grid: CityGrid, state) -> Dictionary:
	var out := {}
	var pop_total := 0
	for i in range(grid.size):
		if grid.zone_type[i] == Constants.Zone.RES and grid.level[i] > 0:
			pop_total += grid.population[i]

	for group in GROUPS:
		var id: String = group[0]
		var field: String = group[2]
		var layer: PackedFloat32Array = grid.get(field)
		var covered := 0.0
		if pop_total > 0:
			for i in range(grid.size):
				if grid.zone_type[i] == Constants.Zone.RES and grid.level[i] > 0 and grid.population[i] > 0:
					covered += float(grid.population[i]) * clampf(layer[i], 0.0, 1.0)
		out[id] = {
			"label": group[1],
			"coverage": 0.0 if pop_total == 0 else covered / float(pop_total),
			"buildings": 0,
			"cost": 0.0,
			"per_person": 0.0,
			"funding": group[3],
		}

	# Upkeep is charged per building at its department's funding level, matching Budget.
	for origin in grid.civic_origins():
		var type := grid.building[origin]
		var kind := str(BuildingDefs.def_value(type, "coverage", ""))
		if not out.has(kind):
			continue
		var cost := float(BuildingDefs.def_value(type, "upkeep", 0))
		var funding_key: String = out[kind]["funding"]
		if state.funding.has(funding_key):
			cost *= float(state.funding[funding_key]) / 100.0
		out[kind]["buildings"] += 1
		out[kind]["cost"] += cost

	for id in out.keys():
		out[id]["per_person"] = 0.0 if pop_total == 0 else out[id]["cost"] / float(pop_total)
	out["population"] = pop_total
	return out
