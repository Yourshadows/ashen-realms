extends CharacterBody2D

const ASHEN_BOLT_SCENE: PackedScene = preload("res://scenes/player/AshenBolt.tscn")
signal silver_changed(total: int)
signal inventory_changed
signal health_changed(current: int, maximum: int)
signal progression_changed(level: int, current_xp: int, required_xp: int, unspent_points: int)

@export var move_speed: float = 150.0
@export var attack_range: float = 28.0
@export var attack_damage: int = 10
@export var attack_speed: float = 1.25
@export var selection_radius: float = 22.0
@export var pickup_range: float = 32.0
@export var max_health: int = 100
@export var downed_duration: float = 5.0
@export_range(0.0, 1.0) var respawn_health_ratio: float = 0.3
@export var skill_damage: int = 25
@export var skill_range: float = 180.0
@export var skill_cooldown: float = 3.0
@export var cleave_range: float = 90.0

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var visual: Polygon2D = $Visual
@onready var health_fill: Polygon2D = $HealthBar/Fill
@onready var skill_fill: Polygon2D = $SkillBar/Fill

var class_id: String = "knight"
var health: int
var level: int = 1
var experience: int = 0
var experience_to_next_level: int = 100
var stat_points: int = 0
var silver: int = 0
var inventory: Array[String] = []
var rusty_sword_equipped := false
var health_potions: int = 0
var _is_downed := false
var _downed_timer := 0.0
var _spawn_position := Vector2.ZERO
var _has_move_target := false
var _attack_target: Node2D
var _attack_timer := 0.0
var _hit_flash_timer := 0.0
var _skill_cooldown_remaining := 0.0

func _ready() -> void:
	_apply_starting_class()
	health = max_health
	var game_session := get_node_or_null("/root/GameSession")
	if game_session != null:
		var pending_save: Dictionary = game_session.call("get_pending_save")
		if not pending_save.is_empty():
			apply_saved_progress(pending_save)
	_spawn_position = global_position
	add_to_group("players")
	_refresh_health_bar()
	_refresh_skill_bar()

func apply_saved_progress(data: Dictionary) -> void:
	class_id = String(data.get("class_id", class_id))
	level = int(data.get("level", level))
	experience = int(data.get("experience", experience))
	experience_to_next_level = int(data.get("experience_to_next_level", experience_to_next_level))
	stat_points = int(data.get("stat_points", stat_points))
	silver = int(data.get("silver", silver))
	max_health = int(data.get("max_health", max_health))
	health = clampi(int(data.get("health", max_health)), 1, max_health)
	attack_damage = int(data.get("attack_damage", attack_damage))
	attack_speed = float(data.get("attack_speed", attack_speed))
	skill_damage = int(data.get("skill_damage", skill_damage))
	move_speed = float(data.get("move_speed", move_speed))
	health_potions = int(data.get("health_potions", health_potions))
	rusty_sword_equipped = bool(data.get("rusty_sword_equipped", rusty_sword_equipped))
	inventory.clear()
	for item_id in data.get("inventory", []):
		inventory.append(String(item_id))
	_refresh_health_bar()
	_refresh_skill_bar()

func _apply_starting_class() -> void:
	var game_session := get_node_or_null("/root/GameSession")
	if game_session != null:
		class_id = String(game_session.get("selected_class"))
	match class_id:
		"knight":
			max_health = 125
			attack_damage = 13
			skill_damage = 25
			move_speed = 140.0
		_:
			class_id = "knight"

func _unhandled_input(event: InputEvent) -> void:
	if _is_downed:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var skill_slot := -1
		match event.physical_keycode:
			KEY_W:
				skill_slot = 0
			KEY_E:
				skill_slot = 1
			KEY_R:
				skill_slot = 2
			KEY_1:
				skill_slot = 3
			KEY_2:
				skill_slot = 4
			KEY_3:
				skill_slot = 5
		if skill_slot >= 0:
			_activate_skill_slot(skill_slot)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Q:
		use_health_potion()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var click_position := get_global_mouse_position()
		var clicked_item := _find_item_at(click_position)
		if clicked_item != null:
			clicked_item.call("collect", self)
			return
		var clicked_loot := _find_loot_at(click_position)
		if clicked_loot != null:
			clicked_loot.call("collect", self)
			return
		var clicked_enemy := _find_enemy_at(click_position)
		if clicked_enemy != null:
			_set_attack_target(clicked_enemy)
		else:
			_clear_attack_target()
			navigation_agent.target_position = click_position
			_has_move_target = true

