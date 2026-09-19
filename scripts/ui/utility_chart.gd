class_name UtilityChart
extends Control
## One utilisation chart: monthly demand against available capacity for a single utility.
##
## Power and water are drawn as two separate charts rather than one, because they are
## different units and a single plot would need two y-scales.

## Categorical slot 1: demand, the series the player watches.
const DEMAND := Color("#3987e5")
## Categorical slot 2: capacity.
const CAPACITY := Color("#d95926")
## Reserved status colour, used only for the over-capacity region.
const CRITICAL := Color("#d03b3b")

const SURFACE := Color("#1a1d26")
const GRID_INK := Color(1, 1, 1, 0.09)
const AXIS_INK := Color(1, 1, 1, 0.22)
const TEXT_PRIMARY := Color(0.96, 0.96, 0.97)
const TEXT_MUTED := Color(0.70, 0.71, 0.76)

const PAD_LEFT := 56.0
const PAD_RIGHT := 14.0
const PAD_TOP := 30.0
const PAD_BOTTOM := 26.0

var title_text := "Power"
var unit := "MW"
var demand_name := "Demand"
var capacity_name := "Capacity"
var demand := PackedFloat32Array()
var capacity := PackedFloat32Array()

var _hover_index := -1


func _ready() -> void:
	custom_minimum_size = Vector2(430, 170)
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_series(new_demand: PackedFloat32Array, new_capacity: PackedFloat32Array) -> void:
	demand = new_demand
	capacity = new_capacity
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var idx := _index_at(event.position.x)
		if idx != _hover_index:
			_hover_index = idx
			queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover_index != -1:
		_hover_index = -1
		queue_redraw()


func _plot_rect() -> Rect2:
	return Rect2(PAD_LEFT, PAD_TOP, maxf(size.x - PAD_LEFT - PAD_RIGHT, 1.0),
		maxf(size.y - PAD_TOP - PAD_BOTTOM, 1.0))


func _index_at(x: float) -> int:
	var n := demand.size()
	if n < 2:
		return -1
	var r := _plot_rect()
	var t := clampf((x - r.position.x) / r.size.x, 0.0, 1.0)
	return int(round(t * float(n - 1)))


func _point(i: int, value: float, y_max: float) -> Vector2:
	var r := _plot_rect()
	var n := maxi(demand.size() - 1, 1)
	return Vector2(
		r.position.x + r.size.x * float(i) / float(n),
		r.end.y - r.size.y * clampf(value / y_max, 0.0, 1.0))


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), SURFACE)
	draw_string(font, Vector2(PAD_LEFT, 20), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TEXT_PRIMARY)

	var n := demand.size()
	if n < 2:
		draw_string(font, Vector2(PAD_LEFT, size.y * 0.55), "Not enough history yet.",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT_MUTED)
		return

	var y_max := 1.0
	for v in demand:
		y_max = maxf(y_max, v)
	for v in capacity:
		y_max = maxf(y_max, v)
	y_max *= 1.15

	var r := _plot_rect()
	# Recessive gridlines and y labels.
	for step in range(3):
		var frac := float(step) / 2.0
		var y := r.end.y - r.size.y * frac
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), GRID_INK, 1.0)
		var label := _fmt(y_max * frac)
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(font, Vector2(r.position.x - 8 - w, y + 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT_MUTED)
	draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), AXIS_INK, 1.0)

	# Shade the stretch where demand ran past capacity.
	var over := PackedVector2Array()
	for i in range(n):
		var d: float = demand[i]
		var c: float = capacity[i] if i < capacity.size() else 0.0
		if d > c:
			var top := _point(i, d, y_max)
			var bottom := _point(i, c, y_max)
			over.append(top)
			over.append(bottom)
	for k in range(0, over.size() - 2, 2):
		draw_colored_polygon(PackedVector2Array([over[k], over[k + 2], over[k + 3], over[k + 1]]),
			Color(CRITICAL.r, CRITICAL.g, CRITICAL.b, 0.30))

	# Demand as a filled area plus a 2px line.
	var area := PackedVector2Array()
	var line := PackedVector2Array()
	area.append(Vector2(r.position.x, r.end.y))
	for i in range(n):
		var p := _point(i, demand[i], y_max)
		area.append(p)
		line.append(p)
	area.append(Vector2(r.end.x, r.end.y))
	draw_colored_polygon(area, Color(DEMAND.r, DEMAND.g, DEMAND.b, 0.22))
	draw_polyline(line, DEMAND, 2.0)

	# Capacity as a dashed 2px line, so the two series differ by more than colour.
	if capacity.size() >= 2:
		var prev := _point(0, capacity[0], y_max)
		for i in range(1, capacity.size()):
			var p := _point(i, capacity[i], y_max)
			if i % 2 == 1:
				draw_line(prev, p, CAPACITY, 2.0)
			prev = p

	_draw_legend(font, r)
	_draw_end_labels(font, r, y_max)
	if _hover_index >= 0 and _hover_index < n:
		_draw_hover(font, r, y_max)


