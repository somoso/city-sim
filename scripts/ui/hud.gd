extends CanvasLayer
## Builds and updates the in-game interface: top status bar, toolbar, overlay picker,
## news ticker, and the info / budget / menu panels.

const T := Constants.Tool

const CATEGORIES := [
	["Query", [T.QUERY]],
	["Bulldoze", [T.BULLDOZE, T.DEZONE]],
	["Roads", [T.ROAD]],
	["Residential", [T.ZONE_R_LOW, T.ZONE_R_MED, T.ZONE_R_HIGH]],
	["Commercial", [T.ZONE_C_LOW, T.ZONE_C_MED, T.ZONE_C_HIGH]],
	["Industrial", [T.ZONE_I_LOW, T.ZONE_I_MED, T.ZONE_I_HIGH]],
	["Utilities", [T.POWER_COAL, T.POWER_WIND, T.POWER_NUCLEAR, T.WATER_PUMP, T.WATER_TOWER]],
	["Civic", [T.POLICE, T.FIRE_STATION, T.SCHOOL, T.HOSPITAL, T.PARK]],
]

const SHORT_NAMES := {
	T.QUERY: "Query", T.BULLDOZE: "Bulldoze", T.DEZONE: "De-zone", T.ROAD: "Road",
	T.ZONE_R_LOW: "Low", T.ZONE_R_MED: "Medium", T.ZONE_R_HIGH: "High",
	T.ZONE_C_LOW: "Low", T.ZONE_C_MED: "Medium", T.ZONE_C_HIGH: "High",
	T.ZONE_I_LOW: "Low", T.ZONE_I_MED: "Medium", T.ZONE_I_HIGH: "High",
	T.POWER_COAL: "Coal Plant", T.POWER_WIND: "Wind Turbine", T.POWER_NUCLEAR: "Nuclear Plant",
	T.WATER_PUMP: "Water Pump", T.WATER_TOWER: "Water Tower",
	T.POLICE: "Police", T.FIRE_STATION: "Fire Station", T.SCHOOL: "School",
	T.HOSPITAL: "Hospital", T.PARK: "Park",
}

var city_label: Label
var funds_label: Label
var date_label: Label
var pop_label: Label
var jobs_label: Label
var power_label: Label
var water_label: Label
var speed_buttons: Array[Button] = []
var speed_group := ButtonGroup.new()

var item_row: HBoxContainer
var category_buttons: Array[Button] = []
var tool_group := ButtonGroup.new()
var tool_hint: Label
var overlay_select: OptionButton

var news_label: Label
var news_timer: Timer

var info_panel: InfoPanel
var budget_panel: BudgetPanel
var menu_panel: GameMenu


func _ready() -> void:
	layer = 10
	_build_top_bar()
	_build_toolbar()
	_build_overlay_picker()
	_build_news()
	info_panel = InfoPanel.new()
	add_child(info_panel)
	budget_panel = BudgetPanel.new()
	add_child(budget_panel)
	menu_panel = GameMenu.new()
	add_child(menu_panel)

	Events.month_ticked.connect(_refresh_stats)
	Events.funds_changed.connect(func(_f: int) -> void: _refresh_stats())
	Events.speed_changed.connect(_refresh_speed)
	Events.tool_changed.connect(_refresh_tool)
	Events.message.connect(_show_news)
	Events.city_started.connect(_refresh_all)
	_refresh_all()


func _process(_delta: float) -> void:
	var day := int(get_parent().month_progress() * 30.0) + 1
	date_label.text = "%s %d, %d" % [Constants.MONTH_NAMES[GameState.month], day, GameState.year]


# --- Construction -----------------------------------------------------------------

