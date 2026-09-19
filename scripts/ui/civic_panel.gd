class_name CivicPanel
extends PanelContainer
## Civic utilisation: how much of the population each service actually reaches, what it
## costs per month, and what that is per resident. A table of meters rather than a chart,
## because the question is "how covered am I right now", not "how has it moved".

var rows := {}
var summary: Label
var population_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	custom_minimum_size = Vector2(520, 0)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	offset_left = -540
	offset_right = -14
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
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
	title.text = "Civic services"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(hide_panel)
	head.add_child(close)

	population_label = Label.new()
	population_label.add_theme_font_size_override("font_size", 12)
	population_label.modulate = Color(1, 1, 1, 0.75)
	col.add_child(population_label)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	col.add_child(grid)
	for header in ["Service", "Residents covered", "Cost / month", "Per resident"]:
		var h := Label.new()
		h.text = header
		h.add_theme_font_size_override("font_size", 12)
		h.modulate = Color(1, 1, 1, 0.65)
		grid.add_child(h)
	for group in CivicStats.GROUPS:
		var id: String = group[0]
		var name_label := Label.new()
		name_label.text = group[1]
		name_label.custom_minimum_size.x = 120
		grid.add_child(name_label)
		var cover := HBoxContainer.new()
		cover.custom_minimum_size.x = 170
		grid.add_child(cover)
		var meter := UtilityMeter.new()
		meter.custom_minimum_size = Vector2(112, 14)
		meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cover.add_child(meter)
		var pct := Label.new()
		pct.custom_minimum_size.x = 52
		cover.add_child(pct)
		var cost := Label.new()
		cost.custom_minimum_size.x = 90
		grid.add_child(cost)
		var per := Label.new()
		grid.add_child(per)
		rows[id] = { "meter": meter, "pct": pct, "cost": cost, "per": per }

	summary = Label.new()
	summary.add_theme_font_size_override("font_size", 12)
	summary.modulate = Color(1, 1, 1, 0.78)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(summary)

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
	if not GameState.has_city():
		return
	var stats := CivicStats.compute(GameState.grid, GameState)
	var pop := int(stats["population"])
	population_label.text = "Coverage is weighted by where people actually live, across %s residents." % _fmt(pop)
	var total_cost := 0.0
	for group in CivicStats.GROUPS:
		var id: String = group[0]
		var s: Dictionary = stats[id]
		var row: Dictionary = rows[id]
		var pct := float(s["coverage"]) * 100.0
		total_cost += float(s["cost"])
		# The meter reads as "how much of the job is done", so full coverage is the target.
		row["meter"].set_value(pct, 100.0)
		row["pct"].text = "%d%%" % int(round(pct))
		row["cost"].text = "$%s" % _fmt(int(round(float(s["cost"]))))
		if pop == 0:
			row["per"].text = "-"
		else:
			row["per"].text = "$%.2f" % float(s["per_person"])
		var buildings := int(s["buildings"])
		row["pct"].tooltip_text = "%d building%s" % [buildings, "" if buildings == 1 else "s"]
	var per_head := 0.0 if pop == 0 else total_cost / float(pop)
	var lines: Array[String] = []
	lines.append("All civic services cost $%s a month, or $%.2f per resident." % [_fmt(int(round(total_cost))), per_head])
	lines.append("Medium housing needs any education building; high housing needs %d%% of residents schooled (now %d%%)." % [
		int(round(Balance.num("society.high_res_educated_share", Society.HIGH_RES_EDUCATED_SHARE) * 100.0)),
		int(round(GameState.educated_share * 100.0))])
	lines.append("High commercial needs %d%% university educated (now %d%%); medium commercial needs %d%% in medium housing (now %d%%)." % [
		int(round(Balance.num("society.high_com_university_share", Society.HIGH_COM_UNIVERSITY_SHARE) * 100.0)),
		int(round(GameState.university_share * 100.0)),
		int(round(Balance.num("society.medium_com_medium_res_share", Society.MED_COM_MEDIUM_RES_SHARE) * 100.0)),
		int(round(GameState.medium_res_share * 100.0))])
	summary.text = "\n".join(lines)


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
