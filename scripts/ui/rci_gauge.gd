class_name RCIGauge
extends Control
## The classic three-bar demand indicator.


func _ready() -> void:
	custom_minimum_size = Vector2(78, 40)
	tooltip_text = "RCI demand: Residential / Commercial / Industrial"
	Events.month_ticked.connect(queue_redraw)
	Events.city_started.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var mid := h * 0.5
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.35))
	draw_line(Vector2(0, mid), Vector2(w, mid), Color(1, 1, 1, 0.5), 1.0)
	var keys := ["R", "C", "I"]
	var colors := [Constants.ZONE_COLORS[Constants.Zone.RES], Constants.ZONE_COLORS[Constants.Zone.COM], Constants.ZONE_COLORS[Constants.Zone.IND]]
	var bar_w := (w - 16.0) / 3.0
	for k in range(3):
		var v: float = GameState.demand[keys[k]] / 100.0
		var x := 4.0 + float(k) * (bar_w + 4.0)
		var bh := absf(v) * (mid - 2.0)
		var col: Color = colors[k]
		if v < 0.0:
			col = Color(0.9, 0.25, 0.25)
			draw_rect(Rect2(x, mid, bar_w, bh), col)
		else:
			draw_rect(Rect2(x, mid - bh, bar_w, bh), col)
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(x + bar_w * 0.5 - 4.0, h - 2.0), keys[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.85))
