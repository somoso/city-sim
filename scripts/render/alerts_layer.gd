class_name AlertsLayer
extends Node2D
## Draws the flashing warnings over lots and buildings that lack road access, power or
## water: a pulsing red outline on every affected footprint, plus one alert badge per
## contiguous block of lots that share the same problem.
##
## Badges are clustered rather than drawn per tile, because a freshly zoned district can
## easily be a hundred lots and a badge on each one hides the city underneath them.
##
## This is a separate layer from WorldLayer because it animates every frame, while the
## world layer only redraws chunks that actually changed.

## Seconds per flash cycle.
const PULSE_PERIOD := 1.1
## Horizontal gap between two badges on the same cluster, in sprite pixels before scaling.
const BADGE_GAP := 62.0
## World-space slack around the visible area, so badges anchored just off-screen still show.
const CULL_PAD := 400.0

var grid: CityGrid = null
## Per-tile bitmask of Alerts.NO_* flags. Kept for the HUD's jump-to-problem buttons.
var flags := PackedByteArray()
var counts := { "road": 0, "power": 0, "water": 0 }
## One entry per contiguous group of tiles sharing a problem:
## { "tile": int, "flags": int, "count": int }.
var clusters: Array = []

var _time := 0.0
var _has_alerts := false
var draw_count := 0


func setup(g: CityGrid) -> void:
	grid = g
	_time = 0.0
	rebuild()


## Recomputes which tiles are in trouble, groups them, and tells the HUD the new totals.
func rebuild() -> void:
	if grid == null:
		return
	var result := Alerts.compute(grid)
	flags = result["flags"]
	counts = result["counts"]
	_has_alerts = counts["road"] + counts["power"] + counts["water"] > 0
	clusters = _build_clusters()
	Events.alerts_changed.emit(counts)
	queue_redraw()


func has_alerts() -> bool:
	return _has_alerts


## Flood-fills tiles that share an identical problem into blocks, and picks the tile
## nearest each block's centre to carry its badge.
func _build_clusters() -> Array:
	var out: Array = []
	if not _has_alerts:
		return out
	var seen := PackedByteArray()
	seen.resize(grid.size)
	seen.fill(0)
	var members := PackedInt32Array()
	for start in range(grid.size):
		if flags[start] == 0 or seen[start] == 1:
			continue
		var f := flags[start]
		members.clear()
		members.append(start)
		seen[start] = 1
		var head := 0
		var sum_x := 0
		var sum_y := 0
		while head < members.size():
			var cur := members[head]
			head += 1
			sum_x += grid.x_of(cur)
			sum_y += grid.y_of(cur)
			for n in grid.neighbors4(cur):
				if seen[n] == 0 and flags[n] == f:
					seen[n] = 1
					members.append(n)
		var count := members.size()
		var cx := float(sum_x) / float(count)
		var cy := float(sum_y) / float(count)
		var best := members[0]
		var best_d := INF
		for m in members:
			var d := Vector2(float(grid.x_of(m)) - cx, float(grid.y_of(m)) - cy).length_squared()
			if d < best_d:
				best_d = d
				best = m
		out.append({ "tile": best, "flags": f, "count": count })
	return out


func _process(delta: float) -> void:
	if not _has_alerts or not visible:
		return
	_time += delta
	queue_redraw()


func _camera_zoom() -> float:
	var cam := get_viewport().get_camera_2d()
	if cam == null or cam.zoom.x <= 0.0:
		return 1.0
	return cam.zoom.x


## Tile-space bounding box of what the camera can see, padded for tall sprites.
func _visible_tile_rect() -> Rect2i:
	var full := Rect2i(0, 0, grid.width, grid.height)
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return full
	var half := get_viewport_rect().size * 0.5 / cam.zoom
	var c := cam.get_screen_center_position()
	var lo := Vector2i(grid.width, grid.height)
	var hi := Vector2i(-1, -1)
	for corner in [c - half, c + Vector2(half.x, -half.y), c + half, c + Vector2(-half.x, half.y)]:
		var t: Vector2i = IsoMath.screen_to_tile(corner)
		lo.x = mini(lo.x, t.x)
		lo.y = mini(lo.y, t.y)
		hi.x = maxi(hi.x, t.x)
		hi.y = maxi(hi.y, t.y)
	var pad := 8
	lo -= Vector2i(pad, pad)
	hi += Vector2i(pad, pad)
	lo.x = clampi(lo.x, 0, grid.width)
	lo.y = clampi(lo.y, 0, grid.height)
	hi.x = clampi(hi.x + 1, 0, grid.width)
	hi.y = clampi(hi.y + 1, 0, grid.height)
	if hi.x <= lo.x or hi.y <= lo.y:
		return Rect2i(0, 0, 0, 0)
	return Rect2i(lo, hi - lo)


