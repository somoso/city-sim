extends Node
## Headless smoke test: builds a small city, runs the simulation for several years, and
## round-trips a save. Run with:
##   godot --headless --path . tests/sim_smoke_test.tscn

var failures := 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


## Bounding box of the biggest contiguous block of one zone, ignoring roads between them.
func _largest_block(grid: CityGrid, zone: int) -> Vector2i:
	var seen := {}
	var best := Vector2i.ZERO
	for start in range(grid.size):
		if grid.zone_type[start] != zone or seen.has(start):
			continue
		var stack := PackedInt32Array([start])
		seen[start] = true
		var minx := grid.x_of(start)
		var maxx := minx
		var miny := grid.y_of(start)
		var maxy := miny
		while stack.size() > 0:
			var cur := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			minx = mini(minx, grid.x_of(cur))
			maxx = maxi(maxx, grid.x_of(cur))
			miny = mini(miny, grid.y_of(cur))
			maxy = maxi(maxy, grid.y_of(cur))
			for n in grid.neighbors4(cur):
				if not seen.has(n) and grid.zone_type[n] == zone:
					seen[n] = true
					stack.append(n)
		var w := maxx - minx + 1
		var h := maxy - miny + 1
		if w * h > best.x * best.y:
			best = Vector2i(w, h)
	return best


## Editing balance.json has to take effect, and a broken file has to be survivable.
func _check_balance_reload() -> void:
	var path := Balance.USER_FILE
	var before := Balance.num("buildings.landfill.cost", 0.0)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({ "buildings": { "landfill": { "cost": 4321 } } }))
	file.close()
	Balance.reload()
	check(Balance.num("buildings.landfill.cost", 0.0) == 4321.0, "an edited balance file overrides the shipped value")
	check(int(BuildingDefs.def_value(Constants.Building.LANDFILL, "cost", 0)) == 4321, "and the catalogue picks it up")
	check(Balance.num("buildings.landfill.waste_out", 0.0) == 300.0, "untouched keys keep their shipped value")

	# A corrupt override must not take the game down with it.
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	Balance.reload()
	check(Balance.last_error() != "", "a corrupt file is reported (%s)" % Balance.last_error())
	check(Balance.num("buildings.landfill.cost", 0.0) == 4321.0, "and the last good values stay in force")

	DirAccess.remove_absolute(path)
	Balance.reload()
	check(Balance.num("buildings.landfill.cost", 0.0) == before, "removing the override restores the shipped value")
	check(Balance.last_error() == "", "and the error clears")