func _panel(preset: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.set_anchors_and_offsets_preset(preset)
	return p


func _label(text: String, size: int = 14) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _vsep() -> VSeparator:
	return VSeparator.new()


func _build_top_bar() -> void:
	var panel := _panel(Control.PRESET_TOP_WIDE)
	panel.name = "TopBar"
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	city_label = _label("City", 16)
	row.add_child(city_label)
	row.add_child(_vsep())
	funds_label = _label("$0", 16)
	funds_label.tooltip_text = "City treasury. Click Budget to adjust taxes and funding."
	row.add_child(funds_label)
	row.add_child(_vsep())
	date_label = _label("Jan 1, 2000", 14)
	date_label.custom_minimum_size.x = 120
	row.add_child(date_label)
	row.add_child(_vsep())
	pop_label = _label("Pop 0")
	row.add_child(pop_label)
	jobs_label = _label("Jobs 0")
	row.add_child(jobs_label)
	row.add_child(_vsep())
	power_label = _label("Power 0/0")
	power_label.tooltip_text = "Power demand / supply"
	row.add_child(power_label)
	water_label = _label("Water 0/0")
	water_label.tooltip_text = "Water demand / supply"
	row.add_child(water_label)
	row.add_child(_vsep())
	var gauge := RCIGauge.new()
	row.add_child(gauge)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var speed_names := ["||", "1x", "2x", "3x"]
	for s in range(4):
		var b := Button.new()
		b.text = speed_names[s]
		b.toggle_mode = true
		b.button_group = speed_group
		b.tooltip_text = ["Pause (Space)", "Normal speed (1)", "Fast (2)", "Fastest (3)"][s]
		b.pressed.connect(func() -> void: GameState.set_speed(s))
		row.add_child(b)
		speed_buttons.append(b)
	row.add_child(_vsep())
	var budget_btn := Button.new()
	budget_btn.text = "Budget"
	budget_btn.pressed.connect(func() -> void: budget_panel.toggle())
	row.add_child(budget_btn)
	var menu_btn := Button.new()
	menu_btn.text = "Menu"
	menu_btn.pressed.connect(func() -> void: menu_panel.toggle())
	row.add_child(menu_btn)


func _build_toolbar() -> void:
	var panel := _panel(Control.PRESET_BOTTOM_WIDE)
	panel.name = "Toolbar"
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var col := VBoxContainer.new()
	margin.add_child(col)

	var item_wrap := HBoxContainer.new()
	col.add_child(item_wrap)
	item_row = HBoxContainer.new()
	item_row.add_theme_constant_override("separation", 6)
	item_wrap.add_child(item_row)
	tool_hint = _label("", 12)
	tool_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tool_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tool_hint.modulate = Color(1, 1, 1, 0.8)
	item_wrap.add_child(tool_hint)

	var cat_row := HBoxContainer.new()
	cat_row.add_theme_constant_override("separation", 6)
	col.add_child(cat_row)
	var cat_group := ButtonGroup.new()
	for c in CATEGORIES:
		var b := Button.new()
		b.text = c[0]
		b.toggle_mode = true
		b.button_group = cat_group
		var tools_in: Array = c[1]
		b.pressed.connect(func() -> void: _show_category(tools_in))
		cat_row.add_child(b)
		category_buttons.append(b)
	_show_category(CATEGORIES[0][1])
	tool_hint.text = "Left-drag to zone or lay roads. Right-click cancels. WASD pans, wheel zooms."


func _show_category(tools_in: Array) -> void:
	for child in item_row.get_children():
		child.queue_free()
	for t in tools_in:
		var b := Button.new()
		var cost := BuildingDefs.tool_cost(t)
		b.text = SHORT_NAMES.get(t, BuildingDefs.TOOL_NAMES[t])
		if cost > 0:
			b.text += "  $%d" % cost
		b.toggle_mode = true
		b.button_group = tool_group
		b.tooltip_text = _tool_tooltip(t)
		b.button_pressed = GameState.current_tool == t
		b.pressed.connect(func() -> void: GameState.set_tool(t))
		item_row.add_child(b)
	if tools_in.size() == 1:
		GameState.set_tool(tools_in[0])


func _tool_tooltip(t: int) -> String:
	var name: String = BuildingDefs.TOOL_NAMES[t]
	if BuildingDefs.tool_is_building(t):
		var def := BuildingDefs.get_def(BuildingDefs.TOOL_BUILDING[t])
		var s := "%s\n%s\nCost $%d, upkeep $%d/month" % [name, def.get("desc", ""), def.get("cost", 0), def.get("upkeep", 0)]
		if def.has("power_out"):
			s += "\nProduces %d power" % def["power_out"]
		if def.has("water_out"):
			s += "\nProduces %d water" % def["water_out"]
		if def.has("radius"):
			s += "\nCoverage radius %d tiles" % def["radius"]
		return s
	if BuildingDefs.tool_is_zone(t):
		return "%s\n$%d per tile. Needs a road next to it plus power and water to develop." % [name, BuildingDefs.tool_cost(t)]
	match t:
		T.BULLDOZE: return "Bulldoze\nRemoves buildings, development, rubble, trees or empty zones. $%d per tile." % BuildingDefs.BULLDOZE_COST
		T.DEZONE: return "De-zone\nRemoves zoning from undeveloped lots. Free."
		T.QUERY: return "Query\nClick any tile for details."
	return name


func _build_overlay_picker() -> void:
	overlay_select = OptionButton.new()
	overlay_select.mouse_filter = Control.MOUSE_FILTER_STOP
	for o in Constants.OVERLAY_NAMES.keys():
		overlay_select.add_item(Constants.OVERLAY_NAMES[o], o)
	overlay_select.item_selected.connect(func(idx: int) -> void:
		GameState.set_overlay(overlay_select.get_item_id(idx)))
	overlay_select.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	overlay_select.position = Vector2(-190, 44)
	overlay_select.size = Vector2(180, 30)
	overlay_select.tooltip_text = "Data view"
	add_child(overlay_select)


func _build_news() -> void:
	news_label = Label.new()
	news_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	news_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	news_label.offset_top = -124
	news_label.offset_bottom = -98
	news_label.add_theme_font_size_override("font_size", 15)
	news_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	news_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	news_label.add_theme_constant_override("shadow_offset_x", 1)
	news_label.add_theme_constant_override("shadow_offset_y", 1)
	news_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(news_label)
	news_timer = Timer.new()
	news_timer.one_shot = true
	news_timer.wait_time = 6.0
	news_timer.timeout.connect(func() -> void: news_label.text = "")
	add_child(news_timer)


# --- Updates ---------------------------------------------------------------------

func _refresh_all() -> void:
	_refresh_stats()
	_refresh_speed(GameState.speed)
	_refresh_tool(GameState.current_tool)
	overlay_select.select(overlay_select.get_item_index(GameState.current_overlay))
	if not GameState.news.is_empty():
		_show_news(GameState.news[GameState.news.size() - 1])


func _refresh_stats() -> void:
	city_label.text = GameState.city_name
	funds_label.text = "$%s" % _fmt(GameState.funds)
	funds_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4) if GameState.funds < 0 else Color(0.85, 1.0, 0.85))
	pop_label.text = "Pop %s" % _fmt(GameState.population)
	jobs_label.text = "Jobs %s" % _fmt(GameState.jobs_total)
	power_label.text = "Power %d/%d" % [int(GameState.power_demand), int(GameState.power_supply)]
	power_label.add_theme_color_override("font_color", Color(1, 0.5, 0.4) if GameState.power_demand > GameState.power_supply else Color(1, 1, 1))
	water_label.text = "Water %d/%d" % [int(GameState.water_demand), int(GameState.water_supply)]
	water_label.add_theme_color_override("font_color", Color(1, 0.5, 0.4) if GameState.water_demand > GameState.water_supply else Color(1, 1, 1))


func _refresh_speed(s: int) -> void:
	if s >= 0 and s < speed_buttons.size():
		speed_buttons[s].button_pressed = true


func _refresh_tool(t: int) -> void:
	for b in item_row.get_children():
		if b is Button and b.button_pressed and t == T.NONE:
			b.button_pressed = false
	if t == T.NONE:
		tool_hint.text = "No tool selected. Click a tile to inspect it."
	else:
		tool_hint.text = "%s selected" % BuildingDefs.TOOL_NAMES[t]


func _show_news(text: String) -> void:
	news_label.text = text
	news_timer.start()


## Closes any open panel; returns true if one was open.
func close_panels() -> bool:
	var closed := false
	for p in [info_panel, budget_panel, menu_panel]:
		if p.visible:
			p.hide_panel()
			closed = true
	return closed


static func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var count := 0
	for k in range(s.length() - 1, -1, -1):
		out = s[k] + out
		count += 1
		if count % 3 == 0 and k > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out
