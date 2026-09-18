class_name BudgetPanel
extends PanelContainer
## Tax rates, department funding and the monthly income/expense breakdown.

var tax_sliders := {}
var tax_labels := {}
var fund_sliders := {}
var fund_labels := {}
var summary: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	custom_minimum_size = Vector2(420, 0)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
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
	summary = Label.new()
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
	var lines: Array[String] = []
	lines.append("Last month")
	lines.append("  Income:   $%d  (R $%d, C $%d, I $%d)" % [int(inc.get("total", 0)), int(inc.get("R", 0)), int(inc.get("C", 0)), int(inc.get("I", 0))])
	var parts: Array[String] = []
	for k in ["roads", "power", "water", "police", "fire", "school", "health", "park"]:
		if exp.has(k) and exp[k] > 0.0:
			parts.append("%s $%d" % [k, int(exp[k])])
	lines.append("  Expenses: $%d" % int(GameState.last_expenses_total))
	if not parts.is_empty():
		lines.append("    " + ", ".join(parts))
	var net := int(inc.get("total", 0)) - int(GameState.last_expenses_total)
	lines.append("  Net: %s$%d" % ["+" if net >= 0 else "-", absi(net)])
	lines.append("Treasury: $%d" % GameState.funds)
	summary.text = "\n".join(lines)


func toggle() -> void:
	if visible:
		hide_panel()
	else:
		_sync_from_state()
		visible = true


func hide_panel() -> void:
	visible = false