func _find_land_rect(grid: CityGrid, w: int, h: int) -> Vector2i:
	for y in range(0, grid.height - h):
		for x in range(0, grid.width - w):
			var ok := true
			for dy in range(h):
				for dx in range(w):
					if not grid.is_land(grid.idx(x + dx, y + dy)):
						ok = false
						break
				if not ok:
					break
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _ready() -> void:
	print("Starting simulation smoke test")
	GameState.new_city(48, 48, 12345, "Testville", false)
	var grid: CityGrid = GameState.grid
	check(grid.size == 48 * 48, "grid allocated")

	var land := 0
	for i in range(grid.size):
		if grid.is_land(i):
			land += 1
	check(land > grid.size / 2, "terrain is mostly land (%d/%d)" % [land, grid.size])

	# Find an all-land 20x16 area and build a tiny town on it.
	var origin := _find_land_rect(grid, 20, 16)
	check(origin.x >= 0, "found an all-land build area at %s" % origin)
	var ox := origin.x
	var oy := origin.y
	var tools := BuildTools.new()
	var road_ok := 0
	for x in range(ox, ox + 18):
		if tools.apply_line(Constants.Tool.ROAD, x, oy + 4, x, oy + 4) > 0:
			road_ok += 1
	for x in range(ox, ox + 18):
		tools.apply_line(Constants.Tool.ROAD, x, oy + 9, x, oy + 9)
	for y in range(oy, oy + 14):
		tools.apply_line(Constants.Tool.ROAD, ox + 9, y, ox + 9, y)
	check(road_ok > 10, "roads placed along a line (%d)" % road_ok)

	tools.apply_area(Constants.Tool.ZONE_R_LOW, ox, oy + 5, ox + 8, oy + 6)
	tools.apply_area(Constants.Tool.ZONE_R_MED, ox, oy + 7, ox + 8, oy + 8)
	tools.apply_area(Constants.Tool.ZONE_C_LOW, ox + 10, oy + 5, ox + 17, oy + 6)
	tools.apply_area(Constants.Tool.ZONE_I_LOW, ox + 10, oy + 7, ox + 17, oy + 8)
	tools.apply_area(Constants.Tool.ZONE_I_LOW, ox, oy + 10, ox + 8, oy + 11)

	# Before any utility exists, every zoned lot must raise a missing-power and
	# missing-water alert, including lots that have not developed yet. This is what tells
	# the player why a freshly zoned neighbourhood is doing nothing.
	var dry := Alerts.compute(grid)
	check(dry["counts"]["power"] > 20 and dry["counts"]["water"] > 20,
		"unserviced zones raise power/water alerts (power %d, water %d)" % [dry["counts"]["power"], dry["counts"]["water"]])
	var undeveloped_flagged := 0
	for i in range(grid.size):
		if grid.zone_type[i] != Constants.Zone.NONE and grid.level[i] == 0 and dry["flags"][i] != 0:
			undeveloped_flagged += 1
	check(undeveloped_flagged > 20, "undeveloped lots are flagged too (%d)" % undeveloped_flagged)
	check(dry["flags"][grid.idx(ox + 1, oy + 5)] & Alerts.NO_POWER != 0, "a specific lot reports no power")

	var placed_power := tools.apply_point(Constants.Tool.POWER_COAL, ox, oy + 2)
	var placed_water := tools.apply_point(Constants.Tool.WATER_TOWER, ox + 3, oy + 3)
	if not placed_water:
		var wi := grid.idx(ox + 3, oy + 3)
		print("  water tower blocked: terrain=%d building=%d level=%d" % [grid.terrain[wi], grid.building[wi], grid.level[wi]])
	var placed_wind := tools.apply_point(Constants.Tool.POWER_WIND, ox + 4, oy + 3)
	var placed_fire := tools.apply_point(Constants.Tool.FIRE_STATION, ox + 12, oy + 1)
	tools.apply_point(Constants.Tool.PARK, ox + 5, oy + 3)
	check(placed_power or placed_wind, "a power source was placed")
	check(placed_water, "water tower placed")
	check(placed_fire, "fire station placed")

	var zoned := 0
	for i in range(grid.size):
		if grid.zone_type[i] != Constants.Zone.NONE:
			zoned += 1
	check(zoned > 40, "zones placed (%d)" % zoned)

	# Zoning away from a road now lays the service roads instead of refusing the lots.
	var far_x := ox + 1
	var far_y := oy + 13
	var plan := tools.plan_zone_roads(Constants.Tool.ZONE_R_LOW, far_x, far_y, far_x + 6, far_y + 5)
	check(plan["roads"].size() > 0, "a zone away from a road plans service roads (%d)" % plan["roads"].size())
	check(plan["lots"].size() > 0, "and still plans lots (%d)" % plan["lots"].size())
	var placed := tools.apply_area(Constants.Tool.ZONE_R_LOW, far_x, far_y, far_x + 6, far_y + 5)
	check(placed > 0, "the far district was placed (%d tiles)" % placed)
	var unserved := 0
	for i in range(grid.size):
		if grid.zone_type[i] != Constants.Zone.NONE and grid.road_access[i] == 0:
			unserved += 1
	check(unserved == 0, "every zoned lot has road access after auto-roads (%d without)" % unserved)

	# Denser zones are gated on what the city has built and who lives in it.
	check(Society.growth_blocker(GameState, Constants.Zone.RES, 1) == "", "low housing has no prerequisite")
	check(Society.growth_blocker(GameState, Constants.Zone.RES, 2) != "", "medium housing is blocked without a school")
	tools.apply_point(Constants.Tool.NURSERY, ox + 6, oy + 1)
	Simulation.refresh(grid, GameState)
	check(GameState.has_education_building, "a nursery counts as an education building")
	check(Society.growth_blocker(GameState, Constants.Zone.RES, 2) == "", "medium housing unblocks once one is built")
	check(Society.growth_blocker(GameState, Constants.Zone.RES, 3).contains("high school"), "high housing still wants schooling")
	check(Society.growth_blocker(GameState, Constants.Zone.COM, 3).contains("university"), "high commercial wants graduates")

	# Refuse: homes put it out, and tips take it away.
	check(Constants.zone_waste(1) == 5.0 and Constants.zone_waste(2) == 3.0 and Constants.zone_waste(3) == 7.0,
		"waste per density is 5 / 3 / 7")

	# Commercial blocks are capped at 2 x 5, so a long strip gets a cross street.
	var com_block := _largest_block(grid, Constants.Zone.COM)
	check(mini(com_block.x, com_block.y) <= 2 and maxi(com_block.x, com_block.y) <= 5,
		"largest commercial block is within 2x5 (got %dx%d)" % [com_block.x, com_block.y])

	# Farmland reaches four tiles from a road instead of two.
	check(Constants.access_depth(Constants.Zone.IND, 1) == 4, "agriculture reaches 4 tiles")
	check(Constants.access_depth(Constants.Zone.RES, 1) == 2, "other zones still reach 2")
	check(Constants.zone_label(Constants.Zone.IND, 1) == "Agricultural", "low industrial is labelled agricultural")
	check(Constants.block_limits(Constants.Zone.COM, 1) == Vector2i(2, 5), "commercial block limit is 2x5")
	check(Constants.block_limits(Constants.Zone.IND, 1) == Vector2i(8, 0), "agricultural blocks may run 8 deep")

	var funds_before := GameState.funds
	for m in range(60):
		GameState.tick_month()
	check(GameState.population > 0, "population grew: %d" % GameState.population)
	check(GameState.jobs_total > 0, "jobs appeared: %d" % GameState.jobs_total)
	check(GameState.power_supply > GameState.power_demand, "power supply %.0f exceeds demand %.0f" % [GameState.power_supply, GameState.power_demand])
	print("  demand R/C/I: %.0f / %.0f / %.0f" % [GameState.demand["R"], GameState.demand["C"], GameState.demand["I"]])
	print("  funds %d -> %d (income %.0f, expenses %.0f)" % [funds_before, GameState.funds, GameState.last_income["total"], GameState.last_expenses_total])
	check(GameState.year == Constants.START_YEAR + 5, "five years elapsed")

	var powered := 0
	var developed := 0
	for i in range(grid.size):
		if grid.is_developed(i):
			developed += 1
			if grid.powered[i] == 1:
				powered += 1
	check(developed > 0 and powered == developed, "all developed lots powered (%d/%d)" % [powered, developed])

	# Utilities are tracked per connected network, and the query panel reads them.
	check(GameState.power_networks.size() >= 1, "at least one power network exists (%d)" % GameState.power_networks.size())
	var net_tile := -1
	for i in range(grid.size):
		if grid.is_developed(i) and grid.power_net[i] >= 0:
			net_tile = i
			break
	check(net_tile >= 0, "a developed lot is attached to a power network")
	if net_tile >= 0:
		check(Utilities.tile_power_use(grid, net_tile) > 0.0, "a developed lot draws power (%.0f)" % Utilities.tile_power_use(grid, net_tile))
		var stats: Dictionary = GameState.power_networks[grid.power_net[net_tile]]
		check(stats["supply"] > 0.0, "its network reports a supply (%.0f)" % stats["supply"])

	# The top-bar graph needs residents and the employed share of them.
	check(GameState.employed <= GameState.jobs_total, "employed never exceeds the number of jobs (%d vs %d)" % [GameState.employed, GameState.jobs_total])
	check(GameState.employed <= GameState.population / 2, "employed never exceeds the working-age population")
	check(GameState.employed > 0, "some residents hold jobs (%d)" % GameState.employed)
	check(GameState.population_history.size() == GameState.employed_history.size(), "population and employed history stay in step")

	# Ten years of utilisation history feed the graphs, capped at HISTORY_MONTHS.
	check(GameState.power_demand_history.size() > 12, "power history recorded (%d months)" % GameState.power_demand_history.size())
	check(GameState.power_demand_history.size() <= GameState.HISTORY_MONTHS, "history is capped")
	check(GameState.water_supply_history.size() == GameState.power_demand_history.size(), "all four series stay in step")

	# With power, water and roads in place the alerts must clear for served lots.
	var after := Alerts.compute(grid)
	var served_flagged := 0
	for i in range(grid.size):
		if grid.is_developed(i) and grid.road_access[i] == 1 and grid.powered[i] == 1 and grid.watered[i] == 1:
			if after["flags"][i] != 0:
				served_flagged += 1
	check(served_flagged == 0, "fully served lots raise no alert (%d did)" % served_flagged)
	check(Alerts.mask_for("power") == Alerts.NO_POWER and Alerts.mask_for("nope") == Alerts.NONE, "alert kind lookup")

	# Refuse has to be collected once homes exist.
	Waste.run(grid, GameState)
	check(GameState.waste_production > 0.0, "homes produce refuse (%.0f units)" % GameState.waste_production)
	check(GameState.waste_capacity == 0.0 and GameState.waste_served < 1.0, "with no tip, refuse goes uncollected")
	var tip := tools.apply_point(Constants.Tool.LANDFILL, ox + 14, oy + 1)
	check(tip, "landfill placed")
	Simulation.refresh(grid, GameState)
	check(GameState.waste_capacity > 0.0, "the landfill adds capacity (%.0f units)" % GameState.waste_capacity)
	var refuse_alerts := Alerts.compute(grid, GameState)
	check(refuse_alerts["counts"].has("waste"), "refuse is an alert kind")

	# A demolition depot clears derelict lots on its own.
	check(Demolition.batch_size() == 100, "demolition clears 100 lots at a time")
	check(Demolition.cooldown_seconds() == 30.0, "and rests 30 seconds between sweeps")

	# Cutting the power off must make lots decay and report themselves as abandoned.
	for i in range(grid.size):
		if grid.building[i] == Constants.Building.POWER_COAL or grid.building[i] == Constants.Building.POWER_WIND:
			tools.apply_area(Constants.Tool.BULLDOZE, grid.x_of(i), grid.y_of(i), grid.x_of(i), grid.y_of(i))
	for m in range(36):
		GameState.tick_month()
	var abandoned_tiles := 0
	for i in range(grid.size):
		if grid.abandoned[i] == 1:
			abandoned_tiles += 1
	check(abandoned_tiles > 0, "lots are marked abandoned after losing power (%d)" % abandoned_tiles)
	var cut := Alerts.compute(grid)
	check(cut["counts"]["abandoned"] == abandoned_tiles, "abandoned lots are reported as alerts (%d)" % cut["counts"]["abandoned"])

	check(not Demolition.has_working_depot(grid), "no depot yet")
	tools.apply_point(Constants.Tool.DEMOLITION_DEPOT, ox + 16, oy + 1)
	Simulation.refresh(grid, GameState)
	var swept := Demolition.sweep(grid, Demolition.batch_size())
	check(swept.size() > 0 and swept.size() <= 100, "a sweep clears up to 100 lots (%d)" % swept.size())
	var still_derelict := 0
	for i in range(grid.size):
		if grid.abandoned[i] == 1:
			still_derelict += 1
	check(still_derelict < abandoned_tiles, "derelict lots go down after a sweep (%d left of %d)" % [still_derelict, abandoned_tiles])


	# Disasters must not crash.
	GameState.post_message(FireSim.trigger_tornado(grid, GameState.rng))
	GameState.post_message(FireSim.trigger_meteor(grid, GameState.rng))
	GameState.post_message(FireSim.trigger_fire(grid, GameState.rng))
	for m in range(12):
		GameState.tick_month()
	check(true, "survived disasters")

	# Save / load round trip.
	var pop_before := GameState.population
	var funds_saved := GameState.funds
	var history_before := GameState.power_demand_history.size()
	var abandoned_before := 0
	for i in range(grid.size):
		if grid.abandoned[i] == 1:
			abandoned_before += 1

	# Balance values come from data/balance.json and fall back to the code on a bad file.
	check(Balance.num("buildings.landfill.waste_out", 0.0) == 300.0, "balance.json supplies the landfill capacity")
	check(Balance.num("buildings.nonexistent.cost", 1234.0) == 1234.0, "a missing key falls back")
	check(Balance.nums("zones.res.waste", [0.0, 1.0, 1.0, 1.0]) == [0.0, 5.0, 3.0, 7.0], "and arrays load")
	check(int(BuildingDefs.def_value(Constants.Building.DEMOLITION_DEPOT, "cost", 0)) == 10000, "the depot costs $10,000")
	check(int(BuildingDefs.def_value(Constants.Building.DEMOLITION_DEPOT, "upkeep", 0)) == 300, "and $300 a month")
	_check_balance_reload()
	check(SaveManager.save_city("smoke_test"), "saved city")
	GameState.new_city(32, 32, 1, "Other", false)
	check(SaveManager.load_city("smoke_test"), "loaded city")
	check(GameState.grid.width == 48, "loaded grid width")
	check(GameState.funds == funds_saved, "funds restored")
	check(GameState.population == pop_before, "population restored (%d vs %d)" % [GameState.population, pop_before])
	check(GameState.power_demand_history.size() == history_before, "utilisation history restored (%d)" % GameState.power_demand_history.size())
	var abandoned_after := 0
	for i in range(GameState.grid.size):
		if GameState.grid.abandoned[i] == 1:
			abandoned_after += 1
	check(abandoned_after == abandoned_before, "abandoned lots survive a save/load (%d vs %d)" % [abandoned_after, abandoned_before])
	check("smoke_test" in SaveManager.list_saves(), "save listed")
	SaveManager.delete_save("smoke_test")

	if failures == 0:
		print("ALL CHECKS PASSED")
	else:
		printerr("%d CHECK(S) FAILED" % failures)
	get_tree().quit(1 if failures > 0 else 0)
