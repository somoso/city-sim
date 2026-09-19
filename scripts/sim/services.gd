class_name Services
extends RefCounted
## Radial coverage for civic buildings, scaled by department funding.

## Coverage kinds that draw on the same budget line. Nurseries, schools and universities
## are all funded from education.
const FUNDING_KEYS := {
	"police": "police",
	"fire": "fire",
	"school": "school",
	"nursery": "school",
	"university": "school",
	"health": "health",
}


static func funding_key(coverage_kind: String) -> String:
	return str(FUNDING_KEYS.get(coverage_kind, coverage_kind))



static func run(grid: CityGrid, state) -> void:
	grid.cov_police.fill(0.0)
	grid.cov_fire.fill(0.0)
	grid.cov_school.fill(0.0)
	grid.cov_nursery.fill(0.0)
	grid.cov_university.fill(0.0)
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
		var radius := float(BuildingDefs.def_value(type, "radius", def["radius"]))
		var strength := 1.0
		var budget_kind := funding_key(kind)
		if state.funding.has(budget_kind):
			strength = float(state.funding[budget_kind]) / 100.0
		# Unpowered services operate at reduced effectiveness.
		if float(BuildingDefs.def_value(type, "power_use", 0)) > 0.0 and grid.powered[origin] == 0:
			strength *= 0.4
		var target: PackedFloat32Array
		match kind:
			"police": target = grid.cov_police
			"fire": target = grid.cov_fire
			"school": target = grid.cov_school
			"nursery": target = grid.cov_nursery
			"university": target = grid.cov_university
			"health": target = grid.cov_health
			"park": target = grid.cov_park
			_: continue
		var fsize := int(BuildingDefs.def_value(type, "size", 1))
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
			"nursery": grid.cov_nursery = target
			"university": grid.cov_university = target
			"health": grid.cov_health = target
			"park": grid.cov_park = target
