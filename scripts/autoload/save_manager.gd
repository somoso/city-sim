extends Node
## Saves and loads cities as JSON files under user://saves/. Autoloaded as `SaveManager`.

const SAVE_DIR := "user://saves"


func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _path_for(save_name: String) -> String:
	var safe := save_name.strip_edges().validate_filename()
	if safe == "":
		safe = "city"
	return "%s/%s.json" % [SAVE_DIR, safe]


func save_city(save_name: String) -> bool:
	if not GameState.has_city():
		return false
	_ensure_dir()
	var data := GameState.to_dict()
	data["saved_at"] = Time.get_datetime_string_from_system()
	var file := FileAccess.open(_path_for(save_name), FileAccess.WRITE)
	if file == null:
		push_error("Could not open save file for writing: %s" % _path_for(save_name))
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true


func load_city(save_name: String) -> bool:
	var path := _path_for(save_name)
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Save file is not valid JSON: %s" % path)
		return false
	return GameState.from_dict(parsed)


## Returns save names (without extension), newest first.
func list_saves() -> Array[String]:
	_ensure_dir()
	var out: Array[String] = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return out
	var entries: Array = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".json"):
			var full := "%s/%s" % [SAVE_DIR, fname]
			entries.append([FileAccess.get_modified_time(full), fname.get_basename()])
		fname = dir.get_next()
	dir.list_dir_end()
	entries.sort_custom(func(a, b): return a[0] > b[0])
	for e in entries:
		out.append(e[1])
	return out


func delete_save(save_name: String) -> void:
	var path := _path_for(save_name)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
