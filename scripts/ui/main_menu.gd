extends Control

const SAVE_MENU_SCENE_PATH := "res://scenes/ui/SaveMenu.tscn"

@onready var play_button: Button = $CenterContainer/Menu/PlayButton

func _ready() -> void:
	play_button.pressed.connect(_on_play_button_pressed)
	play_button.grab_focus()

func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file(SAVE_MENU_SCENE_PATH)
