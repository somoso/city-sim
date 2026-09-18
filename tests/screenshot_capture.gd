extends Node
## Builds a demo town, runs it for a few years and saves screenshots of the viewport.
## Useful for eyeballing the renderer without playing. Run under a display (or Xvfb):
##   godot --path . tests/screenshot_capture.tscn -- --out=/tmp/shots
## Screenshots are written to the --out directory (default: user://screenshots).

var frames := 0
var game: Node2D
var out_dir := "user://screenshots"
var shot := 0
var town_origin := Vector2i.ZERO


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.new_city(64, 64, 20240918, "Demoville", false)
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)


func _build_town() -> void:
	var grid: CityGrid = GameState.grid
	var origin := Vector2i(-1, -1)
	# Find an all-land 22x18 block.
	for y in range(0, grid.height - 18):
		for x in range(0, grid.width - 22):
			var ok := true
			for dy in range(18):
				for dx in range(22):
					if not grid.is_land(grid.idx(x + dx, y + dy)):
						ok = false
						break
				if not ok:
					break
			if ok:
				origin = Vector2i(x, y)
				break
		if origin.x >= 0:
			break
	if origin.x < 0:
		origin = TerrainGenerator.find_start_tile(grid)
	var ox := origin.x
	var oy := origin.y
	town_origin = origin
	GameState.funds = 200000
	var T := Constants.Tool
	# Grid of roads.
	for k in range(0, 4):
		game.apply_tool_at(T.ROAD, ox, oy + 2 + k * 4, ox + 20, oy + 2 + k * 4)
	game.apply_tool_at(T.ROAD, ox + 10, oy + 2, ox + 10, oy + 14)
	game.apply_tool_at(T.ROAD, ox, oy + 2, ox, oy + 14)
	game.apply_tool_at(T.ROAD, ox + 20, oy + 2, ox + 20, oy + 14)
	# Zones between the roads.
	game.apply_tool_at(T.ZONE_R_LOW, ox + 1, oy + 3, ox + 9, oy + 5)
	game.apply_tool_at(T.ZONE_R_MED, ox + 1, oy + 7, ox + 9, oy + 9)
	game.apply_tool_at(T.ZONE_R_HIGH, ox + 1, oy + 11, ox + 9, oy + 13)
	game.apply_tool_at(T.ZONE_C_LOW, ox + 11, oy + 3, ox + 15, oy + 5)
	game.apply_tool_at(T.ZONE_C_HIGH, ox + 11, oy + 7, ox + 19, oy + 9)
	game.apply_tool_at(T.ZONE_I_LOW, ox + 16, oy + 3, ox + 19, oy + 5)
	game.apply_tool_at(T.ZONE_I_MED, ox + 11, oy + 11, ox + 19, oy + 13)
	# Utilities and services along the top road.
	game.apply_tool_at(T.POWER_COAL, ox + 1, oy, 0, 0)
	game.apply_tool_at(T.WATER_TOWER, ox + 4, oy + 1, 0, 0)
	game.apply_tool_at(T.WATER_TOWER, ox + 5, oy + 1, 0, 0)
	game.apply_tool_at(T.POWER_WIND, ox + 6, oy + 1, 0, 0)
	game.apply_tool_at(T.WATER_TOWER, ox + 7, oy + 1, 0, 0)
	game.apply_tool_at(T.FIRE_STATION, ox + 8, oy, 0, 0)
	game.apply_tool_at(T.POLICE, ox + 12, oy, 0, 0)
	game.apply_tool_at(T.SCHOOL, ox + 15, oy, 0, 0)
	game.apply_tool_at(T.PARK, ox + 18, oy + 1, 0, 0)
	game.apply_tool_at(T.PARK, ox + 19, oy + 1, 0, 0)
	game.apply_tool_at(T.HOSPITAL, ox + 1, oy + 15, 0, 0)
	game.camera.focus_tile(Vector2i(ox + 10, oy + 8))
	game.camera.zoom = Vector2(0.5, 0.5)
	GameState.set_speed(0)


func _save_shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, name]
	var err := img.save_png(path)
	print("screenshot %s -> %s (%s)" % [name, path, error_string(err)])


func _process(_delta: float) -> void:
	frames += 1
	match frames:
		3:
			_build_town()
		8:
			_save_shot("01_fresh_zones")
		9:
			for m in range(48):
				GameState.tick_month()
			print("after 4 years: pop %d jobs %d funds %d" % [GameState.population, GameState.jobs_total, GameState.funds])
		14:
			_save_shot("02_grown_city")
			GameState.set_overlay(Constants.Overlay.WATER)
		18:
			_save_shot("03_water_overlay")
			GameState.set_overlay(Constants.Overlay.NONE)
			Events.tile_selected.emit(GameState.grid.idx(town_origin.x + 2, town_origin.y + 4))
			game.hud.budget_panel.toggle()
			GameState.set_tool(Constants.Tool.ZONE_R_HIGH)
			game.cursor_layer.begin_drag(Vector2i(town_origin.x + 2, town_origin.y + 18))
			game.cursor_layer.set_hover(Vector2i(town_origin.x + 9, town_origin.y + 23))
		22:
			_save_shot("04_ui_panels")
			game.hud.close_panels()
			game.cursor_layer.end_drag()
			GameState.set_tool(Constants.Tool.NONE)
			game.hud.menu_panel._trigger("tornado")
			game.hud.menu_panel._trigger("fire")
			for m in range(2):
				GameState.tick_month()
		26:
			_save_shot("05_disaster")
			game.cursor_layer.visible = false
		28:
			_save_shot("06_no_cursor")
			game.cursor_layer.visible = true
			game.hud.visible = false
		30:
			_save_shot("07_no_hud")
			game.hud.visible = true
			# Enlarged crop of the bottom-right corner for close inspection.
			var img := get_viewport().get_texture().get_image()
			var crop := img.get_region(Rect2i(960, 540, 320, 180))
			crop.resize(960, 540, Image.INTERPOLATE_NEAREST)
			crop.save_png("%s/08_crop_bottom_right.png" % out_dir)
			get_tree().quit(0)
