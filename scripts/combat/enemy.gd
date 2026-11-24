extends CharacterBody2D

const LOOT_PICKUP_SCENE: PackedScene = preload("res://scenes/items/LootPickup.tscn")
const RUSTY_SWORD_PICKUP_SCENE: PackedScene = preload("res://scenes/items/RustySwordPickup.tscn")
const HEALTH_POTION_PICKUP_SCENE: PackedScene = preload("res://scenes/items/HealthPotionPickup.tscn")

@export var max_health: int = 40
@export var move_speed: float = 72.0
@export var attack_range: float = 34.0
@export var attack_damage: int = 5
@export var attack_interval: float = 1.2
@export var experience_reward: int = 35

var health: int
var _attack_timer := 0.0
var _hit_flash_timer := 0.0
var _is_selected := false

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var visual: Polygon2D = $Visual
@onready var health_fill: Polygon2D = $HealthBar/Fill

func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	_refresh_health_bar()

func _physics_process(delta: float) -> void:
	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		if _hit_flash_timer <= 0.0:
			_update_visual_color()

	if health <= 0:
		velocity = Vector2.ZERO
		return

	var player := _nearest_player()
	if player == null:
		velocity = Vector2.ZERO
		return

	var distance_to_player := global_position.distance_to(player.global_position)
	if distance_to_player > attack_range:
		navigation_agent.target_position = player.global_position
		var next_path_position := navigation_agent.get_next_path_position()
		if navigation_agent.is_navigation_finished():
			velocity = Vector2.ZERO
		else:
			velocity = global_position.direction_to(next_path_position) * move_speed
		move_and_slide()
		return

	velocity = Vector2.ZERO
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		player.call("take_damage", attack_damage)
		_attack_timer = attack_interval

func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = maxi(health - amount, 0)
	_refresh_health_bar()
	if health == 0:
		var game_session := get_node_or_null("/root/GameSession")
		var world := get_tree().current_scene
		if game_session != null and world != null and world.has_method("get"):
			game_session.call("register_enemy_defeat", String(world.get("_current_location_path")), String(name))
		var player := get_tree().get_first_node_in_group("players")
		if player != null and player.has_method("add_experience"):
			player.call("add_experience", experience_reward)
		var loot := LOOT_PICKUP_SCENE.instantiate() as Node2D
		get_tree().current_scene.add_child(loot)
		loot.global_position = global_position
		_drop_rusty_sword()
		_drop_health_potion()
		queue_free()
		return
	_hit_flash_timer = 0.14
	visual.color = Color(1.0, 0.92, 0.72, 1.0)

func set_selected(selected: bool) -> void:
	_is_selected = selected
	_update_visual_color()

func is_alive() -> bool:
	return health > 0

func _nearest_player() -> Node2D:
	var nearest_player: Node2D
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group("players"):
		var player := candidate as Node2D
		if player == null or not player.has_method("take_damage") or (player.has_method("is_downed") and bool(player.call("is_downed"))):
			continue
		var distance := global_position.distance_to(player.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_player = player
	return nearest_player

func _refresh_health_bar() -> void:
	var fill_width := 20.0 * float(health) / float(max_health)
	health_fill.polygon = PackedVector2Array([Vector2(-10.0, -2.0), Vector2(-10.0 + fill_width, -2.0), Vector2(-10.0 + fill_width, 2.0), Vector2(-10.0, 2.0)])

func _update_visual_color() -> void:
	if _hit_flash_timer > 0.0:
		visual.color = Color(1.0, 0.92, 0.72, 1.0)
	elif _is_selected:
		visual.color = Color(1.0, 0.72, 0.32, 1.0)
	else:
		visual.color = Color(0.62, 0.2, 0.18, 1.0)
func _drop_rusty_sword() -> void:
	var player := get_tree().get_first_node_in_group("players")
	if player != null and player.has_method("has_item") and bool(player.call("has_item", "rusty_sword")):
		return
	var pickup := RUSTY_SWORD_PICKUP_SCENE.instantiate() as Node2D
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = global_position + Vector2(0, 18)

func _drop_health_potion() -> void:
	var player := get_tree().get_first_node_in_group("players")
	if player == null or int(player.get("health_potions")) >= 3:
		return
	var pickup := HEALTH_POTION_PICKUP_SCENE.instantiate() as Node2D
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = global_position + Vector2(0, -18)
