class_name Demand
extends RefCounted
## RCI demand model. Positive values mean sims want to move in / businesses want to open.


static func run(grid: CityGrid, state) -> void:
	var pop := 0
	var com_jobs := 0
	var ind_jobs := 0
	var unpowered_lots := 0
	var developed := 0
	for i in range(grid.size):
		pop += grid.population[i]
		match grid.zone_type[i]:
			Constants.Zone.COM: com_jobs += grid.jobs[i]
			Constants.Zone.IND: ind_jobs += grid.jobs[i]
		if grid.is_developed(i):
			developed += 1
			if grid.powered[i] == 0:
				unpowered_lots += 1

	state.population = pop
	state.com_jobs = com_jobs
	state.ind_jobs = ind_jobs
	state.jobs_total = com_jobs + ind_jobs
	# Half the population is of working age; they fill whatever jobs exist.
	state.employed = mini(pop / 2, state.jobs_total)

	var workers := float(pop) * 0.5
	var jobs := float(com_jobs + ind_jobs)

	# Residential: people follow jobs. A young city always has some baseline pull.
	var r := 25.0
	if jobs > 0.0 or workers > 0.0:
		r += 70.0 * (jobs - workers) / maxf(jobs + workers, 1.0)
	r -= (float(state.tax["R"]) - 9.0) * 6.0
	if pop == 0:
		r = maxf(r, 40.0)

	# Commercial: driven by residents to serve, capped by existing supply.
	var c := 10.0
	var c_target := float(pop) * 0.28
	c += 70.0 * (c_target - float(com_jobs)) / maxf(c_target + float(com_jobs), 1.0)
	c -= (float(state.tax["C"]) - 9.0) * 6.0
	if pop < 30:
		c = minf(c, 0.0)

	# Industrial: has external demand so it can bootstrap a city.
	var ind := 30.0
	var i_target := float(pop) * 0.22 + 40.0
	ind += 60.0 * (i_target - float(ind_jobs)) / maxf(i_target + float(ind_jobs), 1.0)
	ind -= (float(state.tax["I"]) - 9.0) * 6.0

	# Unreliable power hurts everyone.
	if developed > 0:
		var frac := float(unpowered_lots) / float(developed)
		r -= frac * 30.0
		c -= frac * 30.0
		ind -= frac * 30.0

	state.demand["R"] = clampf(r, -100.0, 100.0)
	state.demand["C"] = clampf(c, -100.0, 100.0)
	state.demand["I"] = clampf(ind, -100.0, 100.0)
