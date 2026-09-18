class_name InfoPanel
extends PanelContainer
## Shows details for the selected tile.

var body: Label
var title: Label
var selected := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	position = Vector2(10, -170)
	custom_minimum_size = Vector2(260, 0)
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
		lines.append("%s zone, %s density" % [Constants.ZONE_NAMES[z], Constants.DENSITY_NAMES[grid.zone_density[i]].to_lower()])
		if grid.level[i] > 0:
			lines.append("Developed level %d, %s" % [grid.level[i], Constants.WEALTH_NAMES[grid.wealth[i]].to_lower()])
			if grid.population[i] > 0:
				lines.append("Residents: %d" % grid.population[i])
			if grid.jobs[i] > 0:
				lines.append("Jobs: %d" % grid.jobs[i])
		else:
			lines.append("Undeveloped lot")
		var needs: Array[String] = []
		if grid.road_access[i] == 0:
			needs.append("road access")
		if grid.powered[i] == 0:
			needs.append("power")
		if grid.watered[i] == 0:
			needs.append("water")
		if needs.is_empty():
			lines.append("Services: road, power, water OK")
		else:
			lines.append("Missing: %s" % ", ".join(needs))
		if z == Constants.Zone.RES:
			lines.append("Job access: %d%%" % int(grid.commute[i] * 100))
	if grid.burning[i] > 0:
		lines.append("ON FIRE!")

	lines.append("")
	lines.append("Land value %d   Pollution %d" % [int(grid.land_value[i]), int(grid.pollution[i])])
	lines.append("Crime %d   Fire risk %d" % [int(grid.crime[i]), int(grid.fire_risk[i])])
	lines.append("Police %d%%  Fire %d%%  School %d%%  Health %d%%" % [
		int(grid.cov_police[i] * 100), int(grid.cov_fire[i] * 100),
		int(grid.cov_school[i] * 100), int(grid.cov_health[i] * 100)])
	body.text = "\n".join(lines)
