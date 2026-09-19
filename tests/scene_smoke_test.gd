extends Node
## Headless scene test: instantiates the game scene, exercises tools, overlays and panels,
## and lets the clock tick. Catches runtime errors in rendering and UI code paths.
## Run with: godot --headless --path . tests/scene_smoke_test.tscn

var failures := 0
var frames := 0
var game: Node2D
var town := Vector2i.ZERO


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: " + msg)
	else:
		print("ok: " + msg)


func _ready() -> void:
	GameState.new_city(64, 64, 4242, "Scene Test", true)
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)


func _process(_delta: float) -> void:
	frames += 1
	match frames:
		2:
			check(game.terrain_layer.chunks.size() == 16, "terrain chunks created (%d)" % game.terrain_layer.chunks.size())
			var grid: CityGrid = GameState.grid
			var start := TerrainGenerator.find_start_tile(grid)
			var x := clampi(start.x, 2, grid.width - 12)
			var y := clampi(start.y, 2, grid.height - 12)
			game.apply_tool_at(Constants.Tool.ROAD, x, y, x + 9, y)
			game.apply_tool_at(Constants.Tool.ROAD, x, y + 5, x + 9, y + 5)
			game.apply_tool_at(Constants.Tool.ZONE_R_MED, x, y + 1, x + 4, y + 2)
			game.apply_tool_at(Constants.Tool.ZONE_C_HIGH, x + 5, y + 1, x + 9, y + 2)
			game.apply_tool_at(Constants.Tool.ZONE_I_LOW, x, y + 3, x + 9, y + 4)
			town = Vector2i(x, y)
			Events.tile_selected.emit(grid.idx(x, y + 1))
		3:
			# Roads and zones exist but no utilities yet, so the warnings must be up.
			check(game.alerts_layer.has_alerts(), "alerts layer picked up missing services")
			check(game.hud.alert_panel.visible, "HUD problem banner is shown")
			check(game.hud.alert_buttons["power"].visible and game.hud.alert_buttons["water"].visible,
				"power and water rows are listed")
			var before_focus: Vector2 = game.camera.position
			game.focus_alert("power")
			check(game.camera.position != before_focus, "clicking a problem moves the camera")
			game.apply_tool_at(Constants.Tool.POWER_COAL, town.x, town.y - 2, 0, 0)
			game.apply_tool_at(Constants.Tool.WATER_TOWER, town.x + 2, town.y - 1, 0, 0)
			game.apply_tool_at(Constants.Tool.POLICE, town.x + 3, town.y - 2, 0, 0)
			game.apply_tool_at(Constants.Tool.PARK, town.x + 6, town.y - 1, 0, 0)
			GameState.set_speed(3)
			check(game.alerts_layer.counts["power"] < 5, "power alerts clear once a plant is connected (%d left)" % game.alerts_layer.counts["power"])
		4:
			GameState.set_tool(Constants.Tool.ZONE_R_HIGH)
			game.cursor_layer.set_hover(Vector2i(10, 10))
			game.cursor_layer.begin_drag(Vector2i(8, 8))
		5:
			game.cursor_layer.end_drag()
			GameState.set_tool(Constants.Tool.HOSPITAL)
			game.cursor_layer.set_hover(Vector2i(12, 12))
		6:
			GameState.set_tool(Constants.Tool.ROAD)
			game.cursor_layer.begin_drag(Vector2i(5, 5))
			game.cursor_layer.set_hover(Vector2i(9, 9))
		8:
			# The destructive tool group is labelled so it cannot be mistaken for the
			# bulldoze tool itself.
			var names: Array[String] = []
			for entry in game.hud.CATEGORIES:
				names.append(entry[0])
			check("Destruction" in names and not ("Bulldoze" in names), "tool group renamed to Destruction")
			for m in range(24):
				GameState.tick_month()
			check(GameState.population > 0, "population after 2 years: %d (power %d/%d, water %d/%d)" % [
				GameState.population, int(GameState.power_demand), int(GameState.power_supply),
				int(GameState.water_demand), int(GameState.water_supply)])
			game.hud.budget_panel.toggle()
			game.hud.menu_panel.toggle()
			check(GameState.speed == 0, "menu pauses the game")
			game.hud.menu_panel._trigger("meteor")
			check(GameState.speed > 0, "closing menu resumes the game")
		10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22:
			# Cycle through every overlay, one per frame, so each gets drawn.
			var keys := Constants.OVERLAY_NAMES.keys()
			GameState.set_overlay(keys[(frames - 10) % keys.size()])
		24:
			GameState.set_overlay(Constants.Overlay.NONE)
			for m in range(12):
				GameState.tick_month()
			GameState.set_tool(Constants.Tool.QUERY)
			Events.tile_selected.emit(0)
		26:
			# Utilities panel: stats, meters and both charts.
			game.hud.utility_panel.toggle()
			check(game.hud.utility_panel.visible, "utilities panel opens")
			check(game.hud.utility_panel.power_chart.demand.size() > 1, "power chart has history (%d points)" % game.hud.utility_panel.power_chart.demand.size())
			check(game.hud.utility_panel.water_chart.capacity.size() > 1, "water chart has capacity series")
			check(game.hud.utility_panel.power_stat.text.contains("used"), "power stat reads: %s" % game.hud.utility_panel.power_stat.text)
			game.hud.utility_panel.power_chart._hover_index = 3
			game.hud.utility_panel.power_chart.queue_redraw()
			game.hud.utility_panel.water_chart.queue_redraw()
			game.hud.utility_panel.power_meter.queue_redraw()
			check(game.hud.income_label.text.begins_with("+$") and game.hud.expenses_label.text.begins_with("-$"),
				"treasury shows income and expenses (%s, %s)" % [game.hud.income_label.text, game.hud.expenses_label.text])
			check(game.hud.net_label.text.begins_with("net"), "treasury shows net (%s)" % game.hud.net_label.text)
			check(game.hud.population_chart != null, "top bar carries the population graph")
			game.hud.population_chart.queue_redraw()
			var labels: Array[String] = []
			for child in game.hud.get_children():
				if child is PanelContainer:
					continue
			check(not ("power_label" in game.hud), "power/water readouts were removed from the top bar")
		28:
			# Close only the utilities panel; the info panel is checked below.
			game.hud.utility_panel.toggle()
			check(not game.hud.utility_panel.visible, "utilities panel closes")
			check(game.alerts_layer.draw_count >= 3, "alerts layer animated (%d draws)" % game.alerts_layer.draw_count)
			check(game.terrain_layer.draw_count >= 16, "terrain chunks drew (%d)" % game.terrain_layer.draw_count)
			check(game.world_layer.draw_count >= 16, "world chunks drew (%d)" % game.world_layer.draw_count)
			check(game.overlay_layer.draw_count >= 16, "overlay chunks drew (%d)" % game.overlay_layer.draw_count)
			check(game.cursor_layer.draw_count >= 3, "cursor layer drew (%d)" % game.cursor_layer.draw_count)
			check(game.hud.info_panel.visible, "info panel opened on tile select")
			check(game.hud.close_panels(), "close_panels closed the info panel")
			if failures == 0:
				print("ALL SCENE CHECKS PASSED")
			else:
				printerr("%d SCENE CHECK(S) FAILED" % failures)
			get_tree().quit(1 if failures > 0 else 0)
