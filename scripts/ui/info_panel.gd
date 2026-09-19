class_name InfoPanel
extends PanelContainer
## Shows details for the selected tile.

var body: Label
var title: Label
var selected := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Anchored below the problems banner, which sits under the top bar.
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	offset_left = 10
	offset_right = 344
	offset_top = 200
	offset_bottom = 200
	grow_vertical = Control.GROW_DIRECTION_END
	custom_minimum_size = Vector2(334, 0)
	visible = false
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	add_child(margin)
	var col := VBoxContainer.new()
	margin.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "x"
	close.pressed.connect(hide_panel)
	head.add_child(close)
	body = Label.new()
	body.add_theme_font_size_override("font_size", 13)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	Events.tile_selected.connect(show_tile)
	Events.month_ticked.connect(func() -> void:
		if visible and selected >= 0:
			_refresh())
	Events.world_changed.connect(func() -> void:
		if visible and selected >= 0:
			_refresh())
	Events.city_started.connect(hide_panel)


func hide_panel() -> void:
	visible = false
	selected = -1


func show_tile(i: int) -> void:
	selected = i
	visible = true
	_refresh()


## Power and water for the selected tile: what it draws or produces, whether it is being
## served, and how loaded the network it sits on actually is. Utilities are per-network,
## so the city-wide totals in the top bar can look fine while one grid is starved.
func _utility_lines(grid: CityGrid, i: int) -> Array[String]:
	var lines: Array[String] = []
	if not grid.conducts(i):
		return lines
	# Only the origin tile of a multi-tile building reports its output, so a 3x3 plant
	# does not claim to produce its full output nine times over.
	var origin_tile := grid.owner[i] == i or not grid.has_civic(i)
	lines.append("")
	lines.append("Utilities")
	for entry in [
			["Power", "MW", grid.powered, grid.power_net, GameState.power_networks,
				Utilities.tile_power_use(grid, i),
				float(BuildingDefs.def_value(grid.building[i], "power_out", 0)) if origin_tile else 0.0],
			["Water", "units", grid.watered, grid.water_net, GameState.water_networks,
				Utilities.tile_water_use(grid, i),
				float(BuildingDefs.def_value(grid.building[i], "water_out", 0)) if origin_tile else 0.0]]:
		var name: String = entry[0]
		var unit: String = entry[1]
		var served: PackedInt32Array = entry[2]
		var nets: PackedInt32Array = entry[3]
		var stats: Array = entry[4]
		var use: float = entry[5]
		var out: float = entry[6]
		var bits: Array[String] = []
		if out > 0.0:
			bits.append("produces %d %s" % [int(out), unit])
		if use > 0.0:
			bits.append("uses %d %s" % [int(use), unit])
		if bits.is_empty():
			bits.append("no draw")
		bits.append("supplied" if served[i] == 1 else "NOT SUPPLIED")
		lines.append("  %s: %s" % [name, ", ".join(bits)])
		var net_id := nets[i] if i < nets.size() else -1
		if net_id >= 0 and net_id < stats.size():
			var supply: float = stats[net_id]["supply"]
			var demand: float = stats[net_id]["demand"]
			var pct := 0 if supply <= 0.0 else int(round(demand / supply * 100.0))
			lines.append("    net %d/%d: %d/%d %s (%d%%)" % [
				net_id + 1, stats.size(), int(round(demand)), int(round(supply)), unit, pct])
		else:
			lines.append("    not connected to a %s source" % name.to_lower())
	var refuse := Waste.tile_waste(grid, i)
	var capacity := float(BuildingDefs.def_value(grid.building[i], "waste_out", 0)) if origin_tile else 0.0
	if refuse > 0.0 or capacity > 0.0:
		if capacity > 0.0:
			lines.append("  Refuse: processes %d units" % int(capacity))
		if refuse > 0.0:
			var collected := int(round(refuse * GameState.waste_served))
			lines.append("  Refuse: puts out %d units, %d collected" % [int(refuse), collected])
		lines.append("    city-wide: %d of %d units handled" % [
			int(round(minf(GameState.waste_production, GameState.waste_capacity))),
			int(round(GameState.waste_production))])
	return lines


