extends Node
## Holds the active city and all player-facing numbers. Autoloaded as `GameState`.

var grid: CityGrid = null
var city_name := "New City"
var map_seed := 0

var funds: int = Constants.START_FUNDS
var year: int = Constants.START_YEAR
var month: int = 0 # 0-based
var months_elapsed: int = 0

var tax := { "R": 9, "C": 9, "I": 9 }
var funding := { "police": 100, "fire": 100, "school": 100, "health": 100 }
var demand := { "R": 0.0, "C": 0.0, "I": 0.0 }

var population := 0
var com_jobs := 0
var ind_jobs := 0
var jobs_total := 0
var power_supply := 0.0
var power_demand := 0.0
var water_supply := 0.0
var water_demand := 0.0
## One { "supply": float, "demand": float } per separately connected grid.
var power_networks: Array = []
var water_networks: Array = []

## Rolling monthly history for the utilisation graphs, oldest first.
var power_demand_history := PackedFloat32Array()
var power_supply_history := PackedFloat32Array()
var water_demand_history := PackedFloat32Array()
var water_supply_history := PackedFloat32Array()
var last_income := { "R": 0.0, "C": 0.0, "I": 0.0, "total": 0.0 }
var last_expenses := {}
var last_expenses_total := 0.0

var disasters_enabled := false
var speed: int = 1
var current_tool: int = Constants.Tool.NONE
var current_overlay: int = Constants.Overlay.NONE

var rng := RandomNumberGenerator.new()
var news: Array[String] = []

const MAX_NEWS := 40
## Months of utilisation kept for the graphs (ten years).
const HISTORY_MONTHS := 120


func has_city() -> bool:
	return grid != null


func new_city(width: int, height: int, seed_value: int, name: String, disasters: bool) -> void:
	grid = CityGrid.new(width, height)
	map_seed = seed_value
	city_name = name if name.strip_edges() != "" else "New City"
	disasters_enabled = disasters
	rng.seed = seed_value
	TerrainGenerator.generate(grid, seed_value)
	funds = Constants.START_FUNDS
	year = Constants.START_YEAR
	month = 0
	months_elapsed = 0
	tax = { "R": 9, "C": 9, "I": 9 }
	funding = { "police": 100, "fire": 100, "school": 100, "health": 100 }
	demand = { "R": 0.0, "C": 0.0, "I": 0.0 }
	population = 0
	com_jobs = 0
	ind_jobs = 0
	jobs_total = 0
	speed = 1
	current_tool = Constants.Tool.NONE
	current_overlay = Constants.Overlay.NONE
	news.clear()
	_clear_history()
	Simulation.refresh(grid, self)
	_record_history()
	post_message("Welcome to %s, Mayor! Lay roads and zone land to get started." % city_name)
	Events.city_started.emit()


func tick_month() -> void:
	if grid == null:
		return
	var reports := Simulation.run_month(grid, self, rng)
	_record_history()
	month += 1
	months_elapsed += 1
	if month >= 12:
		month = 0
		year += 1
	for r in reports:
		post_message(r)
	Events.month_ticked.emit()
	Events.world_changed.emit()
	Events.funds_changed.emit(funds)


func _clear_history() -> void:
	power_demand_history = PackedFloat32Array()
	power_supply_history = PackedFloat32Array()
	water_demand_history = PackedFloat32Array()
	water_supply_history = PackedFloat32Array()


func _record_history() -> void:
	_push_history(power_demand_history, power_demand)
	_push_history(power_supply_history, power_supply)
	_push_history(water_demand_history, water_demand)
	_push_history(water_supply_history, water_supply)


func _push_history(buffer: PackedFloat32Array, value: float) -> void:
	buffer.append(value)
	while buffer.size() > HISTORY_MONTHS:
		buffer.remove_at(0)


## Monthly net change in the treasury from the last budget run.
func net_income() -> float:
	return float(last_income.get("total", 0.0)) - last_expenses_total


func date_string() -> String:
	return "%s %d" % [Constants.MONTH_NAMES[month], year]


func set_speed(s: int) -> void:
	speed = clampi(s, 0, Constants.MONTH_SECONDS.size() - 1)
	Events.speed_changed.emit(speed)


