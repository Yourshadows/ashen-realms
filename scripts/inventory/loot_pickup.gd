extends Area2D

@export var silver_value: int = 10

var _collected := false

func _ready() -> void:
	add_to_group("loot")

func collect(player: Node) -> void:
	if _collected or not is_instance_valid(player):
		return
	if not player.has_method("add_silver"):
		return
	_collected = true
	player.call("add_silver", silver_value)
	queue_free()