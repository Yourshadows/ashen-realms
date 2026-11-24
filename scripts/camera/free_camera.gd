extends Camera2D

@export var pan_speed: float = 240.0
@export var edge_scroll_margin: float = 20.0
@export var zoom_step: float = 1.1
@export var minimum_zoom: float = 1.0
@export var maximum_zoom: float = 1.8
@export var map_bounds: Rect2 = Rect2(-400.0, -225.0, 800.0, 450.0)

func _ready() -> void:
	_clamp_to_map()

func _unhandled_input(event: InputEvent) -> void:
	if _inventory_is_open():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(zoom.x * zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(zoom.x / zoom_step)

func _process(delta: float) -> void:
	if _inventory_is_open():
		_clamp_to_map()
		return

	var mouse_position := get_viewport().get_mouse_position()
	var viewport_size := get_viewport_rect().size
	var pan_direction := Vector2.ZERO
	if mouse_position.x <= edge_scroll_margin:
		pan_direction.x -= 1.0
	elif mouse_position.x >= viewport_size.x - edge_scroll_margin:
		pan_direction.x += 1.0
	if mouse_position.y <= edge_scroll_margin:
		pan_direction.y -= 1.0
	elif mouse_position.y >= viewport_size.y - edge_scroll_margin:
		pan_direction.y += 1.0

	if pan_direction != Vector2.ZERO:
		global_position += pan_direction.normalized() * pan_speed * delta / zoom.x
	_clamp_to_map()

func _inventory_is_open() -> bool:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return false
	var inventory_panel := current_scene.get_node_or_null("HUD/InventoryPanel")
	return inventory_panel != null and inventory_panel.visible

func _set_zoom(value: float) -> void:
	var clamped_zoom := clampf(value, minimum_zoom, maximum_zoom)
	zoom = Vector2.ONE * clamped_zoom
	_clamp_to_map()

func clamp_to_map() -> void:
	_clamp_to_map()

func _clamp_to_map() -> void:
	var half_view_size := get_viewport_rect().size / zoom * 0.5
	var map_right := map_bounds.position.x + map_bounds.size.x
	var map_bottom := map_bounds.position.y + map_bounds.size.y

	if half_view_size.x * 2.0 >= map_bounds.size.x:
		global_position.x = map_bounds.position.x + map_bounds.size.x * 0.5
	else:
		global_position.x = clampf(global_position.x, map_bounds.position.x + half_view_size.x, map_right - half_view_size.x)

	if half_view_size.y * 2.0 >= map_bounds.size.y:
		global_position.y = map_bounds.position.y + map_bounds.size.y * 0.5
	else:
		global_position.y = clampf(global_position.y, map_bounds.position.y + half_view_size.y, map_bottom - half_view_size.y)
