class_name GameMenu
extends PanelContainer
## In-game menu: save/load, disaster settings and returning to the main menu.

var save_name: LineEdit
var save_list: ItemList
var status: Label
var disasters_check: CheckBox
var _speed_before := 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	custom_minimum_size = Vector2(380, 0)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)

	var title := Label.new()
	title.text = "Menu"
	title.add_theme_font_size_override("font_size", 18)
	col.add_child(title)

	var save_row := HBoxContainer.new()
	col.add_child(save_row)
	save_name = LineEdit.new()
	save_name.placeholder_text = "Save name"
	save_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(save_name)
	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_on_save)
	save_row.add_child(save_btn)

	save_list = ItemList.new()
	save_list.custom_minimum_size = Vector2(0, 110)
	save_list.item_selected.connect(func(idx: int) -> void: save_name.text = save_list.get_item_text(idx))
	col.add_child(save_list)
	var load_row := HBoxContainer.new()
	col.add_child(load_row)
	var load_btn := Button.new()
	load_btn.text = "Load selected"
	load_btn.pressed.connect(_on_load)
	load_row.add_child(load_btn)
	var del_btn := Button.new()
	del_btn.text = "Delete selected"
	del_btn.pressed.connect(_on_delete)
	load_row.add_child(del_btn)
	status = Label.new()
	status.modulate = Color(1, 1, 1, 0.8)
	col.add_child(status)

	col.add_child(HSeparator.new())
	disasters_check = CheckBox.new()
	disasters_check.text = "Random disasters"
	disasters_check.toggled.connect(func(on: bool) -> void: GameState.disasters_enabled = on)
	col.add_child(disasters_check)
	var dis_row := HBoxContainer.new()
	col.add_child(dis_row)
	var dis_label := Label.new()
	dis_label.text = "Trigger:"
	dis_row.add_child(dis_label)
	for entry in [["Fire", "fire"], ["Tornado", "tornado"], ["Meteor", "meteor"]]:
		var b := Button.new()
		b.text = entry[0]
		var kind: String = entry[1]
		b.pressed.connect(func() -> void: _trigger(kind))
		dis_row.add_child(b)

	col.add_child(HSeparator.new())
	var bottom := HBoxContainer.new()
	col.add_child(bottom)
	var resume := Button.new()
	resume.text = "Resume"
	resume.pressed.connect(hide_panel)
	bottom.add_child(resume)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	var main_menu := Button.new()
	main_menu.text = "Quit to main menu"
	main_menu.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	bottom.add_child(main_menu)


func toggle() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()


func show_panel() -> void:
	_speed_before = GameState.speed
	GameState.set_speed(0)
	save_name.text = GameState.city_name
	disasters_check.set_pressed_no_signal(GameState.disasters_enabled)
	status.text = ""
	_refresh_saves()
	visible = true


func hide_panel() -> void:
	if visible and GameState.speed == 0:
		GameState.set_speed(maxi(_speed_before, 1))
	visible = false


func _refresh_saves() -> void:
	save_list.clear()
	for s in SaveManager.list_saves():
		save_list.add_item(s)


func _on_save() -> void:
	var name := save_name.text.strip_edges()
	if name == "":
		name = GameState.city_name
	if SaveManager.save_city(name):
		status.text = "Saved as '%s'." % name
		GameState.post_message("City saved.")
	else:
		status.text = "Save failed."
	_refresh_saves()


func _selected_save() -> String:
	var sel := save_list.get_selected_items()
	if sel.is_empty():
		return ""
	return save_list.get_item_text(sel[0])


func _on_load() -> void:
	var name := _selected_save()
	if name == "":
		status.text = "Select a save first."
		return
	if SaveManager.load_city(name):
		status.text = "Loaded '%s'." % name
		visible = false
		GameState.set_speed(1)
		GameState.post_message("Welcome back to %s." % GameState.city_name)
	else:
		status.text = "Could not load '%s'." % name


func _on_delete() -> void:
	var name := _selected_save()
	if name == "":
		status.text = "Select a save first."
		return
	SaveManager.delete_save(name)
	status.text = "Deleted '%s'." % name
	_refresh_saves()


func _trigger(kind: String) -> void:
	var grid := GameState.grid
	var text := ""
	match kind:
		"fire": text = FireSim.trigger_fire(grid, GameState.rng)
		"tornado": text = FireSim.trigger_tornado(grid, GameState.rng)
		"meteor": text = FireSim.trigger_meteor(grid, GameState.rng)
	Simulation.refresh(grid, GameState)
	GameState.post_message(text)
	Events.world_changed.emit()
	hide_panel()
