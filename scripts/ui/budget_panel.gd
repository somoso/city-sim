class_name BudgetPanel
extends PanelContainer
## Tax rates, department funding and the monthly income/expense breakdown.

var tax_sliders := {}
var tax_labels := {}
var fund_sliders := {}
var fund_labels := {}
var summary: Label
var treasury_label: Label
var flow_labels := {}

const MONEY_IN := Color("#28c828")
const MONEY_OUT := Color("#f06464")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	custom_minimum_size = Vector2(420, 0)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Label.new()
	title.text = "City Budget"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(hide_panel)
	head.add_child(close)

	var tax_title := Label.new()
	tax_title.text = "Tax rates (%)"
	col.add_child(tax_title)
	var tax_grid := GridContainer.new()
	tax_grid.columns = 3
	tax_grid.add_theme_constant_override("h_separation", 10)
	col.add_child(tax_grid)
	for entry in [["R", "Residential"], ["C", "Commercial"], ["I", "Industrial"]]:
		var key: String = entry[0]
		_add_slider_row(tax_grid, entry[1], 0, 20, 1, GameState.tax[key], tax_sliders, tax_labels, key,
			func(v: float) -> void:
				GameState.tax[key] = int(v)
				tax_labels[key].text = "%d%%" % int(v))

	col.add_child(HSeparator.new())
	var fund_title := Label.new()
	fund_title.text = "Department funding (%)"
	col.add_child(fund_title)
	var fund_grid := GridContainer.new()
	fund_grid.columns = 3
	fund_grid.add_theme_constant_override("h_separation", 10)
	col.add_child(fund_grid)
	for entry in [["police", "Police"], ["fire", "Fire"], ["school", "Education"], ["health", "Health"]]:
		var key: String = entry[0]
		_add_slider_row(fund_grid, entry[1], 0, 150, 10, GameState.funding[key], fund_sliders, fund_labels, key,
			func(v: float) -> void:
				GameState.funding[key] = int(v)
				fund_labels[key].text = "%d%%" % int(v))

	col.add_child(HSeparator.new())
	treasury_label = Label.new()
	treasury_label.add_theme_font_size_override("font_size", 16)
	col.add_child(treasury_label)
	var flow := GridContainer.new()
	flow.columns = 2
	flow.add_theme_constant_override("h_separation", 10)
	col.add_child(flow)
	for entry in [["Income", "income"], ["Expenses", "expenses"], ["Net", "net"]]:
		var name_label := Label.new()
		name_label.text = entry[0]
		name_label.custom_minimum_size.x = 90
		flow.add_child(name_label)
		var value := Label.new()
		value.add_theme_font_size_override("font_size", 15)
		flow.add_child(value)
		flow_labels[entry[1]] = value
	summary = Label.new()
	summary.add_theme_font_size_override("font_size", 12)
	summary.modulate = Color(1, 1, 1, 0.8)
	col.add_child(summary)

	Events.month_ticked.connect(_refresh)
	Events.city_started.connect(_sync_from_state)


func _add_slider_row(grid: GridContainer, label_text: String, min_v: float, max_v: float, step: float,
		value: float, sliders: Dictionary, labels: Dictionary, key: String, on_change: Callable) -> void:
	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size.x = 110
	grid.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = value
	slider.custom_minimum_size.x = 200
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(on_change)
	grid.add_child(slider)
	var value_label := Label.new()
	value_label.text = "%d%%" % int(value)
	value_label.custom_minimum_size.x = 48
	grid.add_child(value_label)
	sliders[key] = slider
	labels[key] = value_label


func _sync_from_state() -> void:
	for k in tax_sliders.keys():
		tax_sliders[k].set_value_no_signal(GameState.tax[k])
		tax_labels[k].text = "%d%%" % GameState.tax[k]
	for k in fund_sliders.keys():
		fund_sliders[k].set_value_no_signal(GameState.funding[k])
		fund_labels[k].text = "%d%%" % GameState.funding[k]
	_refresh()


func _refresh() -> void:
	var inc := GameState.last_income
	var exp := GameState.last_expenses
	var income := float(inc.get("total", 0.0))
	var expenses := GameState.last_expenses_total
	var net := income - expenses

	treasury_label.text = "Treasury: $%s" % _money(GameState.funds)
	treasury_label.add_theme_color_override("font_color", MONEY_OUT if GameState.funds < 0 else Color(0.90, 1.0, 0.90))
	flow_labels["income"].text = "+$%s" % _money(int(round(income)))
	flow_labels["income"].add_theme_color_override("font_color", MONEY_IN)
	flow_labels["expenses"].text = "-$%s" % _money(int(round(expenses)))
	flow_labels["expenses"].add_theme_color_override("font_color", MONEY_OUT)
	flow_labels["net"].text = "%s$%s per month" % ["+" if net >= 0.0 else "-", _money(int(round(abs(net))))]
	flow_labels["net"].add_theme_color_override("font_color", MONEY_IN if net >= 0.0 else MONEY_OUT)

	var lines: Array[String] = []
	lines.append("Income came from R $%d, C $%d, I $%d." % [int(inc.get("R", 0)), int(inc.get("C", 0)), int(inc.get("I", 0))])
	var parts: Array[String] = []
	for k in ["roads", "power", "water", "police", "fire", "school", "health", "park"]:
		if exp.has(k) and exp[k] > 0.0:
			parts.append("%s $%d" % [k, int(exp[k])])
	if not parts.is_empty():
		lines.append("Spending: " + ", ".join(parts) + ".")
	summary.text = "\n".join(lines)


static func _money(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var count := 0
	for k in range(s.length() - 1, -1, -1):
		out = s[k] + out
		count += 1
		if count % 3 == 0 and k > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


func toggle() -> void:
	if visible:
		hide_panel()
	else:
		_sync_from_state()
		visible = true


func hide_panel() -> void:
	visible = false
