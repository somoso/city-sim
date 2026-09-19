extends CanvasLayer
## Builds and updates the in-game interface: top status bar, toolbar, overlay picker,
## news ticker, and the info / budget / menu panels.

const T := Constants.Tool

const CATEGORIES := [
	["Query", [T.QUERY]],
	["Destruction", [T.BULLDOZE, T.DEZONE]],
	["Roads", [T.ROAD]],
	["Residential", [T.ZONE_R_LOW, T.ZONE_R_MED, T.ZONE_R_HIGH]],
	["Commercial", [T.ZONE_C_LOW, T.ZONE_C_MED, T.ZONE_C_HIGH]],
	["Industrial", [T.ZONE_I_LOW, T.ZONE_I_MED, T.ZONE_I_HIGH]],
	["Power", [T.POWER_COAL, T.POWER_WIND, T.POWER_NUCLEAR]],
	["Water", [T.WATER_PUMP, T.WATER_TOWER]],
	["Waste", [T.LANDFILL, T.INCINERATOR, T.RECYCLING_CENTRE]],
	["Police", [T.POLICE, T.PRISON, T.HIGH_SECURITY_PRISON]],
	["Fire", [T.FIRE_STATION, T.FIRE_HELIPAD]],
	["Health", [T.GP_SURGERY, T.COMMUNITY_HOSPITAL, T.HOSPITAL, T.PRIVATE_HOSPITAL]],
	["Education", [T.NURSERY, T.SCHOOL, T.UNIVERSITY]],
	["Services", [T.PARK, T.DEMOLITION_DEPOT]],
]

const SHORT_NAMES := {
	T.QUERY: "Query", T.BULLDOZE: "Bulldoze", T.DEZONE: "De-zone", T.ROAD: "Road",
	T.ZONE_R_LOW: "Low", T.ZONE_R_MED: "Medium", T.ZONE_R_HIGH: "High",
	T.ZONE_C_LOW: "Low", T.ZONE_C_MED: "Medium", T.ZONE_C_HIGH: "High",
	T.ZONE_I_LOW: "Agriculture", T.ZONE_I_MED: "Medium", T.ZONE_I_HIGH: "High",
	T.POWER_COAL: "Coal Plant", T.POWER_WIND: "Wind Turbine", T.POWER_NUCLEAR: "Nuclear Plant",
	T.WATER_PUMP: "Pump", T.WATER_TOWER: "Tower",
	T.LANDFILL: "Landfill", T.INCINERATOR: "Incinerator", T.RECYCLING_CENTRE: "Recycling",
	T.POLICE: "Station", T.PRISON: "Prison", T.HIGH_SECURITY_PRISON: "High Security",
	T.FIRE_STATION: "Station", T.FIRE_HELIPAD: "Helicopters",
	T.GP_SURGERY: "GP", T.COMMUNITY_HOSPITAL: "Community", T.HOSPITAL: "General",
	T.PRIVATE_HOSPITAL: "Private",
	T.NURSERY: "Nursery", T.SCHOOL: "High School", T.UNIVERSITY: "University",
	T.PARK: "Park", T.DEMOLITION_DEPOT: "Demolition Depot",
}

var city_label: Label
var funds_label: Label
var income_label: Label
var expenses_label: Label
var net_label: Label
var date_label: Label
var population_chart: PopulationChart
var speed_buttons: Array[Button] = []
var speed_group := ButtonGroup.new()

var item_row: HBoxContainer
var category_buttons: Array[Button] = []
var tool_group := ButtonGroup.new()
var tool_hint: Label
var overlay_select: OptionButton

var news_label: Label
var news_timer: Timer
var overlay_legend: Label

var alert_panel: PanelContainer
var alert_style: StyleBoxFlat
var alert_buttons := {}
var _alert_time := 0.0

## Wording and accent colour for each kind of shortage.
const ALERT_INFO := {
	"road": ["No road access: %d lot%s", Color(1.0, 0.72, 0.66)],
	"power": ["No electricity: %d lot%s", Color(1.0, 0.86, 0.35)],
	"water": ["No water: %d lot%s", Color(0.55, 0.80, 1.0)],
	"waste": ["Refuse uncollected: %d lot%s", Color(0.72, 0.86, 0.60)],
	"abandoned": ["Abandoned: %d lot%s", Color(0.86, 0.72, 0.52)],
}

## Reserved status colours for money moving in and out.
const MONEY_IN := Color("#28c828")
const MONEY_OUT := Color("#f06464")

