extends Node
## Global signal bus. Autoloaded as `Events`.

## A new city was created or loaded; everything should rebuild.
signal city_started
## Specific tiles changed (edits). Renderers redraw the affected chunks.
signal tiles_changed(indices: PackedInt32Array)
## Everything may have changed (monthly tick, disasters, load).
signal world_changed
## A simulated month elapsed.
signal month_ticked
signal funds_changed(funds: int)
signal speed_changed(speed: int)
signal tool_changed(tool: int)
signal overlay_changed(overlay: int)
signal tile_selected(index: int)
## Totals of lots/buildings missing each service: { "road": int, "power": int, "water": int }.
signal alerts_changed(counts: Dictionary)
## The tunable numbers in data/balance.json were edited and reloaded.
signal balance_reloaded
signal message(text: String)
