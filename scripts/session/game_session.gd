extends Node

const SAVE_DIRECTORY := "user://saves"

var selected_slot: int = -1
var selected_class: String = "knight"
var _pending_save: Dictionary = {}
var defeated_enemy_ids: Array[String] = []

func begin_new_game(slot_index: int, class_id: String) -> void:
	selected_slot = slot_index
	selected_class = class_id
	_pending_save.clear()
	defeated_enemy_ids.clear()

func has_save(slot_index: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot_index))

func read_save(slot_index: int) -> Dictionary:
	var path := _slot_path(slot_index)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

func get_save_summary(slot_index: int) -> String:
	var data := read_save(slot_index)
	if data.is_empty():
		return "Слот %d  —  Новый персонаж" % (slot_index + 1)
	var location_name := "Пепельные поля"
	if String(data.get("location", "")).contains("ForestRuins"):
		location_name = "Лесные руины"
	return "Слот %d  —  Уровень %d • %s" % [slot_index + 1, int(data.get("level", 1)), location_name]

func load_save(slot_index: int) -> bool:
	var data := read_save(slot_index)
	if data.is_empty():
		return false
	selected_slot = slot_index
	selected_class = String(data.get("class_id", "knight"))
	_pending_save = data
	defeated_enemy_ids.clear()
	for enemy_id in data.get("defeated_enemy_ids", []):
		defeated_enemy_ids.append(String(enemy_id))
	return true

func get_pending_save() -> Dictionary:
	return _pending_save

func clear_pending_save() -> void:
	_pending_save.clear()

func register_enemy_defeat(location_path: String, enemy_name: String) -> void:
	var enemy_id := "%s::%s" % [location_path, enemy_name]
	if not defeated_enemy_ids.has(enemy_id):
		defeated_enemy_ids.append(enemy_id)

func is_enemy_defeated(location_path: String, enemy_name: String) -> bool:
	return defeated_enemy_ids.has("%s::%s" % [location_path, enemy_name])

func save_current_game(player: Node2D, world: Node) -> void:
	if selected_slot < 0 or not is_instance_valid(player) or not is_instance_valid(world):
		return
	var position: Vector2 = player.global_position
	var data := {
		"class_id": String(player.get("class_id")),
		"level": int(player.get("level")),
		"experience": int(player.get("experience")),
		"experience_to_next_level": int(player.get("experience_to_next_level")),
		"stat_points": int(player.get("stat_points")),
		"silver": int(player.get("silver")),
		"inventory": player.get("inventory"),
		"rusty_sword_equipped": bool(player.get("rusty_sword_equipped")),
		"health_potions": int(player.get("health_potions")),
		"health": int(player.get("health")),
		"max_health": int(player.get("max_health")),
		"attack_damage": int(player.get("attack_damage")),
		"attack_speed": float(player.get("attack_speed")),
		"skill_damage": int(player.get("skill_damage")),
		"move_speed": float(player.get("move_speed")),
		"location": String(world.get("_current_location_path")),
		"defeated_enemy_ids": defeated_enemy_ids,
		"player_x": position.x,
		"player_y": position.y,
		"saved_at": Time.get_datetime_string_from_system()
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIRECTORY))
	var file := FileAccess.open(_slot_path(selected_slot), FileAccess.WRITE)
	if file == null:
		push_error("Could not open save slot for writing: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data))

func delete_save(slot_index: int) -> bool:
	var path := _slot_path(slot_index)
	if not FileAccess.file_exists(path):
		return true
	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return error == OK

func _slot_path(slot_index: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIRECTORY, slot_index + 1]
