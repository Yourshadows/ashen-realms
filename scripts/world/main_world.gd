extends Node2D

@onready var location_container: Node2D = $LocationContainer
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Camera2D

var _is_transitioning := false
var _is_restoring := false
var _autosave_timer := 0.0
var _current_location_path := "res://scenes/world/TestMap.tscn"
var _locations: Dictionary = {}

func _ready() -> void:
	_locations[_current_location_path] = $LocationContainer/TestMap
	call_deferred("_restore_saved_world")

func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= 15.0:
		_autosave_timer = 0.0
		_save_progress()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_progress()

func change_location(scene_path: String, arrival_position: Vector2) -> void:
	if _is_transitioning:
		return
	var next_location: Node2D
	if _locations.has(scene_path):
		next_location = _locations[scene_path] as Node2D
	else:
		var packed_scene := load(scene_path) as PackedScene
		if packed_scene == null:
			push_error("Could not load location: %s" % scene_path)
			return
		next_location = packed_scene.instantiate() as Node2D
	_remove_defeated_enemies(scene_path, next_location)

	_is_transitioning = true
	await get_tree().process_frame
	player.call("prepare_for_location_change", arrival_position)
	var old_location := location_container.get_child(0) as Node2D
	location_container.remove_child(old_location)
	_locations[_current_location_path] = old_location
	await get_tree().process_frame

	player.global_position = arrival_position
	location_container.add_child(next_location)
	_current_location_path = scene_path
	await get_tree().process_frame
	camera.global_position = player.global_position
	camera.call("clamp_to_map")
	_is_transitioning = false
	_save_progress()

func _restore_saved_world() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null:
		return
	var data: Dictionary = game_session.call("get_pending_save")
	if data.is_empty():
		return
	_is_restoring = true
	_remove_defeated_enemies(_current_location_path, location_container.get_child(0) as Node2D)
	var saved_location := String(data.get("location", _current_location_path))
	if saved_location != _current_location_path:
		await change_location(saved_location, Vector2.ZERO)
	var saved_position := Vector2(float(data.get("player_x", player.global_position.x)), float(data.get("player_y", player.global_position.y)))
	player.call("prepare_for_location_change", saved_position)
	player.global_position = saved_position
	camera.global_position = player.global_position
	camera.call("clamp_to_map")
	_is_restoring = false
	game_session.call("clear_pending_save")

func _save_progress() -> void:
	if _is_restoring:
		return
	var game_session := get_node_or_null("/root/GameSession")
	if game_session != null and player != null:
		game_session.call("save_current_game", player, self)

func _remove_defeated_enemies(location_path: String, location: Node) -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null or location == null:
		return
	for child in location.get_children():
		if child.has_method("is_alive") and bool(game_session.call("is_enemy_defeated", location_path, String(child.name))):
			child.free()
