# City Sim

An isometric city-building simulation game built with **Godot 4.5** and GDScript, in the
spirit of SimCity 4. Lay roads, zone land for residents, shops and factories, keep the
lights on and the taps running, fund police, fire, schools and hospitals, and try to keep
the treasury in the black while the city grows.

All graphics are drawn procedurally at runtime: there are no external art assets, so the
project opens and runs from a plain checkout.

![A grown city with residential, commercial and industrial districts](docs/screenshots/city.png)

![Budget panel, tile info and a zoning drag preview](docs/screenshots/ui.png)

## Running the game

1. Install [Godot 4.5](https://godotengine.org/download) (the standard build; .NET is not needed).
2. Open the Godot project manager, choose **Import**, and select `project.godot` in this folder.
3. Press **F5** (Run Project). The main menu lets you name your city, pick a map size and
   seed, and decide whether random disasters are enabled (off by default).

From the command line:

```sh
godot --path /path/to/city-sim
```

## How to play

| Action | Control |
| --- | --- |
| Pan the camera | `W A S D` / arrow keys, or drag with middle or right mouse button |
| Zoom | Mouse wheel |
| Place zones / bulldoze | Pick a tool, then left-click-drag a rectangle |
| Lay roads | Pick Road, then left-click-drag (an L-shaped path is previewed) |
| Place a building | Pick it from Utilities or Civic, then left-click |
| Inspect a tile | Query tool (or no tool) and left-click |
| Cancel tool / close panel | Right-click or `Esc` |
| Pause / speed | `Space`, `1`, `2`, `3`, or the buttons in the top bar |
| Shortcuts | `R` road, `B` bulldoze, `Q` query |

### Getting a city started

1. Lay a few roads. Zones only develop on lots that touch a road.
2. Build a power source (a wind turbine is cheap) and a water tower or a water pump next to
   water. Power and water travel through roads and any built tile, so keep things connected.
3. Zone residential, commercial and industrial land next to the roads. Watch the RCI gauge in
   the top bar: bars above the line mean demand, bars below mean oversupply.
4. Open **Budget** to set tax rates and department funding. Nine percent is the neutral
   tax rate; higher rates cut demand.
5. Add parks, schools, police and fire stations as the city grows. Use the overlay dropdown
   (top right) to see power, water, land value, pollution, crime, traffic, fire risk and
   service coverage.

Small icons above a lot mean it is missing something: a red circle for no road access, a
yellow bolt for no power, a blue drop for no water.

## Simulation overview

Every simulated month the following systems run in order (see `scripts/sim/simulation.gd`):

- **Road network** – flood-fills road components, marks which lots have road access, and
  estimates job accessibility for residents. Traffic is spread along roads from nearby lots.
- **Utilities** – power and water propagate from plants through connected built tiles. If a
  network's demand exceeds supply, tiles furthest from the source lose service first.
- **Services** – police, fire, school, hospital and park coverage radiate from each building,
  scaled by its department funding. Unpowered services run at reduced strength.
- **Environment** – pollution (industry, coal, traffic, fires), crime (density, poverty,
  unemployment, minus police), land value (water, elevation, parks, services, minus
  pollution/crime/industry) and fire risk.
- **Demand** – residential demand follows available jobs, commercial follows population,
  industrial has external demand so a new town can bootstrap. Taxes and brownouts reduce it.
- **Growth** – zoned lots with a road, power, water and positive demand develop and level up.
  Higher levels need better land value; wealth follows land value. Unserved lots decay.
- **Fire and disasters** – fires spread to flammable neighbours and burn out into rubble
  unless fire coverage extinguishes them. With random disasters enabled, tornadoes, meteors
  and major fires may strike; all three can also be triggered from the in-game menu.
- **Budget** – tax income from developed lots minus building upkeep and department funding.

## Project layout

```
project.godot            Godot project (autoloads, display settings)
scenes/
  main_menu.tscn         Title screen
  game.tscn              Game scene: render layers, camera, HUD
scripts/
  autoload/              Events (signal bus), GameState (city data), SaveManager (JSON saves)
  core/                  Constants, BuildingDefs catalogue, CityGrid data model, TerrainGenerator
  sim/                   One file per simulation system plus the Simulation orchestrator
  game/                  GameController (input, clock) and BuildTools (applying tools)
  render/                IsoMath, chunked terrain/world/overlay layers, cursor, camera
  ui/                    HUD, RCI gauge, info panel, budget panel, in-game menu, main menu
tests/                   Headless smoke tests (see below)
```

Saves are written to `user://saves/<name>.json` (on Linux this is
`~/.local/share/godot/app_userdata/City Sim/saves/`).

## Tests

Two headless smoke tests exercise the simulation and the scene code without a display:

```sh
godot --headless --path . --import          # first run only: builds the class cache
godot --headless --path . tests/sim_smoke_test.tscn
godot --headless --path . tests/scene_smoke_test.tscn
```

Both exit with code 0 on success and print `ALL ... CHECKS PASSED`.

`tests/screenshot_capture.tscn` builds a demo town and saves screenshots; it needs a display
(or `xvfb-run`) because it renders for real:

```sh
xvfb-run -a godot --path . --resolution 1280x720 tests/screenshot_capture.tscn -- --out=/tmp/shots
```

## Ideas for what comes next

- Region view with multiple connected cities
- Bridges, highways, rail and mass transit
- Advisors, charts and a proper news ticker history
- Terrain tools (raise, lower, plant trees) and real building sprites
