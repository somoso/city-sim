class_name UtilityMeter
extends Control
## A single bar showing how much of a utility's capacity is in use. The status colour is
## always paired with the wording in the label above it, never used on its own.

const TRACK := Color(1, 1, 1, 0.10)
const GOOD := Color("#0ca30c")
const WARNING := Color("#fab219")
const CRITICAL := Color("#d03b3b")

var demand := 0.0
var supply := 0.0


func _ready() -> void:
	# Only claim a height; the width is whatever the caller or the container gives it.
	custom_minimum_size.y = maxf(custom_minimum_size.y, 14.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_value(new_demand: float, new_supply: float) -> void:
	demand = new_demand
	supply = new_supply
	queue_redraw()


static func state_word(pct: float) -> String:
	if pct > 100.0:
		return "over capacity"
	if pct >= 85.0:
		return "running tight"
	return "comfortable"


static func state_color(pct: float) -> Color:
	if pct > 100.0:
		return CRITICAL
	if pct >= 85.0:
		return WARNING
	return GOOD


func _draw() -> void:
	var h := 10.0
	var y := (size.y - h) * 0.5
	draw_rect(Rect2(0, y, size.x, h), TRACK)
	if supply <= 0.0:
		if demand > 0.0:
			draw_rect(Rect2(0, y, size.x, h), Color(CRITICAL.r, CRITICAL.g, CRITICAL.b, 0.65))
		return
	var pct := demand / supply * 100.0
	var filled := clampf(pct / 100.0, 0.0, 1.0) * size.x
	draw_rect(Rect2(0, y, filled, h), state_color(pct))
	# Capacity marker, so "full" is readable even when demand overshoots.
	draw_line(Vector2(size.x - 1, y - 2), Vector2(size.x - 1, y + h + 2), Color(1, 1, 1, 0.45), 2.0)
