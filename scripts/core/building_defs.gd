class_name BuildingDefs
extends RefCounted
## Static catalogue of placeable buildings and tool metadata.

const B := Constants.Building
const T := Constants.Tool

## Building definitions. Keys are Constants.Building values.
## Fields: name, cost, upkeep (per month), size (footprint side), color, height (px),
## power_out, water_out, power_use, water_use, pollution, coverage (kind), radius,
## fire_risk, needs_water (bool), desc.
const DEFS := {
	B.ROAD: {
		"name": "Road", "cost": 10, "upkeep": 0.5, "size": 1,
		"color": Color(0.30, 0.30, 0.32), "height": 0,
		"desc": "Connects zones. Carries power and water alongside traffic.",
	},
	B.RUBBLE: {
		"name": "Rubble", "cost": 0, "upkeep": 0, "size": 1,
		"color": Color(0.45, 0.40, 0.35), "height": 0,
		"desc": "Debris left after fire or disaster. Bulldoze to clear.",
	},
	B.POWER_COAL: {
		"name": "Coal Power Plant", "cost": 3000, "upkeep": 150, "size": 2,
		"color": Color(0.40, 0.36, 0.34), "height": 42,
		"power_out": 600, "pollution": 35, "fire_risk": 15,
		"desc": "Cheap and powerful, but heavily polluting.",
	},
	B.POWER_WIND: {
		"name": "Wind Turbine", "cost": 800, "upkeep": 30, "size": 1,
		"color": Color(0.85, 0.87, 0.90), "height": 56,
		"power_out": 60, "pollution": 0, "fire_risk": 2,
		"desc": "Clean but low output. Great for small towns.",
	},
	B.POWER_NUCLEAR: {
		"name": "Nuclear Power Plant", "cost": 15000, "upkeep": 600, "size": 3,
		"color": Color(0.70, 0.75, 0.72), "height": 60,
		"power_out": 4000, "pollution": 4, "fire_risk": 8,
		"desc": "Enormous clean output at a steep price.",
	},
	B.WATER_PUMP: {
		"name": "Water Pump", "cost": 1000, "upkeep": 50, "size": 1,
		"color": Color(0.35, 0.55, 0.85), "height": 20,
		"water_out": 400, "needs_water": true, "fire_risk": 2,
		"desc": "Must be placed next to water. High output.",
	},
	B.WATER_TOWER: {
		"name": "Water Tower", "cost": 500, "upkeep": 25, "size": 1,
		"color": Color(0.55, 0.70, 0.90), "height": 48,
		"water_out": 120, "fire_risk": 2,
		"desc": "Works anywhere. Modest output.",
	},
	B.POLICE: {
		"name": "Police Station", "cost": 1500, "upkeep": 120, "size": 2,
		"color": Color(0.25, 0.35, 0.75), "height": 28,
		"power_use": 4, "water_use": 2, "coverage": "police", "radius": 12, "fire_risk": 4,
		"desc": "Reduces crime within its coverage radius.",
	},
	B.FIRE_STATION: {
		"name": "Fire Station", "cost": 1500, "upkeep": 120, "size": 2,
		"color": Color(0.85, 0.25, 0.20), "height": 28,
		"power_use": 4, "water_use": 4, "coverage": "fire", "radius": 12, "fire_risk": 1,
		"desc": "Lowers fire risk and fights fires nearby.",
	},
	B.SCHOOL: {
		"name": "Elementary School", "cost": 1800, "upkeep": 140, "size": 2,
		"color": Color(0.90, 0.60, 0.25), "height": 24,
		"power_use": 4, "water_use": 3, "coverage": "school", "radius": 10, "fire_risk": 4,
		"desc": "Educates residents and raises nearby land value.",
	},
	B.HOSPITAL: {
		"name": "Hospital", "cost": 3500, "upkeep": 260, "size": 3,
		"color": Color(0.95, 0.95, 0.98), "height": 36,
		"power_use": 10, "water_use": 8, "coverage": "health", "radius": 14, "fire_risk": 3,
		"desc": "Keeps residents healthy and boosts land value.",
	},
	B.PARK: {
		"name": "Park", "cost": 200, "upkeep": 10, "size": 1,
		"color": Color(0.35, 0.65, 0.30), "height": 0,
		"coverage": "park", "radius": 4, "fire_risk": 1,
		"desc": "Raises land value and absorbs pollution.",
	},
}

