class_name BuildingDefs
extends RefCounted
## Static catalogue of placeable buildings and tool metadata.
##
## Every entry carries a `key`, which is both its sprite name (`civic_<key>`) and its path
## in data/balance.json (`buildings.<key>.<field>`), so a number can be retuned without
## touching this file.
##
## Fields: key, name, cost, upkeep (per month), size (footprint side), desc,
## power_out / water_out / waste_out (capacity supplied), power_use / water_use,
## pollution, coverage (kind) + radius, fire_risk, needs_water,
## tax_jobs / tax_wealth (private operations that pay commercial tax).

const B := Constants.Building
const T := Constants.Tool

const DEFS := {
	B.ROAD: {
		"key": "road", "name": "Road", "cost": 10, "upkeep": 0.5, "size": 1,
		"desc": "Connects zones. Carries power, water and refuse collection alongside traffic.",
	},
	B.RUBBLE: {
		"key": "rubble", "name": "Rubble", "cost": 0, "upkeep": 0, "size": 1,
		"desc": "Debris left after fire or disaster. Bulldoze to clear.",
	},

	# --- Power ---------------------------------------------------------------------
	B.POWER_COAL: {
		"key": "coal_plant", "name": "Coal Power Plant", "cost": 3000, "upkeep": 150, "size": 2,
		"power_out": 600, "pollution": 35, "fire_risk": 15,
		"desc": "Cheap and powerful, but heavily polluting.",
	},
	B.POWER_WIND: {
		"key": "wind_turbine", "name": "Wind Turbine", "cost": 800, "upkeep": 30, "size": 1,
		"power_out": 60, "pollution": 0, "fire_risk": 2,
		"desc": "Clean but low output. Great for small towns.",
	},
	B.POWER_NUCLEAR: {
		"key": "nuclear_plant", "name": "Nuclear Power Plant", "cost": 15000, "upkeep": 600, "size": 3,
		"power_out": 4000, "pollution": 4, "fire_risk": 8,
		"desc": "Enormous clean output at a steep price.",
	},

	# --- Water ---------------------------------------------------------------------
	B.WATER_PUMP: {
		"key": "water_pump", "name": "Water Pump", "cost": 1000, "upkeep": 50, "size": 1,
		"water_out": 400, "needs_water": true, "fire_risk": 2,
		"desc": "Must be placed next to water. High output.",
	},
	B.WATER_TOWER: {
		"key": "water_tower", "name": "Water Tower", "cost": 500, "upkeep": 25, "size": 1,
		"water_out": 120, "fire_risk": 2,
		"desc": "Works anywhere. Modest output.",
	},

	# --- Waste ---------------------------------------------------------------------
	B.LANDFILL: {
		"key": "landfill", "name": "Landfill", "cost": 1200, "upkeep": 60, "size": 2,
		"waste_out": 300, "pollution": 45, "fire_risk": 12,
		"desc": "Cheap tipping for 300 units of refuse, but it stinks and ruins the land nearby.",
	},
	B.INCINERATOR: {
		"key": "incinerator", "name": "Incinerator", "cost": 4500, "upkeep": 200, "size": 2,
		"waste_out": 700, "pollution": 28, "power_use": 6, "fire_risk": 14,
		"desc": "Burns 700 units of refuse in a small footprint. Still dirty, but far less so than tipping.",
	},
	B.RECYCLING_CENTRE: {
		"key": "recycling_centre", "name": "Recycling Centre", "cost": 6000, "upkeep": 260, "size": 2,
		"waste_out": 500, "pollution": 4, "power_use": 8, "water_use": 4, "fire_risk": 6,
		"desc": "Processes 500 units of refuse almost cleanly. Expensive to run.",
	},

	# --- Police --------------------------------------------------------------------
	B.POLICE: {
		"key": "police_station", "name": "Police Station", "cost": 1500, "upkeep": 120, "size": 2,
		"power_use": 4, "water_use": 2, "coverage": "police", "radius": 12, "fire_risk": 4,
		"desc": "Reduces crime within its coverage radius.",
	},
	B.PRISON: {
		"key": "prison", "name": "Prison", "cost": 6000, "upkeep": 300, "size": 3,
		"power_use": 8, "water_use": 6, "coverage": "police", "radius": 6, "fire_risk": 5,
		"tax_jobs": 40, "tax_wealth": 2,
		"desc": "Holds offenders from across the city. Taxed like a medium commercial block.\nKeep it away from housing: nobody wants to live next door.",
	},
	B.HIGH_SECURITY_PRISON: {
		"key": "high_security_prison", "name": "High Security Prison", "cost": 14000, "upkeep": 600, "size": 3,
		"power_use": 14, "water_use": 10, "coverage": "police", "radius": 8, "fire_risk": 4,
		"tax_jobs": 70, "tax_wealth": 3,
		"desc": "A serious facility with a serious price. Taxed like a high commercial block.",
	},

	# --- Fire ----------------------------------------------------------------------
	B.FIRE_STATION: {
		"key": "fire_station", "name": "Fire Station", "cost": 1500, "upkeep": 120, "size": 2,
		"power_use": 4, "water_use": 4, "coverage": "fire", "radius": 12, "fire_risk": 1,
		"desc": "Lowers fire risk and fights fires nearby.",
	},
	B.FIRE_HELIPAD: {
		"key": "fire_helipad", "name": "Fire Helicopter Base", "cost": 5000, "upkeep": 320, "size": 2,
		"power_use": 6, "water_use": 6, "coverage": "fire", "radius": 30, "fire_risk": 1,
		"desc": "Crews fly to the fire, so this covers a huge area regardless of roads.\nWorks exactly like a fire station, just much further.",
	},

	# --- Health --------------------------------------------------------------------
	B.GP_SURGERY: {
		"key": "gp_surgery", "name": "GP Surgery", "cost": 900, "upkeep": 70, "size": 1,
		"power_use": 2, "water_use": 2, "coverage": "health", "radius": 7, "fire_risk": 3,
		"desc": "A single doctor's practice. Cheap cover for a small neighbourhood.",
	},
	B.COMMUNITY_HOSPITAL: {
		"key": "community_hospital", "name": "Community Hospital", "cost": 2200, "upkeep": 170, "size": 2,
		"power_use": 6, "water_use": 5, "coverage": "health", "radius": 11, "fire_risk": 3,
		"desc": "A small hospital for a district.",
	},
	B.HOSPITAL: {
		"key": "hospital", "name": "General Hospital", "cost": 3500, "upkeep": 260, "size": 3,
		"power_use": 10, "water_use": 8, "coverage": "health", "radius": 14, "fire_risk": 3,
		"desc": "Keeps residents healthy and raises land value across a wide area.",
	},
	B.PRIVATE_HOSPITAL: {
		"key": "private_hospital", "name": "Private Hospital", "cost": 9000, "upkeep": 380, "size": 3,
		"power_use": 12, "water_use": 10, "coverage": "health", "radius": 14, "fire_risk": 3,
		"tax_jobs": 90, "tax_wealth": 3,
		"desc": "Costly to build, but it pays commercial tax at the high-wealth rate.",
	},

	# --- Education -----------------------------------------------------------------
	B.NURSERY: {
		"key": "nursery", "name": "Nursery", "cost": 700, "upkeep": 60, "size": 1,
		"power_use": 2, "water_use": 2, "coverage": "nursery", "radius": 6, "fire_risk": 3,
		"desc": "Early years care. Counts as an education building for medium-density housing.",
	},
	B.SCHOOL: {
		"key": "high_school", "name": "High School", "cost": 1800, "upkeep": 140, "size": 2,
		"power_use": 4, "water_use": 3, "coverage": "school", "radius": 10, "fire_risk": 4,
		"desc": "Educates residents to high school level, which high-density housing demands.",
	},
	B.UNIVERSITY: {
		"key": "university", "name": "University", "cost": 8000, "upkeep": 420, "size": 3,
		"power_use": 12, "water_use": 10, "coverage": "university", "radius": 16, "fire_risk": 4,
		"desc": "Graduates the workforce that high-density commercial towers need.",
	},

	# --- Other ---------------------------------------------------------------------
	B.PARK: {
		"key": "park", "name": "Park", "cost": 200, "upkeep": 10, "size": 1,
		"coverage": "park", "radius": 4, "fire_risk": 1,
		"desc": "Raises land value and absorbs pollution.",
	},
	B.DEMOLITION_DEPOT: {
		"key": "demolition_depot", "name": "Demolition Depot", "cost": 10000, "upkeep": 300, "size": 2,
		"power_use": 6, "water_use": 4, "fire_risk": 6,
		"desc": "Clears abandoned lots and rubble on its own, up to 100 at a time,\nthen rests for 30 seconds before the next sweep.",
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
	T.LANDFILL: B.LANDFILL,
	T.INCINERATOR: B.INCINERATOR,
	T.RECYCLING_CENTRE: B.RECYCLING_CENTRE,
	T.POLICE: B.POLICE,
	T.PRISON: B.PRISON,
	T.HIGH_SECURITY_PRISON: B.HIGH_SECURITY_PRISON,
	T.FIRE_STATION: B.FIRE_STATION,
	T.FIRE_HELIPAD: B.FIRE_HELIPAD,
	T.GP_SURGERY: B.GP_SURGERY,
	T.COMMUNITY_HOSPITAL: B.COMMUNITY_HOSPITAL,
	T.HOSPITAL: B.HOSPITAL,
	T.PRIVATE_HOSPITAL: B.PRIVATE_HOSPITAL,
	T.NURSERY: B.NURSERY,
	T.SCHOOL: B.SCHOOL,
	T.UNIVERSITY: B.UNIVERSITY,
	T.PARK: B.PARK,
	T.DEMOLITION_DEPOT: B.DEMOLITION_DEPOT,
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
	T.ZONE_I_LOW: "Agricultural",
	T.ZONE_I_MED: "Medium-density Industrial",
	T.ZONE_I_HIGH: "High-density Industrial",
	T.DEZONE: "De-zone",
}


static func get_def(building: int) -> Dictionary:
	return DEFS.get(building, {})


## Looks up a field, letting data/balance.json override the number in this file.
static func def_value(building: int, key: String, default_value = 0):
	var def: Dictionary = DEFS.get(building, {})
	var base = def.get(key, default_value)
	if typeof(base) == TYPE_FLOAT or typeof(base) == TYPE_INT:
		return Balance.building(def.get("key", ""), key, base)
	return base


static func building_key(building: int) -> String:
	return str(DEFS.get(building, {}).get("key", ""))


static func tool_cost(tool: int) -> int:
	if TOOL_BUILDING.has(tool):
		return int(def_value(TOOL_BUILDING[tool], "cost", 0))
	if TOOL_ZONE.has(tool):
		var density: int = TOOL_ZONE[tool][1]
		return int(Balance.nums("zones.cost", ZONE_COST)[density])
	if tool == T.BULLDOZE:
		return Balance.int_val("zones.bulldoze_cost", BULLDOZE_COST)
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


## Display name, taking building tools from the catalogue so the two never drift apart.
static func tool_name(tool: int) -> String:
	if TOOL_BUILDING.has(tool):
		return str(DEFS[TOOL_BUILDING[tool]].get("name", "Building"))
	return str(TOOL_NAMES.get(tool, "None"))
