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

	# Zoning far from any road must be refused, and the preview must agree.
	var far_reach := tools.zone_reachability(Constants.Tool.ZONE_R_LOW, ox + 2, oy + 13, ox + 6, oy + 15)
	var far_ok := 0
	for v in far_reach.values():
		if v:
			far_ok += 1
	check(far_reach.size() > 0 and far_ok == 0, "lots far from roads are unreachable in preview (%d/%d)" % [far_ok, far_reach.size()])
	var far_placed := tools.apply_area(Constants.Tool.ZONE_R_LOW, ox + 2, oy + 13, ox + 6, oy + 15)
	check(far_placed == 0, "zone tool skipped unreachable lots (%d placed)" % far_placed)
	# Two rows next to a road are fine: row 1 touches it, row 2 reaches through row 1.
	var near_reach := tools.zone_reachability(Constants.Tool.ZONE_C_LOW, ox + 12, oy + 10, ox + 14, oy + 11)
	var near_ok := 0
	for v in near_reach.values():
		if v:
			near_ok += 1
	check(near_ok == near_reach.size() and near_ok > 0, "lots within two tiles of a road are reachable (%d)" % near_ok)
	for i in range(grid.size):
		if grid.zone_type[i] != Constants.Zone.NONE and grid.road_access[i] == 0:
			check(false, "a zoned lot has no road access after zoning")
			break

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

	# With power, water and roads in place the alerts must clear for served lots.
	var after := Alerts.compute(grid)
	var served_flagged := 0
	for i in range(grid.size):
		if grid.is_developed(i) and grid.road_access[i] == 1 and grid.powered[i] == 1 and grid.watered[i] == 1:
			if after["flags"][i] != 0:
				served_flagged += 1
	check(served_flagged == 0, "fully served lots raise no alert (%d did)" % served_flagged)
	check(Alerts.mask_for("power") == Alerts.NO_POWER and Alerts.mask_for("nope") == Alerts.NONE, "alert kind lookup")

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
	check(SaveManager.save_city("smoke_test"), "saved city")
	GameState.new_city(32, 32, 1, "Other", false)
	check(SaveManager.load_city("smoke_test"), "loaded city")
	check(GameState.grid.width == 48, "loaded grid width")
	check(GameState.funds == funds_saved, "funds restored")
	check(GameState.population == pop_before, "population restored (%d vs %d)" % [GameState.population, pop_before])
	check("smoke_test" in SaveManager.list_saves(), "save listed")
	SaveManager.delete_save("smoke_test")

	if failures == 0:
		print("ALL CHECKS PASSED")
	else:
		printerr("%d CHECK(S) FAILED" % failures)
	get_tree().quit(1 if failures > 0 else 0)