## Tools that place a building.
const TOOL_BUILDING := {
	T.ROAD: B.ROAD,
	T.POWER_COAL: B.POWER_COAL,
	T.POWER_WIND: B.POWER_WIND,
	T.POWER_NUCLEAR: B.POWER_NUCLEAR,
	T.WATER_PUMP: B.WATER_PUMP,
	T.WATER_TOWER: B.WATER_TOWER,
	T.POLICE: B.POLICE,
	T.FIRE_STATION: B.FIRE_STATION,
	T.SCHOOL: B.SCHOOL,
	T.HOSPITAL: B.HOSPITAL,
	T.PARK: B.PARK,
}

## Tools that zone tiles: tool -> [zone type, density].
const TOOL_ZONE := {
	T.ZONE_R_LOW: [Constants.Zone.RES, 1],
	T.ZONE_R_MED: [Constants.Zone.RES, 2],
	T.ZONE_R_HIGH: [Constants.Zone.RES, 3],
	T.ZONE_C_LOW: [Constants.Zone.COM, 1],
	T.ZONE_C_MED: [Constants.Zone.COM, 2],
	T.ZONE_C_HIGH: [Constants.Zone.COM, 3],
	T.ZONE_I_LOW: [Constants.Zone.IND, 1],
	T.ZONE_I_MED: [Constants.Zone.IND, 2],
	T.ZONE_I_HIGH: [Constants.Zone.IND, 3],
}

## Per-tile cost of zoning by density.
const ZONE_COST := [0, 10, 25, 60]
const BULLDOZE_COST := 5

const TOOL_NAMES := {
	T.NONE: "None",
	T.QUERY: "Query",
	T.BULLDOZE: "Bulldoze",
	T.ROAD: "Road",
	T.ZONE_R_LOW: "Low-density Residential",
	T.ZONE_R_MED: "Medium-density Residential",
	T.ZONE_R_HIGH: "High-density Residential",
	T.ZONE_C_LOW: "Low-density Commercial",
	T.ZONE_C_MED: "Medium-density Commercial",
	T.ZONE_C_HIGH: "High-density Commercial",
	T.ZONE_I_LOW: "Low-density Industrial",
	T.ZONE_I_MED: "Medium-density Industrial",
	T.ZONE_I_HIGH: "High-density Industrial",
	T.DEZONE: "De-zone",
	T.POWER_COAL: "Coal Power Plant",
	T.POWER_WIND: "Wind Turbine",
	T.POWER_NUCLEAR: "Nuclear Power Plant",
	T.WATER_PUMP: "Water Pump",
	T.WATER_TOWER: "Water Tower",
	T.POLICE: "Police Station",
	T.FIRE_STATION: "Fire Station",
	T.SCHOOL: "Elementary School",
	T.HOSPITAL: "Hospital",
	T.PARK: "Park",
}


static func get_def(building: int) -> Dictionary:
	return DEFS.get(building, {})


static func def_value(building: int, key: String, default_value = 0):
	var def: Dictionary = DEFS.get(building, {})
	return def.get(key, default_value)


static func tool_cost(tool: int) -> int:
	if TOOL_BUILDING.has(tool):
		return int(DEFS[TOOL_BUILDING[tool]]["cost"])
	if TOOL_ZONE.has(tool):
		return ZONE_COST[TOOL_ZONE[tool][1]]
	if tool == T.BULLDOZE:
		return BULLDOZE_COST
	return 0


static func tool_is_zone(tool: int) -> bool:
	return TOOL_ZONE.has(tool)


static func tool_is_building(tool: int) -> bool:
	return TOOL_BUILDING.has(tool)


## True for tools applied over a dragged rectangle (zones, bulldoze, de-zone).
static func tool_is_area(tool: int) -> bool:
	return TOOL_ZONE.has(tool) or tool == T.BULLDOZE or tool == T.DEZONE


## True for tools applied along a dragged line (roads).
static func tool_is_line(tool: int) -> bool:
	return tool == T.ROAD
