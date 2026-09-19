class_name Constants
extends RefCounted
## Shared enums and tuning constants used across the simulation, renderer and UI.

const TILE_W := 128
const TILE_H := 64
const CHUNK_SIZE := 16

## Zoned lots up to this many tiles from a road (through lots of the same zone type) count
## as road-connected.
const ACCESS_DEPTH := 2
## Low-density industrial is farmland, which needs room, so it reaches further.
const AGRICULTURE_ACCESS_DEPTH := 4
## Deepest any zone reaches, used to bound the road-access search.
const MAX_ACCESS_DEPTH := 4

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

## Largest block of lots a zone may form before a road has to break it up, as
## Vector2i(short side, long side) in tiles. A zero long side means no limit.
const ZONE_BLOCK := {
	Zone.RES: Vector2i(4, 0),
	Zone.COM: Vector2i(2, 5),
	Zone.IND: Vector2i(4, 0),
}
## Farmland gets its own, roomier block.
const AGRICULTURE_BLOCK := Vector2i(8, 0)


## How far this lot may sit from a road and still count as served.
static func access_depth(zone: int, density: int) -> int:
	if zone == Zone.IND and density == 1:
		return AGRICULTURE_ACCESS_DEPTH
	return ACCESS_DEPTH


## Largest block this zone may form, as Vector2i(short side, long side); 0 = unlimited.
static func block_limits(zone: int, density: int) -> Vector2i:
	if zone == Zone.IND and density == 1:
		return AGRICULTURE_BLOCK
	return ZONE_BLOCK.get(zone, Vector2i(4, 0))


## Display name for a zone, which is "Agricultural" for low-density industrial.
static func zone_label(zone: int, density: int) -> String:
	if zone == Zone.IND and density == 1:
		return "Agricultural"
	return ZONE_NAMES.get(zone, "Unzoned")


const DENSITY_NAMES := ["", "Low", "Medium", "High"]
const WEALTH_NAMES := ["", "Low wealth", "Middle wealth", "High wealth"]
const MONTH_NAMES := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
