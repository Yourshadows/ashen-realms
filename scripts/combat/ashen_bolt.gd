extends Node2D

@export var speed: float = 320.0

var target: Node2D
var damage: int = 0

func launch(target_node: Node2D, damage_amount: int) -> void:
	target = target_node
	damage = damage_amount

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return

	var offset := target.global_position - global_position
	var travel_distance := speed * delta
	if offset.length() <= travel_distance:
		if target.has_method("take_damage") and target.has_method("is_alive") and bool(target.call("is_alive")):
			target.call("take_damage", damage)
		queue_free()
		return

	var direction := offset.normalized()
	global_position += direction * travel_distance
	rotation = direction.angle()