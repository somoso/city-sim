class_name ZoneGrowth
extends RefCounted
## Develops, upgrades and abandons zoned lots based on demand, services and land value.


static func run(grid: CityGrid, state, rng: RandomNumberGenerator) -> Dictionary:
	var stats := { "grown": 0, "abandoned": 0 }
	var demand_by_zone := {
		Constants.Zone.RES: state.demand["R"],
		Constants.Zone.COM: state.demand["C"],
		Constants.Zone.IND: state.demand["I"],
	}
	for i in range(grid.size):
		var z := grid.zone_type[i]
		if z == Constants.Zone.NONE:
			continue
		if grid.building[i] != Constants.Building.NONE:
			continue # rubble or (illegal) building on a zoned tile
		grid.age[i] += 1
		if grid.burning[i] > 0:
			continue

		var demand: float = demand_by_zone[z]
		var serviced := grid.road_access[i] == 1 and grid.powered[i] == 1 and grid.watered[i] == 1
		var lv := grid.land_value[i]

		if serviced and demand > 0.0:
			var p := (demand / 100.0) * 0.28
			# Undeveloped lots grow a bit faster so new zones fill in.
			if grid.level[i] == 0:
				p *= 1.4
			# Residents want somewhere to work; without jobs growth crawls.
			if z == Constants.Zone.RES and state.jobs_total > 0:
				p *= 0.5 + 0.5 * grid.commute[i]
			# Higher levels need better land value and take longer.
			var next_level := grid.level[i] + 1
			if next_level > grid.zone_density[i]:
				continue
			if next_level >= 2 and lv < 25.0:
				continue
			if next_level >= 3 and lv < 45.0:
				continue
			p *= 1.0 / float(next_level)
			# Pollution and crime discourage residents and shops.
			if z != Constants.Zone.IND:
				p *= clampf(1.0 - grid.pollution[i] / 120.0, 0.1, 1.0)
				p *= clampf(1.0 - grid.crime[i] / 140.0, 0.1, 1.0)
			if rng.randf() < p:
				grid.set_level(i, next_level)
				grid.wealth[i] = _wealth_for(lv)
				stats["grown"] += 1
		elif grid.level[i] > 0:
			var p_decay := 0.0
			if not serviced:
				p_decay = 0.20
			elif demand < -30.0:
				p_decay = (-demand - 30.0) / 70.0 * 0.12
			if z == Constants.Zone.RES and grid.crime[i] > 70.0:
				p_decay += 0.05
			if rng.randf() < p_decay:
				grid.set_level(i, grid.level[i] - 1)
				if grid.level[i] > 0:
					grid.wealth[i] = maxi(1, grid.wealth[i] - 1)
				stats["abandoned"] += 1
		# Wealth drifts toward what the land value supports.
		if grid.level[i] > 0 and grid.age[i] % 6 == 0:
			var target := _wealth_for(lv)
			if target > grid.wealth[i]:
				grid.wealth[i] += 1
			elif target < grid.wealth[i]:
				grid.wealth[i] -= 1
	return stats


static func _wealth_for(land_value: float) -> int:
	if land_value >= 65.0:
		return 3
	if land_value >= 38.0:
		return 2
	return 1