## Legend: a colour chip carries identity, the words stay in ink.
func _draw_legend(font: Font, r: Rect2) -> void:
	var entries := [[demand_name, DEMAND], [capacity_name, CAPACITY]]
	var x := r.end.x
	for k in range(entries.size() - 1, -1, -1):
		var text: String = entries[k][0]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		x -= w
		draw_string(font, Vector2(x, 20), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT_MUTED)
		x -= 9
		draw_circle(Vector2(x, 16), 4.0, entries[k][1])
		x -= 16


## The latest value of each series, labelled at the right edge.
func _draw_end_labels(font: Font, r: Rect2, y_max: float) -> void:
	var last := demand.size() - 1
	var items := [[demand[last], DEMAND]]
	if capacity.size() > 0:
		items.append([capacity[capacity.size() - 1], CAPACITY])
	for item in items:
		var value: float = item[0]
		var p := _point(last, value, y_max)
		draw_circle(p, 4.0, item[1])
		draw_circle(p, 4.0, SURFACE, false, 2.0)


func _draw_hover(font: Font, r: Rect2, y_max: float) -> void:
	var i := _hover_index
	var d: float = demand[i]
	var c: float = capacity[i] if i < capacity.size() else 0.0
	var px := _point(i, d, y_max).x
	draw_line(Vector2(px, r.position.y), Vector2(px, r.end.y), Color(1, 1, 1, 0.28), 1.0)
	draw_circle(_point(i, d, y_max), 5.0, DEMAND)
	draw_circle(_point(i, c, y_max), 5.0, CAPACITY)

	var months_ago := demand.size() - 1 - i
	var lines := [
		_month_label(months_ago),
		"%s %s %s" % [demand_name, _fmt(d), unit],
		"%s %s %s" % [capacity_name, _fmt(c), unit],
	]
	var w := 0.0
	for l in lines:
		w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x)
	var box := Rect2(Vector2(px + 10, r.position.y + 6), Vector2(w + 16, 54))
	if box.end.x > r.end.x:
		box.position.x = px - box.size.x - 10
	draw_rect(box, Color(0.06, 0.07, 0.10, 0.95))
	draw_rect(box, Color(1, 1, 1, 0.18), false, 1.0)
	for k in range(lines.size()):
		draw_string(font, box.position + Vector2(8, 16 + k * 16), lines[k],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT_PRIMARY if k == 0 else TEXT_MUTED)


func _month_label(months_ago: int) -> String:
	var total := GameState.year * 12 + GameState.month - months_ago
	return "%s %d" % [Constants.MONTH_NAMES[posmod(total, 12)], total / 12]


static func _fmt(v: float) -> String:
	if v >= 10000.0:
		return "%.1fk" % (v / 1000.0)
	return "%d" % int(round(v))
