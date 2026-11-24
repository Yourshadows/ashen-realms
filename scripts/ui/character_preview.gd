extends Control

func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	var center_x := size.x * 0.5
	var base_y := size.y - 8.0
	var shadow := Color(0.02, 0.025, 0.03, 0.7)
	var cape := Color(0.16, 0.17, 0.18, 1.0)
	var armor := Color(0.34, 0.36, 0.36, 1.0)
	var armor_light := Color(0.52, 0.48, 0.38, 1.0)
	var leather := Color(0.22, 0.14, 0.1, 1.0)
	var ember := Color(0.83, 0.38, 0.13, 1.0)

	draw_colored_polygon(PackedVector2Array([
		Vector2(center_x - 33.0, base_y), Vector2(center_x + 33.0, base_y),
		Vector2(center_x + 24.0, base_y + 5.0), Vector2(center_x - 24.0, base_y + 5.0)
	]), shadow)

	draw_colored_polygon(PackedVector2Array([
		Vector2(center_x - 16.0, base_y - 84.0), Vector2(center_x + 16.0, base_y - 84.0),
		Vector2(center_x + 29.0, base_y - 20.0), Vector2(center_x + 16.0, base_y - 9.0),
		Vector2(center_x - 17.0, base_y - 9.0), Vector2(center_x - 29.0, base_y - 20.0)
	]), cape)

	draw_colored_polygon(PackedVector2Array([
		Vector2(center_x - 17.0, base_y - 20.0), Vector2(center_x - 12.0, base_y - 48.0),
		Vector2(center_x + 12.0, base_y - 48.0), Vector2(center_x + 17.0, base_y - 20.0),
		Vector2(center_x + 12.0, base_y - 9.0), Vector2(center_x - 12.0, base_y - 9.0)
	]), armor)

	draw_colored_polygon(PackedVector2Array([
		Vector2(center_x - 27.0, base_y - 48.0), Vector2(center_x - 10.0, base_y - 56.0),
		Vector2(center_x, base_y - 49.0), Vector2(center_x + 10.0, base_y - 56.0),
		Vector2(center_x + 27.0, base_y - 48.0), Vector2(center_x + 21.0, base_y - 37.0),
		Vector2(center_x + 11.0, base_y - 40.0), Vector2(center_x, base_y - 34.0),
		Vector2(center_x - 11.0, base_y - 40.0), Vector2(center_x - 21.0, base_y - 37.0)
	]), armor_light)

	draw_colored_polygon(PackedVector2Array([
		Vector2(center_x - 13.0, base_y - 10.0), Vector2(center_x - 1.0, base_y - 10.0),
		Vector2(center_x - 4.0, base_y + 1.0), Vector2(center_x - 17.0, base_y + 1.0)
	]), leather)
	draw_colored_polygon(PackedVector2Array([
		Vector2(center_x + 1.0, base_y - 10.0), Vector2(center_x + 13.0, base_y - 10.0),
		Vector2(center_x + 17.0, base_y + 1.0), Vector2(center_x + 4.0, base_y + 1.0)
	]), leather)

	draw_circle(Vector2(center_x, base_y - 68.0), 13.0, Color(0.68, 0.48, 0.34, 1.0))
	draw_colored_polygon(PackedVector2Array([
		Vector2(center_x - 14.0, base_y - 69.0), Vector2(center_x - 8.0, base_y - 84.0),
		Vector2(center_x + 9.0, base_y - 83.0), Vector2(center_x + 15.0, base_y - 68.0),
		Vector2(center_x + 7.0, base_y - 73.0), Vector2(center_x - 8.0, base_y - 73.0)
	]), armor_light)
	draw_circle(Vector2(center_x, base_y - 37.0), 4.0, ember)

	draw_line(Vector2(center_x + 25.0, base_y - 40.0), Vector2(center_x + 42.0, base_y - 87.0), Color(0.72, 0.74, 0.74, 1.0), 3.0, true)
	draw_line(Vector2(center_x + 19.0, base_y - 50.0), Vector2(center_x + 31.0, base_y - 45.0), armor_light, 3.0, true)
