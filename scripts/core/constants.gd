class_name Constants
extends RefCounted
## Shared enums and tuning constants used across the simulation, renderer and UI.

const TILE_W := 64
const TILE_H := 32
const CHUNK_SIZE := 16

const START_YEAR := 2000
const START_FUNDS := 50000

## Seconds per simulated month for each speed setting (index 0 = paused).
const MONTH_SECONDS := [0.0, 2.0, 1.0, 0.4]

enum Terrain { WATER, GRASS, FOREST, SAND }

enum Zone { NONE, RES, COM, IND }

enum Building {
	NONE,
	ROAD,
	RUBBLE,
	POWER_COAL,
	POWER_WIND,
	POWER_NUCLEAR,
	WATER_PUMP,
	WATER_TOWER,
	POLICE,
	FIRE_STATION,
	SCHOOL,
	HOSPITAL,
	PARK,
}

enum Tool {
	NONE,
	QUERY,
	BULLDOZE,
	ROAD,
	ZONE_R_LOW,
	ZONE_R_MED,
	ZONE_R_HIGH,
	ZONE_C_LOW,
	ZONE_C_MED,
	ZONE_C_HIGH,
	ZONE_I_LOW,
	ZONE_I_MED,
	ZONE_I_HIGH,
	DEZONE,
	POWER_COAL,
	POWER_WIND,
	POWER_NUCLEAR,
	WATER_PUMP,
	WATER_TOWER,
	POLICE,
	FIRE_STATION,
	SCHOOL,
	HOSPITAL,
	PARK,
}

enum Overlay {
	NONE,
	ZONES,
	POWER,
	WATER,
	LAND_VALUE,
	POLLUTION,
	CRIME,
	TRAFFIC,
	FIRE_RISK,
	POLICE,
	FIRE,
	EDUCATION,
	HEALTH,
}

const OVERLAY_NAMES := {
	Overlay.NONE: "No overlay",
	Overlay.ZONES: "Zones",
	Overlay.POWER: "Power",
	Overlay.WATER: "Water",
	Overlay.LAND_VALUE: "Land value",
	Overlay.POLLUTION: "Pollution",
	Overlay.CRIME: "Crime",
	Overlay.TRAFFIC: "Traffic",
	Overlay.FIRE_RISK: "Fire risk",
	Overlay.POLICE: "Police coverage",
	Overlay.FIRE: "Fire coverage",
	Overlay.EDUCATION: "Education coverage",
	Overlay.HEALTH: "Health coverage",
}

## Residents per developed residential tile, per level, indexed by density (1..3).
const RES_POP_PER_LEVEL := [0, 8, 30, 100]
## Jobs per developed commercial tile, per level, indexed by density.
const COM_JOBS_PER_LEVEL := [0, 6, 25, 80]
## Jobs per developed industrial tile, per level, indexed by density.
const IND_JOBS_PER_LEVEL := [0, 10, 30, 60]

## Power (MW-ish units) used per developed zone tile, per level, indexed by density.
const ZONE_POWER_USE := [0, 1, 3, 8]
## Water units used per developed zone tile, per level, indexed by density.
const ZONE_WATER_USE := [0, 1, 3, 8]

const ZONE_COLORS := {
	Zone.RES: Color(0.30, 0.75, 0.30),
	Zone.COM: Color(0.30, 0.50, 0.95),
	Zone.IND: Color(0.90, 0.75, 0.20),
}

const ZONE_NAMES := {
	Zone.NONE: "Unzoned",
	Zone.RES: "Residential",
	Zone.COM: "Commercial",
	Zone.IND: "Industrial",
}

const DENSITY_NAMES := ["", "Low", "Medium", "High"]
const WEALTH_NAMES := ["", "Low wealth", "Middle wealth", "High wealth"]
const MONTH_NAMES := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
