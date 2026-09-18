class_name Services
extends RefCounted
## Radial coverage for civic buildings, scaled by department funding.


static func run(grid: CityGrid, state) -> void:
	grid.cov_police.fill(0.0)
	grid.cov_fire.fill(0.0)
	grid.cov_school.fill(0.0)
	grid.cov_health.fill(0.0)
	grid.cov_park.fill(0.0)

	for origin in grid.civic_origins():
		var type := grid.building[origin]
		var def := BuildingDefs.get_def(type)
		if not def.has("coverage"):
			continue
		if grid.burning[origin] > 0:
			continue
		var kind: String = def["coverage"]
		var radius := float(def["radius"])
		var strength := 1.0
		if state.funding.has(kind):
			strength = float(state.funding[kind]) / 100.0
		# Unpowered services operate at reduced effectiveness.
		if def.get("power_use", 0) > 0 and grid.powered[origin] == 0:
			strength *= 0.4
		var target: PackedFloat32Array
		match kind:
			"police": target = grid.cov_police
			"fire": target = grid.cov_fire
			"school": target = grid.cov_school
			"health": target = grid.cov_health
			"park": target = grid.cov_park
			_: continue
		var fsize := int(def.get("size", 1))
		var cx := float(grid.x_of(origin)) + float(fsize - 1) * 0.5
		var cy := float(grid.y_of(origin)) + float(fsize - 1) * 0.5
		var r := int(ceil(radius))
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var x := int(round(cx)) + dx
				var y := int(round(cy)) + dy
				if not grid.in_bounds(x, y):
					continue
				var d := Vector2(float(x) - cx, float(y) - cy).length()
				if d > radius:
					continue
				var v := strength * (1.0 - 0.6 * (d / radius))
				var i := grid.idx(x, y)
				if v > target[i]:
					target[i] = v
		# Assign back for the PackedFloat32Array copy semantics.
		match kind:
			"police": grid.cov_police = target
			"fire": grid.cov_fire = target
			"school": grid.cov_school = target
			"health": grid.cov_health = target
			"park": grid.cov_park = target