func _physics_process(delta: float) -> void:
	if _skill_cooldown_remaining > 0.0:
		_skill_cooldown_remaining = maxf(_skill_cooldown_remaining - delta, 0.0)
		_refresh_skill_bar()

	if not _is_downed and _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		if _hit_flash_timer <= 0.0:
			visual.color = Color(0.72, 0.49, 0.3, 1.0)

	if _is_downed:
		_downed_timer -= delta
		if _downed_timer <= 0.0:
			_respawn()
		velocity = Vector2.ZERO
		return

	if is_instance_valid(_attack_target):
		if not bool(_attack_target.call("is_alive")):
			_clear_attack_target()
		elif global_position.distance_to(_attack_target.global_position) <= attack_range:
			_has_move_target = false
			velocity = Vector2.ZERO
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_attack_target.call("take_damage", attack_damage + (5 if rusty_sword_equipped else 0))
				_attack_timer = 1.0 / maxf(attack_speed, 0.1)
			return
		else:
			navigation_agent.target_position = _attack_target.global_position
			_has_move_target = true

	if not _has_move_target:
		velocity = Vector2.ZERO
		return

	var next_path_position := navigation_agent.get_next_path_position()
	if navigation_agent.is_navigation_finished():
		_has_move_target = false
		velocity = Vector2.ZERO
		return

	var direction := global_position.direction_to(next_path_position)
	velocity = direction * move_speed
	move_and_slide()

func take_damage(amount: int) -> void:
	if _is_downed or health <= 0:
		return
	health = maxi(health - amount, 0)
	_refresh_health_bar()
	health_changed.emit(health, max_health)
	if health == 0:
		_clear_attack_target()
		_has_move_target = false
		velocity = Vector2.ZERO
		_is_downed = true
		_downed_timer = downed_duration
		_hit_flash_timer = 0.0
		visual.color = Color(0.28, 0.24, 0.2, 1.0)
	else:
		_hit_flash_timer = 0.14
		visual.color = Color(1.0, 0.92, 0.72, 1.0)

func is_downed() -> bool:
	return _is_downed

func _respawn() -> void:
	_is_downed = false
	_downed_timer = 0.0
	_skill_cooldown_remaining = 0.0
	health = maxi(roundi(float(max_health) * respawn_health_ratio), 1)
	health_changed.emit(health, max_health)
	global_position = _spawn_position
	velocity = Vector2.ZERO
	visual.color = Color(0.72, 0.49, 0.3, 1.0)
	_hit_flash_timer = 0.0
	_refresh_health_bar()
	_refresh_skill_bar()

func _cast_cleave() -> void:
	if _skill_cooldown_remaining > 0.0:
		return
	var direction := global_position.direction_to(get_global_mouse_position())
	if direction.is_zero_approx():
		direction = Vector2.RIGHT

	var slash_points := PackedVector2Array([Vector2.ZERO])
	for step in range(19):
		var angle := -PI * 0.5 + PI * float(step) / 18.0
		slash_points.append(Vector2.from_angle(angle) * cleave_range)
	var slash := Polygon2D.new()
	slash.polygon = slash_points
	slash.color = Color(1.0, 0.55, 0.22, 0.36)
	slash.rotation = direction.angle()
	get_tree().current_scene.add_child(slash)
	slash.global_position = global_position
	var fade := get_tree().create_tween()
	fade.tween_property(slash, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.22)
	fade.tween_callback(slash.queue_free)

	for candidate in get_tree().get_nodes_in_group("enemies"):
		var enemy := candidate as Node2D
		if enemy == null or not enemy.has_method("is_alive") or not bool(enemy.call("is_alive")):
			continue
		var to_enemy := enemy.global_position - global_position
		if to_enemy.length() <= cleave_range and direction.dot(to_enemy.normalized()) >= 0.0:
			enemy.call("take_damage", skill_damage)

	_skill_cooldown_remaining = skill_cooldown
	_refresh_skill_bar()

func _cast_ashen_bolt() -> void:
	if _skill_cooldown_remaining > 0.0:
		return
	var target := _get_skill_target()
	if target == null or global_position.distance_to(target.global_position) > skill_range:
		return

	var bolt := ASHEN_BOLT_SCENE.instantiate() as Node2D
	get_tree().current_scene.add_child(bolt)
	bolt.global_position = global_position
	bolt.call("launch", target, skill_damage)
	_skill_cooldown_remaining = skill_cooldown
	_refresh_skill_bar()

func _activate_skill_slot(slot_index: int) -> void:
	if slot_index == 0:
		_cast_cleave()

func _get_skill_target() -> Node2D:
	if is_instance_valid(_attack_target) and bool(_attack_target.call("is_alive")):
		return _attack_target
	var nearest_enemy: Node2D
	var nearest_distance := skill_range
	for candidate in get_tree().get_nodes_in_group("enemies"):
		var enemy := candidate as Node2D
		if enemy == null or not enemy.has_method("is_alive") or not bool(enemy.call("is_alive")):
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy
	return nearest_enemy

