extends Node
## Tunable numbers for the whole game, loaded from JSON with the values in code as the
## fallback. Autoloaded as `Balance`.
##
## Two files are read if they exist, later ones overriding earlier ones:
##   res://data/balance.json   shipped with the game, and the readable record of every knob
##   user://balance.json       the player's own overrides
##
## Both are watched while the game runs, so editing either one takes effect within a second
## without restarting. A file that is missing, unreadable, not an object, or malformed is
## ignored with a warning and the previous good values stay in force, so a typo can never
## leave the game unplayable.

const PROJECT_FILE := "res://data/balance.json"
const USER_FILE := "user://balance.json"
## How often the files are checked for edits, in seconds.
const POLL_SECONDS := 1.0

## Merged values, deepest key wins. Empty means "use the fallback passed by the caller".
var _values := {}
var _mtimes := {}
var _poll := 0.0
var _last_error := ""

## Set false in tests that need the shipped numbers regardless of a stray user file.
var watch_enabled := true


func _ready() -> void:
	reload()


func _process(delta: float) -> void:
	if not watch_enabled:
		return
	_poll += delta
	if _poll < POLL_SECONDS:
		return
	_poll = 0.0
	if _files_changed():
		reload()


func _files_changed() -> bool:
	for path in [PROJECT_FILE, USER_FILE]:
		var stamp := _stamp(path)
		if _mtimes.get(path, -1) != stamp:
			return true
	return false


func _stamp(path: String) -> int:
	if not FileAccess.file_exists(path):
		return -1
	return FileAccess.get_modified_time(path)


## Re-reads every file. Returns true if the values in force changed.
func reload() -> bool:
	var merged := {}
	var errors: Array[String] = []
	for path in [PROJECT_FILE, USER_FILE]:
		_mtimes[path] = _stamp(path)
		if not FileAccess.file_exists(path):
			continue
		var parsed = _read(path)
		if parsed == null:
			errors.append(path.get_file())
			continue
		_merge(merged, parsed)
	if not errors.is_empty():
		var message := "Ignoring invalid balance file(s): %s. Using the last good values." % ", ".join(errors)
		if message != _last_error:
			_last_error = message
			push_warning(message)
			if GameState.has_city():
				GameState.post_message(message)
		# Leave the values exactly as they were. A half-typed file must not change the
		# game, and must not silently drop overrides that were valid a moment ago.
		return false
	_last_error = ""
	var changed := merged != _values
	_values = merged
	if changed:
		Events.balance_reloaded.emit()
	return changed


func _read(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return parsed


## Recursively copies `src` over `dst`, so an override file can set a single leaf.
func _merge(dst: Dictionary, src: Dictionary) -> void:
	for k in src.keys():
		var v = src[k]
		if typeof(v) == TYPE_DICTIONARY and typeof(dst.get(k)) == TYPE_DICTIONARY:
			_merge(dst[k], v)
		else:
			dst[k] = v


## Looks up a dotted path such as "buildings.landfill.cost". Returns null when absent.
func _lookup(path: String):
	var node = _values
	for part in path.split("."):
		if typeof(node) != TYPE_DICTIONARY or not node.has(part):
			return null
		node = node[part]
	return node


## A number from the files, or `fallback` when it is missing or not a number.
func num(path: String, fallback: float) -> float:
	var v = _lookup(path)
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return float(v)
	return fallback


func int_val(path: String, fallback: int) -> int:
	return int(round(num(path, float(fallback))))


func flag(path: String, fallback: bool) -> bool:
	var v = _lookup(path)
	if typeof(v) == TYPE_BOOL:
		return v
	return fallback


## An array of numbers, or `fallback` when it is missing, not an array, or the wrong length.
func nums(path: String, fallback: Array) -> Array:
	var v = _lookup(path)
	if typeof(v) != TYPE_ARRAY or v.size() != fallback.size():
		return fallback
	var out: Array = []
	for item in v:
		if typeof(item) != TYPE_FLOAT and typeof(item) != TYPE_INT:
			return fallback
		out.append(float(item))
	return out


## Convenience for a building field: buildings.<key>.<field>.
func building(key: String, field: String, fallback):
	if key == "":
		return fallback
	var v = _lookup("buildings.%s.%s" % [key, field])
	if v == null:
		return fallback
	if typeof(fallback) == TYPE_FLOAT or typeof(fallback) == TYPE_INT:
		if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
			return fallback
		return v
	return v


## Writes the shipped defaults to user://balance.json so the player has something to edit.
func export_user_file() -> bool:
	if not FileAccess.file_exists(PROJECT_FILE):
		return false
	var parsed = _read(PROJECT_FILE)
	if parsed == null:
		return false
	var out := FileAccess.open(USER_FILE, FileAccess.WRITE)
	if out == null:
		return false
	out.store_string(JSON.stringify(parsed, "\t"))
	out.close()
	_mtimes[USER_FILE] = _stamp(USER_FILE)
	return true


func last_error() -> String:
	return _last_error
