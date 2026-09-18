class_name Simulation
extends RefCounted
## Orchestrates one simulated month across every subsystem, in dependency order.


static func run_month(grid: CityGrid, state, rng: RandomNumberGenerator) -> Array[String]:
	var news: Array[String] = []
	RoadNetwork.run(grid)
	Utilities.run(grid, state)
	Services.run(grid, state)
	EnvironmentSim.run(grid)
	Demand.run(grid, state)
	var growth := ZoneGrowth.run(grid, state, rng)
	news.append_array(FireSim.run(grid, state, rng))
	# Development changed population/jobs; refresh the counts the HUD shows.
	Demand.run(grid, state)
	Budget.run(grid, state)

	if state.power_demand > state.power_supply and state.power_demand > 0:
		news.append("Brownouts reported: power demand exceeds supply.")
	if state.water_demand > state.water_supply and state.water_demand > 0:
		news.append("Water shortage: build more pumps or towers.")
	if state.funds < 0:
		news.append("The city is in debt! Cut spending or raise taxes.")
	if growth["abandoned"] > growth["grown"] and growth["abandoned"] > 3:
		news.append("Buildings are being abandoned across the city.")
	return news


## Recomputes derived layers without advancing time (used after loading or big edits).
static func refresh(grid: CityGrid, state) -> void:
	RoadNetwork.run(grid)
	Utilities.run(grid, state)
	Services.run(grid, state)
	EnvironmentSim.run(grid)
	Demand.run(grid, state)
