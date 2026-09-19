class_name PopulationChart
extends Control
## A compact top-bar chart: residents against the number of them who have a job, so the
## share of the city that is employed is readable at a glance rather than being two
## numbers the player has to compare in their head.

## Categorical slot 1: residents.
const RESIDENTS := Color("#3987e5")
## Categorical slot 3: the employed share of them.
const EMPLOYED := Color("#199e70")
const TEXT_MUTED := Color(0.78, 0.79, 0.84)
const TEXT_PRIMARY := Color(0.96, 0.96, 0.97)

const PLOT_W := 132.0
const LABEL_W := 124.0


func _ready() -> void:
	custom_minimum_size = Vector2(PLOT_W + LABEL_W, 40)
	tooltip_text = "Residents and how many of them have a job.\nThe gap between the lines is unemployment."
	mouse_filter = Control.MOUSE_FILTER_STOP
	Events.month_ticked.connect(queue_redraw)
	Events.city_started.connect(queue_redraw)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var residents := GameState.population_history
	var employed := GameState.employed_history
	var plot := Rect2(0, 5, PLOT_W, size.y - 10)

	if residents.size() >= 2:
		var y_max := 1.0
		for v in residents:
			y_max = maxf(y_max, v)
		y_max *= 1.1
		draw_line(Vector2(plot.position.x, plot.end.y), Vector2(plot.end.x, plot.end.y), Color(1, 1, 1, 0.18), 1.0)
		_draw_series(residents, y_max, plot, RESIDENTS, true)
		_draw_series(employed, y_max, plot, EMPLOYED, false)
	else:
		draw_string(font, Vector2(plot.position.x, plot.get_center().y + 4), "no history yet",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT_MUTED)

	# Direct labels: the colour chip carries identity, the words and numbers stay in ink.
	var x := PLOT_W + 10.0
	draw_circle(Vector2(x, 13), 4.0, RESIDENTS)
	draw_string(font, Vector2(x + 9, 17), "%s residents" % _fmt(GameState.population),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT_PRIMARY)
	draw_circle(Vector2(x, 29), 4.0, EMPLOYED)
	var share := 0
	var workers := GameState.population / 2
	if workers > 0:
		share = int(round(float(GameState.employed) / float(workers) * 100.0))
	draw_string(font, Vector2(x + 9, 33), "%s employed (%d%%)" % [_fmt(GameState.employed), share],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT_MUTED)


func _draw_series(values: PackedFloat32Array, y_max: float, plot: Rect2, colour: Color, fill: bool) -> void:
	if values.size() < 2:
		return
	var n := values.size() - 1
	var line := PackedVector2Array()
	for i in range(values.size()):
		line.append(Vector2(
			plot.position.x + plot.size.x * float(i) / float(n),
			plot.end.y - plot.size.y * clampf(values[i] / y_max, 0.0, 1.0)))
	if fill:
		var area := line.duplicate()
		area.append(Vector2(plot.end.x, plot.end.y))
		area.append(Vector2(plot.position.x, plot.end.y))
		draw_colored_polygon(area, Color(colour.r, colour.g, colour.b, 0.20))
	draw_polyline(line, colour, 2.0)


static func _fmt(n: int) -> String:
	if n >= 10000:
		return "%.1fk" % (float(n) / 1000.0)
	var s := str(n)
	if s.length() > 3:
		return s.substr(0, s.length() - 3) + "," + s.substr(s.length() - 3)
	return s