func set_tool(t: int) -> void:
	current_tool = t
	Events.tool_changed.emit(t)


func set_overlay(o: int) -> void:
	current_overlay = o
	Events.overlay_changed.emit(o)


func spend(amount: int) -> bool:
	if amount > funds:
		return false
	funds -= amount
	Events.funds_changed.emit(funds)
	return true


func post_message(text: String) -> void:
	news.append(text)
	while news.size() > MAX_NEWS:
		news.remove_at(0)
	Events.message.emit(text)


## Serialises everything needed to restore this city.
func to_dict() -> Dictionary:
	var g := {
		"width": grid.width,
		"height": grid.height,
		"int": {},
		"float": {},
	}
	for layer_name in CityGrid.persisted_int_layers():
		var arr: PackedInt32Array = grid.get(layer_name)
		g["int"][layer_name] = Marshalls.raw_to_base64(arr.to_byte_array())
	for layer_name in CityGrid.persisted_float_layers():
		var arr: PackedFloat32Array = grid.get(layer_name)
		g["float"][layer_name] = Marshalls.raw_to_base64(arr.to_byte_array())
	return {
		"version": 1,
		"city_name": city_name,
		"map_seed": map_seed,
		"funds": funds,
		"year": year,
		"month": month,
		"months_elapsed": months_elapsed,
		"tax": tax,
		"funding": funding,
		"disasters_enabled": disasters_enabled,
		"rng_state": rng.state,
		"news": news,
		"history": {
			"power_demand": Array(power_demand_history),
			"power_supply": Array(power_supply_history),
			"water_demand": Array(water_demand_history),
			"water_supply": Array(water_supply_history),
		},
		"grid": g,
	}


func from_dict(d: Dictionary) -> bool:
	if not d.has("grid"):
		return false
	var g: Dictionary = d["grid"]
	var w := int(g.get("width", 64))
	var h := int(g.get("height", 64))
	grid = CityGrid.new(w, h)
	for layer_name in CityGrid.persisted_int_layers():
		if g["int"].has(layer_name):
			var bytes := Marshalls.base64_to_raw(g["int"][layer_name])
			var arr := bytes.to_int32_array()
			if arr.size() == grid.size:
				grid.set(layer_name, arr)
	for layer_name in CityGrid.persisted_float_layers():
		if g["float"].has(layer_name):
			var bytes := Marshalls.base64_to_raw(g["float"][layer_name])
			var arr := bytes.to_float32_array()
			if arr.size() == grid.size:
				grid.set(layer_name, arr)
	city_name = str(d.get("city_name", "Loaded City"))
	map_seed = int(d.get("map_seed", 0))
	funds = int(d.get("funds", Constants.START_FUNDS))
	year = int(d.get("year", Constants.START_YEAR))
	month = int(d.get("month", 0))
	months_elapsed = int(d.get("months_elapsed", 0))
	tax = { "R": 9, "C": 9, "I": 9 }
	for k in ["R", "C", "I"]:
		if d.get("tax", {}).has(k):
			tax[k] = int(d["tax"][k])
	funding = { "police": 100, "fire": 100, "school": 100, "health": 100 }
	for k in funding.keys():
		if d.get("funding", {}).has(k):
			funding[k] = int(d["funding"][k])
	disasters_enabled = bool(d.get("disasters_enabled", false))
	rng.seed = map_seed
	if d.has("rng_state"):
		rng.state = int(d["rng_state"])
	news.clear()
	for n in d.get("news", []):
		news.append(str(n))
	_clear_history()
	var hist: Dictionary = d.get("history", {})
	for entry in [["power_demand", power_demand_history], ["power_supply", power_supply_history],
			["water_demand", water_demand_history], ["water_supply", water_supply_history]]:
		var buffer: PackedFloat32Array = entry[1]
		for v in hist.get(entry[0], []):
			buffer.append(float(v))
		set(entry[0] + "_history", buffer)
	speed = 1
	current_tool = Constants.Tool.NONE
	current_overlay = Constants.Overlay.NONE
	Simulation.refresh(grid, self)
	Events.city_started.emit()
	return true