const OVERLAY_LEGENDS := {
	Constants.Overlay.ZONES: "Green: residential. Blue: commercial. Yellow: industrial.",
	Constants.Overlay.POWER: "Yellow wires under roads carry power. Red: no power reaches here.\nRings mark power plants. Lots tinted red are unpowered.",
	Constants.Overlay.WATER: "Blue pipes under roads carry water from pumps and towers.\nRed pipes are dry. Rings mark water sources. Red lots have no water.",
	Constants.Overlay.LAND_VALUE: "Green: high land value. Red: low. Parks, water and services raise it;\npollution, crime and industry lower it.",
	Constants.Overlay.POLLUTION: "Darker brown means more pollution (industry, coal, traffic).",
	Constants.Overlay.CRIME: "Darker red means more crime. Police coverage reduces it.",
	Constants.Overlay.TRAFFIC: "Roads from green (quiet) to red (congested).",
	Constants.Overlay.FIRE_RISK: "Yellow to red: rising fire risk. Fire stations lower it.",
	Constants.Overlay.POLICE: "Blue: police coverage. Grey: unprotected.",
	Constants.Overlay.FIRE: "Orange: fire station coverage. Grey: unprotected.",
	Constants.Overlay.EDUCATION: "Orange: school coverage. Grey: no schools nearby.",
	Constants.Overlay.HEALTH: "White: hospital coverage. Grey: no hospital nearby.",
}

var info_panel: InfoPanel
var budget_panel: BudgetPanel
var utility_panel: UtilityPanel
var civic_panel: CivicPanel
var menu_panel: GameMenu


func _ready() -> void:
	layer = 10
	_build_top_bar()
	_build_toolbar()
	_build_overlay_picker()
	_build_news()
	_build_alerts()
	info_panel = InfoPanel.new()
	add_child(info_panel)
	budget_panel = BudgetPanel.new()
	add_child(budget_panel)
	utility_panel = UtilityPanel.new()
	add_child(utility_panel)
	civic_panel = CivicPanel.new()
	add_child(civic_panel)
	menu_panel = GameMenu.new()
	add_child(menu_panel)

	Events.month_ticked.connect(_refresh_stats)
	Events.funds_changed.connect(func(_f: int) -> void: _refresh_stats())
	Events.speed_changed.connect(_refresh_speed)
	Events.tool_changed.connect(_refresh_tool)
	Events.overlay_changed.connect(func(o: int) -> void:
		overlay_select.select(overlay_select.get_item_index(o))
		overlay_legend.text = OVERLAY_LEGENDS.get(o, ""))
	Events.message.connect(_show_news)
	Events.alerts_changed.connect(_on_alerts_changed)
	Events.city_started.connect(_refresh_all)
	_refresh_all()


func _process(delta: float) -> void:
	var day := int(get_parent().month_progress() * 30.0) + 1
	date_label.text = "%s %d, %d" % [Constants.MONTH_NAMES[GameState.month], day, GameState.year]
	if alert_panel.visible:
		# Flash the banner border in step with the badges out in the world.
		_alert_time += delta
		var pulse := 0.5 + 0.5 * sin(_alert_time / AlertsLayer.PULSE_PERIOD * TAU)
		alert_style.border_color = Color(1.0, 0.25, 0.20, 0.40 + 0.60 * pulse)


# --- Construction -----------------------------------------------------------------

func _panel(preset: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.set_anchors_and_offsets_preset(preset)
	# Panels anchored to the bottom edge must grow upward to stay on screen.
	if preset == Control.PRESET_BOTTOM_WIDE:
		p.grow_vertical = Control.GROW_DIRECTION_BEGIN
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
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)

	city_label = _label("City", 16)
	row.add_child(city_label)
	row.add_child(_vsep())
	# Treasury, with last month's income, expenses and net underneath it.
	var money := VBoxContainer.new()
	money.add_theme_constant_override("separation", 0)
	money.tooltip_text = "City treasury, and last month's income, expenses and net change.\nClick Budget to adjust taxes and funding."
	row.add_child(money)
	funds_label = _label("$0", 16)
	money.add_child(funds_label)
	var flow := HBoxContainer.new()
	flow.add_theme_constant_override("separation", 8)
	money.add_child(flow)
	income_label = _label("+$0", 11)
	income_label.add_theme_color_override("font_color", MONEY_IN)
	flow.add_child(income_label)
	expenses_label = _label("-$0", 11)
	expenses_label.add_theme_color_override("font_color", MONEY_OUT)
	flow.add_child(expenses_label)
	net_label = _label("$0", 11)
	flow.add_child(net_label)
	row.add_child(_vsep())
	date_label = _label("Jan 1, 2000", 13)
	date_label.custom_minimum_size.x = 104
	row.add_child(date_label)
	row.add_child(_vsep())
	population_chart = PopulationChart.new()
	row.add_child(population_chart)
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
	var civic_btn := Button.new()
	civic_btn.text = "Civic"
	civic_btn.tooltip_text = "Police, fire, health and education coverage, and what each costs per resident"
	civic_btn.pressed.connect(func() -> void: civic_panel.toggle())
	row.add_child(civic_btn)
	var utilities_btn := Button.new()
	utilities_btn.text = "Utilities"
	utilities_btn.tooltip_text = "Power and water utilisation, with ten years of history"
	utilities_btn.pressed.connect(func() -> void: utility_panel.toggle())
	row.add_child(utilities_btn)
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
		b.text = SHORT_NAMES.get(t, BuildingDefs.tool_name(t))
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
	var name: String = BuildingDefs.tool_name(t)
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
		var zd: Array = BuildingDefs.TOOL_ZONE[t]
		var limits := Constants.block_limits(zd[0], zd[1])
		var shape := "%d tiles deep" % limits.x
		if limits.y > 0:
			shape = "%d x %d tiles" % [limits.x, limits.y]
		return "%s\n$%d per tile. Service roads are laid automatically so no block exceeds %s.\nLots need power and water to develop." % [name, BuildingDefs.tool_cost(t), shape]
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
	overlay_select.offset_left = -190
	overlay_select.offset_right = -10
	overlay_select.offset_top = 44
	overlay_select.offset_bottom = 74
	overlay_select.tooltip_text = "Data view"
	add_child(overlay_select)
	overlay_legend = Label.new()
	overlay_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	overlay_legend.add_theme_font_size_override("font_size", 13)
	overlay_legend.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	overlay_legend.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	overlay_legend.add_theme_constant_override("shadow_offset_x", 1)
	overlay_legend.add_theme_constant_override("shadow_offset_y", 1)
	overlay_legend.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	overlay_legend.offset_left = -520
	overlay_legend.offset_right = -10
	overlay_legend.offset_top = 80
	overlay_legend.offset_bottom = 120
	add_child(overlay_legend)


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


