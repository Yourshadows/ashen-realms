extends Control

const MAIN_MENU_PATH := "res://scenes/ui/MainMenu.tscn"
const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"

@onready var slots_panel: VBoxContainer = $CenterContainer/Panel/Content/SlotsPanel
@onready var class_panel: VBoxContainer = $CenterContainer/Panel/Content/ClassPanel
@onready var knight_button: Button = $CenterContainer/Panel/Content/ClassPanel/KnightButton
@onready var confirm_button: Button = $CenterContainer/Panel/Content/ClassPanel/Actions/ConfirmButton
@onready var back_to_slots_button: Button = $CenterContainer/Panel/Content/ClassPanel/Actions/BackToSlotsButton
@onready var class_description: Label = $CenterContainer/Panel/Content/ClassPanel/ClassDescription

var _selected_slot := -1
var _selected_class := ""
var _slot_to_delete := -1

func _ready() -> void:
	for slot_index in 3:
		var row := slots_panel.get_node("SlotRow%d" % (slot_index + 1))
		var slot_button: Button = row.get_node("Slot%dButton" % (slot_index + 1))
		var delete_button: Button = row.get_node("DeleteSlot%dButton" % (slot_index + 1))
		slot_button.pressed.connect(_on_slot_pressed.bind(slot_index))
		delete_button.pressed.connect(_on_delete_pressed.bind(slot_index))
	knight_button.pressed.connect(_on_knight_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	back_to_slots_button.pressed.connect(_back_to_slots)
	$CenterContainer/Panel/Content/BackButton.pressed.connect(_back_to_main_menu)
	$DeleteConfirmation.confirmed.connect(_on_delete_confirmed)
	_refresh_slots()

func _on_slot_pressed(slot_index: int) -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session != null and bool(game_session.call("has_save", slot_index)):
		if game_session.call("load_save", slot_index):
			get_tree().change_scene_to_file(MAIN_SCENE_PATH)
		return
	_selected_slot = slot_index
	_selected_class = ""
	slots_panel.visible = false
	class_panel.visible = true
	knight_button.button_pressed = false
	confirm_button.disabled = true
	class_description.text = "Рыцарь — стойкий боец ближнего боя.\n125 здоровья • 13 урона атаки • 25 урона навыка"

func _on_knight_pressed() -> void:
	_selected_class = "knight"
	knight_button.button_pressed = true
	confirm_button.disabled = false

func _on_confirm_pressed() -> void:
	if _selected_slot < 0 or _selected_class.is_empty():
		return
	var game_session := get_node_or_null("/root/GameSession")
	if game_session != null:
		game_session.call("begin_new_game", _selected_slot, _selected_class)
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)

func _back_to_slots() -> void:
	class_panel.visible = false
	slots_panel.visible = true
	_selected_slot = -1
	_selected_class = ""

func _back_to_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)

func _on_delete_pressed(slot_index: int) -> void:
	_slot_to_delete = slot_index
	$DeleteConfirmation.dialog_text = "Удалить сохранение из слота %d без возможности восстановления?" % (slot_index + 1)
	$DeleteConfirmation.popup_centered()

func _on_delete_confirmed() -> void:
	if _slot_to_delete < 0:
		return
	var game_session := get_node_or_null("/root/GameSession")
	if game_session != null and not bool(game_session.call("delete_save", _slot_to_delete)):
		push_error("Не удалось удалить сохранение слота %d" % (_slot_to_delete + 1))
	_slot_to_delete = -1
	_refresh_slots()

func _refresh_slots() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null:
		return
	for slot_index in 3:
		var row := slots_panel.get_node("SlotRow%d" % (slot_index + 1))
		var slot_button: Button = row.get_node("Slot%dButton" % (slot_index + 1))
		var delete_button: Button = row.get_node("DeleteSlot%dButton" % (slot_index + 1))
		slot_button.text = String(game_session.call("get_save_summary", slot_index))
		delete_button.disabled = not bool(game_session.call("has_save", slot_index))
