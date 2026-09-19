class_name Society
extends RefCounted
## What the population is made of: how many are employed, how well educated they are, and
## what kind of housing they live in. These shares are what gate the denser zones, so a
## city has to build schools and a university before it can grow upward.

## Fraction of residents who must have reached high school before high-density housing
## will move in, and the university share high-density commercial wants. Both are
## overridable in data/balance.json.
const HIGH_RES_EDUCATED_SHARE := 0.40
const HIGH_COM_UNIVERSITY_SHARE := 0.20
const MED_COM_MEDIUM_RES_SHARE := 0.25
## How fast the education shares move toward their target each month.
const EDUCATION_DRIFT := 0.12


static func run(grid: CityGrid, state) -> void:
	var pop_total := 0
	var pop_medium := 0
	var covered_school := 0.0
	var covered_university := 0.0
	var covered_nursery := 0.0

	for i in range(grid.size):
		if grid.zone_type[i] != Constants.Zone.RES or grid.level[i] <= 0:
			continue
		var pop := grid.population[i]
		if pop <= 0:
			continue
		pop_total += pop
		if grid.zone_density[i] == 2:
			pop_medium += pop
		covered_school += float(pop) * clampf(grid.cov_school[i], 0.0, 1.0)
		covered_university += float(pop) * clampf(grid.cov_university[i], 0.0, 1.0)
		covered_nursery += float(pop) * clampf(grid.cov_nursery[i], 0.0, 1.0)

	state.medium_res_share = 0.0 if pop_total == 0 else float(pop_medium) / float(pop_total)

	# Schooling is a stock, not a switch: building a school raises the educated share of the
	# population over the following months rather than instantly.
	var drift := Balance.num("society.education_drift", EDUCATION_DRIFT)
	var school_target := 0.0 if pop_total == 0 else covered_school / float(pop_total)
	var uni_target := 0.0 if pop_total == 0 else covered_university / float(pop_total)
	var nursery_target := 0.0 if pop_total == 0 else covered_nursery / float(pop_total)
	state.educated_share = lerpf(state.educated_share, school_target, drift)
	state.university_share = lerpf(state.university_share, uni_target, drift)
	state.nursery_share = lerpf(state.nursery_share, nursery_target, drift)

	state.has_education_building = _has_education_building(grid)


static func _has_education_building(grid: CityGrid) -> bool:
	for origin in grid.civic_origins():
		var kind := str(BuildingDefs.def_value(grid.building[origin], "coverage", ""))
		if kind == "nursery" or kind == "school" or kind == "university":
			return true
	return false


## Why a lot of this zone and density cannot develop yet, or "" when nothing is in the way.
## Used by both the growth rules and the query panel, so the two always agree.
static func growth_blocker(state, zone: int, density: int) -> String:
	if zone == Constants.Zone.RES:
		if density == 2 and Balance.flag("society.medium_res_requires_school", true) \
				and not state.has_education_building:
			return "needs any education building in the city"
		if density == 3:
			var need := Balance.num("society.high_res_educated_share", HIGH_RES_EDUCATED_SHARE)
			if state.educated_share < need:
				return "needs %d%% of residents schooled to high school (now %d%%)" % [
					int(round(need * 100.0)), int(round(state.educated_share * 100.0))]
	elif zone == Constants.Zone.COM:
		if density == 2:
			var need_med := Balance.num("society.medium_com_medium_res_share", MED_COM_MEDIUM_RES_SHARE)
			if state.medium_res_share < need_med:
				return "needs %d%% of residents in medium-density housing (now %d%%)" % [
					int(round(need_med * 100.0)), int(round(state.medium_res_share * 100.0))]
		if density == 3:
			var need_uni := Balance.num("society.high_com_university_share", HIGH_COM_UNIVERSITY_SHARE)
			if state.university_share < need_uni:
				return "needs %d%% of residents university educated (now %d%%)" % [
					int(round(need_uni * 100.0)), int(round(state.university_share * 100.0))]
	return ""
