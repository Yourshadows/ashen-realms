extends Area2D

@export var item_id: String = "rusty_sword"

var _collected := false

func _ready() -> void:
	add_to_group("items")

func collect(player: Node) -> void:
	if _collected or not is_instance_valid(player) or not player.has_method("add_item"):
		return
	_collected = true
	player.call("add_item", item_id)
	queue_free()