func _refresh_health_bar() -> void:
	var fill_width := 20.0 * float(health) / float(max_health)
	health_fill.polygon = PackedVector2Array([Vector2(-10.0, -2.0), Vector2(-10.0 + fill_width, -2.0), Vector2(-10.0 + fill_width, 2.0), Vector2(-10.0, 2.0)])

func _refresh_skill_bar() -> void:
	var progress := 1.0
	if skill_cooldown > 0.0 and _skill_cooldown_remaining > 0.0:
		progress = 1.0 - _skill_cooldown_remaining / skill_cooldown
	var fill_width := 20.0 * progress
	skill_fill.polygon = PackedVector2Array([Vector2(-10.0, -2.0), Vector2(-10.0 + fill_width, -2.0), Vector2(-10.0 + fill_width, 2.0), Vector2(-10.0, 2.0)])

func add_item(item_id: String) -> void:
	if item_id == "health_potion":
		health_potions += 1
		inventory_changed.emit()
		return
	if inventory.has(item_id):
		return
	inventory.append(item_id)
	inventory_changed.emit()

func use_health_potion() -> void:
	if _is_downed or health_potions <= 0 or health >= max_health:
		return
	health_potions -= 1
	health = mini(health + 40, max_health)
	_refresh_health_bar()
	health_changed.emit(health, max_health)
	inventory_changed.emit()

func has_item(item_id: String) -> bool:
	return inventory.has(item_id)

func equip_rusty_sword() -> void:
	if not inventory.has("rusty_sword") or rusty_sword_equipped:
		return
	rusty_sword_equipped = true
	inventory_changed.emit()

func unequip_rusty_sword() -> void:
	if not rusty_sword_equipped:
		return
	rusty_sword_equipped = false
	inventory_changed.emit()

func prepare_for_location_change(spawn_position: Vector2) -> void:
	_clear_attack_target()
	_has_move_target = false
	velocity = Vector2.ZERO
	_spawn_position = spawn_position

func add_silver(amount: int) -> void:
	silver += maxi(amount, 0)
	silver_changed.emit(silver)

func add_experience(amount: int) -> void:
	experience += maxi(amount, 0)
	while experience >= experience_to_next_level:
		experience -= experience_to_next_level
		level += 1
		experience_to_next_level = 100 + (level - 1) * 50
		stat_points += 1
		max_health += 10
		attack_damage += 2
		skill_damage += 5
		health = max_health
		_refresh_health_bar()
		health_changed.emit(health, max_health)
	progression_changed.emit(level, experience, experience_to_next_level, stat_points)

func spend_stat_point(stat_name: String) -> void:
	if stat_points <= 0:
		return
	match stat_name:
		"vitality":
			max_health += 5
			health = mini(health + 5, max_health)
			_refresh_health_bar()
			health_changed.emit(health, max_health)
		"strength":
			attack_damage += 1
		"attack_speed":
			attack_speed += 0.1
		"arcana":
			skill_damage += 2
		_:
			return
	stat_points -= 1
	progression_changed.emit(level, experience, experience_to_next_level, stat_points)

func _find_item_at(click_position: Vector2) -> Node2D:
	var nearest_item: Node2D
	var nearest_distance := selection_radius
	for candidate in get_tree().get_nodes_in_group("items"):
		var item := candidate as Node2D
		if item == null or global_position.distance_to(item.global_position) > pickup_range:
			continue
		var distance := click_position.distance_to(item.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_item = item
	return nearest_item

func _find_loot_at(click_position: Vector2) -> Node2D:
	var nearest_loot: Node2D
	var nearest_distance := selection_radius
	for candidate in get_tree().get_nodes_in_group("loot"):
		var loot := candidate as Node2D
		if loot == null or global_position.distance_to(loot.global_position) > pickup_range:
			continue
		var distance := click_position.distance_to(loot.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_loot = loot
	return nearest_loot

func _find_enemy_at(click_position: Vector2) -> Node2D:
	var nearest_enemy: Node2D
	var nearest_distance := selection_radius
	for candidate in get_tree().get_nodes_in_group("enemies"):
		var enemy := candidate as Node2D
		if enemy == null or not enemy.has_method("is_alive") or not bool(enemy.call("is_alive")):
			continue
		var distance := click_position.distance_to(enemy.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy
	return nearest_enemy

func _set_attack_target(target: Node2D) -> void:
	if _attack_target == target:
		return
	_clear_attack_target()
	_attack_target = target
	_attack_target.call("set_selected", true)
	if _attack_timer <= 0.0:
		_attack_timer = 1.0 / maxf(attack_speed, 0.1)
	navigation_agent.target_position = _attack_target.global_position
	_has_move_target = true

func _clear_attack_target() -> void:
	if is_instance_valid(_attack_target):
		_attack_target.call("set_selected", false)
	_attack_target = null
