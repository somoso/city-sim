extends Control
## Title screen: start a new city, load a saved one, or quit.

var name_edit: LineEdit
var size_select: OptionButton
var seed_spin: SpinBox
var disasters_check: CheckBox
var save_list: ItemList
var status: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.10, 0.14)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size.x = 420
	margin.add_child(col)

	var title := Label.new()
	title.text = "City Sim"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Zone, build and balance the books in an isometric city."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(1, 1, 1, 0.7)
	col.add_child(subtitle)
	col.add_child(HSeparator.new())

	var form := GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation", 12)
	form.add_theme_constant_override("v_separation", 8)
	col.add_child(form)

	form.add_child(_lbl("City name"))
	name_edit = LineEdit.new()
	name_edit.text = "New City"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(name_edit)

	form.add_child(_lbl("Map size"))
	size_select = OptionButton.new()
	size_select.add_item("Small (64 x 64)", 64)
	size_select.add_item("Medium (96 x 96)", 96)
	size_select.add_item("Large (128 x 128)", 128)
	size_select.select(0)
	form.add_child(size_select)

	form.add_child(_lbl("Seed"))
	var seed_row := HBoxContainer.new()
	form.add_child(seed_row)
	seed_spin = SpinBox.new()
	seed_spin.min_value = 0
	seed_spin.max_value = 999999
	seed_spin.value = randi() % 1000000
	seed_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(seed_spin)
	var rnd := Button.new()
	rnd.text = "Random"
	rnd.pressed.connect(func() -> void: seed_spin.value = randi() % 1000000)
	seed_row.add_child(rnd)

	form.add_child(_lbl("Disasters"))
	disasters_check = CheckBox.new()
	disasters_check.text = "Random disasters (off by default)"
	disasters_check.button_pressed = false
	form.add_child(disasters_check)

	var start := Button.new()
	start.text = "Start new city"
	start.add_theme_font_size_override("font_size", 18)
	start.pressed.connect(_on_start)
	col.add_child(start)

	col.add_child(HSeparator.new())
	col.add_child(_lbl("Saved cities"))
	save_list = ItemList.new()
	save_list.custom_minimum_size = Vector2(0, 100)
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
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_row.add_child(spacer)
	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func() -> void: get_tree().quit())
	load_row.add_child(quit)
	status = Label.new()
	status.modulate = Color(1, 1, 1, 0.75)
	col.add_child(status)

	_refresh_saves()


func _lbl(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _refresh_saves() -> void:
	save_list.clear()
	for s in SaveManager.list_saves():
		save_list.add_item(s)


func _on_start() -> void:
	var size := size_select.get_item_id(size_select.selected)
	GameState.new_city(size, size, int(seed_spin.value), name_edit.text, disasters_check.button_pressed)
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _selected_save() -> String:
	var sel := save_list.get_selected_items()
	if sel.is_empty():
		return ""
	return save_list.get_item_text(sel[0])


func _on_load() -> void:
	var name := _selected_save()
	if name == "":
		status.text = "Select a saved city first."
		return
	if SaveManager.load_city(name):
		get_tree().change_scene_to_file("res://scenes/game.tscn")
	else:
		status.text = "Could not load '%s'." % name


func _on_delete() -> void:
	var name := _selected_save()
	if name == "":
		status.text = "Select a saved city first."
		return
	SaveManager.delete_save(name)
	status.text = "Deleted '%s'." % name
	_refresh_saves()