## World-space rectangle the camera can see, padded so badges just off-screen still draw.
func _visible_world_rect() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return Rect2(-1e9, -1e9, 2e9, 2e9)
	var size := get_viewport_rect().size / cam.zoom
	return Rect2(cam.get_screen_center_position() - size * 0.5, size).grow(CULL_PAD)


func _draw() -> void:
	draw_count += 1
	if grid == null or not _has_alerts or flags.size() != grid.size:
		return
	var pulse := 0.5 + 0.5 * sin(_time / PULSE_PERIOD * TAU)
	var zoom := _camera_zoom()
	var outline_w := clampf(3.0 / zoom, 2.0, 9.0)
	var edge := Color(1.0, 0.24, 0.18, 0.25 + 0.45 * pulse)
	var glow := Color(1.0, 0.32, 0.22, 0.07 + 0.10 * pulse)

	# Every affected footprint gets the pulsing red outline, so the extent of the problem
	# is obvious even though only one badge is drawn per block.
	var r := _visible_tile_rect()
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := grid.idx(x, y)
			if flags[i] == 0:
				continue
			var fsize := 1
			if grid.has_civic(i):
				fsize = int(BuildingDefs.def_value(grid.building[i], "size", 1))
			var d := IsoMath.diamond(x, y, fsize)
			draw_colored_polygon(d, glow)
			draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), edge, outline_w)

	# Badges keep a nearly constant on-screen size so they stay readable at any zoom.
	var badge_scale := clampf(pow(1.0 / zoom, 0.7), 0.45, 1.6)
	var view := _visible_world_rect()
	var font := ThemeDB.fallback_font
	for c in clusters:
		_draw_badges(c, pulse, badge_scale, view, font)


func _draw_badges(cluster: Dictionary, pulse: float, badge_scale: float, view: Rect2, font: Font) -> void:
	var i: int = cluster["tile"]
	var f: int = cluster["flags"]
	var x := grid.x_of(i)
	var y := grid.y_of(i)

	var fsize := 1
	var sprite_name := ""
	if grid.has_civic(i):
		var type := grid.building[i]
		fsize = int(BuildingDefs.def_value(type, "size", 1))
		sprite_name = Sprites.civic_sprite(type)
	elif grid.level[i] > 0:
		sprite_name = Sprites.zone_sprite(grid.zone_type[i], grid.zone_density[i], grid.level[i], grid.wealth[i])
	else:
		sprite_name = Sprites.lot_sprite(grid.zone_type[i], grid.zone_density[i])

	var rect := Sprites.rect_of(sprite_name, x, y, fsize)
	var top_y := rect.position.y if rect.size.y > 0.0 else IsoMath.tile_to_screen(x, y).y
	# A gentle bob, offset per block so they do not all move in lockstep.
	var bob := sin(_time * 2.4 + float(i) * 0.7) * 3.0 * badge_scale
	var anchor := Vector2(IsoMath.tile_to_screen(x, y).x, top_y - 4.0 * badge_scale + bob)
	if not view.has_point(anchor):
		return

	var kinds: Array[String] = []
	if f & Alerts.NO_ROAD:
		kinds.append("road")
	if f & Alerts.NO_POWER:
		kinds.append("power")
	if f & Alerts.NO_WATER:
		kinds.append("water")
	if kinds.is_empty():
		return

	for k in range(kinds.size()):
		var offset := (float(k) - float(kinds.size() - 1) * 0.5) * BADGE_GAP * badge_scale
		var at := anchor + Vector2(offset, 0.0)
		Sprites.draw_badge(self, "alert_%s" % kinds[k], at, badge_scale)
		# The "hot" frame fades in and out over the base frame to make the badge flash.
		Sprites.draw_badge(self, "alert_%s_hot" % kinds[k], at, badge_scale, Color(1, 1, 1, pulse))

	var count := int(cluster["count"])
	if count > 1:
		_draw_count_chip(font, anchor, kinds.size(), badge_scale, count)


## A small chip showing how many lots this badge stands for.
func _draw_count_chip(font: Font, anchor: Vector2, badges: int, badge_scale: float, count: int) -> void:
	var text := "x%d" % count
	var font_size := int(round(17.0 * badge_scale))
	if font_size < 8:
		return
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var half_row := float(badges) * BADGE_GAP * badge_scale * 0.5
	var center := anchor + Vector2(half_row + size.x * 0.5, -58.0 * badge_scale)
	var pad := Vector2(7.0, 3.0) * badge_scale
	var rect := Rect2(center - size * 0.5 - pad, size + pad * 2.0)
	draw_rect(rect, Color(0.09, 0.05, 0.06, 0.92))
	draw_rect(rect, Color(1.0, 0.28, 0.22, 0.95), false, maxf(1.0, 2.0 * badge_scale))
	draw_string(font, Vector2(center.x - size.x * 0.5, center.y + size.y * 0.32), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 0.92, 0.9))
