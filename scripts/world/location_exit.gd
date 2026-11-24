extends Area2D

@export_file("*.tscn") var target_location_path: String
@export var arrival_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("players"):
		return
	var world := get_tree().current_scene
	if world != null and world.has_method("change_location"):
		world.call("change_location", target_location_path, arrival_position)