func _build_alerts() -> void:
	alert_style = StyleBoxFlat.new()
	alert_style.bg_color = Color(0.11, 0.05, 0.06, 0.93)
	alert_style.border_color = Color(1.0, 0.25, 0.20)
	alert_style.set_border_width_all(3)
	alert_style.set_corner_radius_all(6)
	alert_style.set_content_margin_all(9)
	alert_panel = PanelContainer.new()
	alert_panel.add_theme_stylebox_override("panel", alert_style)
	alert_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	alert_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	alert_panel.offset_left = 10
	alert_panel.offset_top = 48
	alert_panel.visible = false
	add_child(alert_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	alert_panel.add_child(col)
	var title := Label.new()
	title.text = "Problems"
	title.add_theme_font_size_override("font_size", 13)
	title.modulate = Color(1, 1, 1, 0.75)
	col.add_child(title)
	for kind in Alerts.KINDS:
		var b := Button.new()
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_color_override("font_color", ALERT_INFO[kind][1])
		b.tooltip_text = "Click to jump to the next affected lot"
		b.pressed.connect(func() -> void: get_parent().focus_alert(kind))
		col.add_child(b)
		alert_buttons[kind] = b


func _on_alerts_changed(counts: Dictionary) -> void:
	var total := 0
	for kind in Alerts.KINDS:
		var n := int(counts.get(kind, 0))
		total += n
		var b: Button = alert_buttons[kind]
		b.visible = n > 0
		if n > 0:
			b.text = ALERT_INFO[kind][0] % [n, "" if n == 1 else "s"]
	alert_panel.visible = total > 0


# --- Updates ---------------------------------------------------------------------

func _refresh_all() -> void:
	_refresh_stats()
	_refresh_speed(GameState.speed)
	_refresh_tool(GameState.current_tool)
	overlay_select.select(overlay_select.get_item_index(GameState.current_overlay))
	overlay_legend.text = OVERLAY_LEGENDS.get(GameState.current_overlay, "")
	if not GameState.news.is_empty():
		_show_news(GameState.news[GameState.news.size() - 1])


func _refresh_stats() -> void:
	city_label.text = GameState.city_name
	funds_label.text = "$%s" % _fmt(GameState.funds)
	funds_label.add_theme_color_override("font_color", MONEY_OUT if GameState.funds < 0 else Color(0.90, 1.0, 0.90))
	var income := int(round(float(GameState.last_income.get("total", 0.0))))
	var expenses := int(round(GameState.last_expenses_total))
	var net := income - expenses
	income_label.text = "+$%s" % _fmt(income)
	expenses_label.text = "-$%s" % _fmt(expenses)
	net_label.text = "net %s$%s" % ["+" if net >= 0 else "-", _fmt(absi(net))]
	net_label.add_theme_color_override("font_color", MONEY_IN if net >= 0 else MONEY_OUT)
	population_chart.queue_redraw()


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
		tool_hint.text = "%s selected" % BuildingDefs.tool_name(t)


func _show_news(text: String) -> void:
	news_label.text = text
	news_timer.start()


## Closes any open panel; returns true if one was open.
func close_panels() -> bool:
	var closed := false
	for p in [info_panel, budget_panel, utility_panel, civic_panel, menu_panel]:
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
