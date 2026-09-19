class_name UtilityPanel
extends PanelContainer
## Power and water utilisation: a headline reading for each utility plus a chart of the
## last ten years, so the player can see a shortage coming instead of only being told
## about it once lots go dark.

var power_stat: Label
var water_stat: Label
var power_meter: UtilityMeter
var water_meter: UtilityMeter
var power_chart: UtilityChart
var water_chart: UtilityChart
var waste_stat: Label
var waste_meter: UtilityMeter
var waste_chart: UtilityChart
var networks_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	custom_minimum_size = Vector2(470, 0)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	offset_left = -490
	offset_right = -14
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	margin.add_child(outer)
	# Three utilities do not fit a 720-tall window, so the body scrolls.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var head := HBoxContainer.new()
	outer.add_child(head)
	outer.add_child(scroll)
	scroll.add_child(col)
	var title := Label.new()
	title.text = "Utilities"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(hide_panel)
	head.add_child(close)

	power_stat = Label.new()
	col.add_child(power_stat)
	power_meter = UtilityMeter.new()
	col.add_child(power_meter)
	power_chart = UtilityChart.new()
	power_chart.title_text = "Power over time"
	power_chart.unit = "MW"
	col.add_child(power_chart)

	col.add_child(HSeparator.new())

	water_stat = Label.new()
	col.add_child(water_stat)
	water_meter = UtilityMeter.new()
	col.add_child(water_meter)
	water_chart = UtilityChart.new()
	water_chart.title_text = "Water over time"
	water_chart.unit = "units"
	col.add_child(water_chart)

	col.add_child(HSeparator.new())

	waste_stat = Label.new()
	col.add_child(waste_stat)
	waste_meter = UtilityMeter.new()
	col.add_child(waste_meter)
	waste_chart = UtilityChart.new()
	waste_chart.title_text = "Refuse over time"
	waste_chart.unit = "units"
	waste_chart.demand_name = "Produced"
	waste_chart.capacity_name = "Processed"
	col.add_child(waste_chart)

	networks_label = Label.new()
	networks_label.add_theme_font_size_override("font_size", 12)
	networks_label.modulate = Color(1, 1, 1, 0.75)
	networks_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(networks_label)

	Events.month_ticked.connect(_refresh_if_open)
	Events.world_changed.connect(_refresh_if_open)
	Events.city_started.connect(hide_panel)


func toggle() -> void:
	if visible:
		hide_panel()
	else:
		refresh()
		visible = true


func hide_panel() -> void:
	visible = false


func _refresh_if_open() -> void:
	if visible:
		refresh()


func refresh() -> void:
	_set_stat(power_stat, power_meter, "Power", GameState.power_demand, GameState.power_supply, "MW")
	_set_stat(water_stat, water_meter, "Water", GameState.water_demand, GameState.water_supply, "units")
	_set_stat(waste_stat, waste_meter, "Refuse", GameState.waste_production, GameState.waste_capacity, "units")
	power_chart.set_series(GameState.power_demand_history, GameState.power_supply_history)
	water_chart.set_series(GameState.water_demand_history, GameState.water_supply_history)
	waste_chart.set_series(GameState.waste_production_history, GameState.waste_capacity_history)
	var p := GameState.power_networks.size()
	var w := GameState.water_networks.size()
	var parts: Array[String] = []
	parts.append("%d power network%s" % [p, "" if p == 1 else "s"])
	parts.append("%d water network%s" % [w, "" if w == 1 else "s"])
	networks_label.text = "%s. Separate networks do not share supply, so check each one with the Query tool." % " and ".join(parts)


func _set_stat(label: Label, meter: UtilityMeter, name: String, demand: float, supply: float, unit: String) -> void:
	var pct := 0.0 if supply <= 0.0 else demand / supply * 100.0
	var state := "no supply" if supply <= 0.0 and demand > 0.0 else UtilityMeter.state_word(pct)
	label.text = "%s: %d of %d %s used (%d%%) - %s" % [name, int(round(demand)), int(round(supply)), unit, int(round(pct)), state]
	label.add_theme_color_override("font_color", UtilityMeter.state_color(pct if supply > 0.0 else 999.0))
	meter.set_value(demand, supply)