func _refresh() -> void:
	var grid := GameState.grid
	if grid == null or selected < 0 or selected >= grid.size:
		hide_panel()
		return
	var i := selected
	var x := grid.x_of(i)
	var y := grid.y_of(i)
	var lines: Array[String] = []
	var terrain_names := ["Water", "Grass", "Forest", "Sand"]
	title.text = "Tile %d, %d" % [x, y]
	lines.append("Terrain: %s (elev %d%%)" % [terrain_names[grid.terrain[i]], int(grid.elevation[i] * 100)])

	var b := grid.building[i]
	if b == Constants.Building.ROAD:
		lines.append("Road, traffic %d%%" % int(grid.traffic[i]))
	elif b == Constants.Building.RUBBLE:
		lines.append("Rubble. Bulldoze to clear.")
	elif b != Constants.Building.NONE:
		var def := BuildingDefs.get_def(b)
		lines.append("%s" % def.get("name", "Building"))
		lines.append(str(def.get("desc", "")))
		lines.append("Upkeep $%d/month" % def.get("upkeep", 0))
		var origin := grid.owner[i] if grid.owner[i] >= 0 else i
		if def.has("power_out"):
			lines.append("Power output: %d" % def["power_out"])
		if def.has("water_out"):
			var producing: int = int(def["water_out"])
			if def.get("needs_water", false):
				var ok := false
				for f in grid.footprint_of(origin):
					if grid.has_water_neighbor(f):
						ok = true
				if not ok:
					producing = 0
					lines.append("Not adjacent to water: producing nothing!")
			lines.append("Water output: %d" % producing)
		if def.get("power_use", 0) > 0:
			lines.append("Powered: %s" % ("yes" if grid.powered[origin] == 1 else "NO"))

	var z := grid.zone_type[i]
	if z != Constants.Zone.NONE:
		if z == Constants.Zone.IND and grid.zone_density[i] == 1:
			lines.append("Agricultural zone")
		else:
			lines.append("%s zone, %s density" % [Constants.ZONE_NAMES[z], Constants.DENSITY_NAMES[grid.zone_density[i]].to_lower()])
		if grid.level[i] > 0:
			lines.append("Developed level %d, %s" % [grid.level[i], Constants.WEALTH_NAMES[grid.wealth[i]].to_lower()])
			if grid.population[i] > 0:
				lines.append("Residents: %d" % grid.population[i])
			if grid.jobs[i] > 0:
				lines.append("Jobs: %d" % grid.jobs[i])
		elif grid.abandoned[i] == 1:
			lines.append("ABANDONED - this lot lost its building.")
		else:
			lines.append("Undeveloped lot")
		lines.append("Road access: %s" % ("yes" if grid.road_access[i] == 1 else "NO"))
		var blocker := Society.growth_blocker(GameState, z, grid.zone_density[i])
		if blocker != "":
			lines.append("Will not develop: %s" % blocker)
		if z == Constants.Zone.RES:
			lines.append("Job access: %d%%" % int(grid.commute[i] * 100))
	if grid.burning[i] > 0:
		lines.append("ON FIRE!")

	lines.append_array(_utility_lines(grid, i))

	lines.append("")
	lines.append("Land value %d   Pollution %d" % [int(grid.land_value[i]), int(grid.pollution[i])])
	lines.append("Crime %d   Fire risk %d" % [int(grid.crime[i]), int(grid.fire_risk[i])])
	lines.append("Police %d%%  Fire %d%%  School %d%%  Health %d%%" % [
		int(grid.cov_police[i] * 100), int(grid.cov_fire[i] * 100),
		int(grid.cov_school[i] * 100), int(grid.cov_health[i] * 100)])
	body.text = "\n".join(lines)
