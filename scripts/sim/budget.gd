class_name Budget
extends RefCounted
## Monthly income from taxes and expenses from building upkeep and department funding.


static func run(grid: CityGrid, state) -> void:
	var income_r := 0.0
	var income_c := 0.0
	var income_i := 0.0
	var upkeep := { "roads": 0.0, "power": 0.0, "water": 0.0, "police": 0.0, "fire": 0.0,
		"school": 0.0, "health": 0.0, "park": 0.0 }

	for i in range(grid.size):
		if grid.is_developed(i):
			var w := float(grid.wealth[i])
			match grid.zone_type[i]:
				Constants.Zone.RES:
					income_r += float(grid.population[i]) * (0.35 + 0.30 * w) * float(state.tax["R"]) / 100.0 * 6.0
				Constants.Zone.COM:
					income_c += float(grid.jobs[i]) * (0.5 + 0.35 * w) * float(state.tax["C"]) / 100.0 * 7.0
				Constants.Zone.IND:
					income_i += float(grid.jobs[i]) * 0.9 * float(state.tax["I"]) / 100.0 * 7.0
		if grid.is_road(i):
			upkeep["roads"] += float(BuildingDefs.def_value(Constants.Building.ROAD, "upkeep", 0))

	for origin in grid.civic_origins():
		var type := grid.building[origin]
		var def := BuildingDefs.get_def(type)
		var base := float(def.get("upkeep", 0))
		var kind: String = def.get("coverage", "")
		if kind == "":
			if def.has("power_out"):
				kind = "power"
			elif def.has("water_out"):
				kind = "water"
		if state.funding.has(kind):
			base *= float(state.funding[kind]) / 100.0
		if upkeep.has(kind):
			upkeep[kind] += base
		else:
			upkeep["roads"] += base

	var income := income_r + income_c + income_i
	var expenses := 0.0
	for k in upkeep.keys():
		expenses += upkeep[k]

	state.last_income = { "R": income_r, "C": income_c, "I": income_i, "total": income }
	state.last_expenses = upkeep
	state.last_expenses_total = expenses
	state.funds += int(round(income - expenses))
