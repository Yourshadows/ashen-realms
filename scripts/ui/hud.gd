extends CanvasLayer

const GRID_COLUMNS := 12
const GRID_ROWS := 5
const SLOT_COUNT := GRID_COLUMNS * GRID_ROWS

@onready var dimmer: ColorRect = $Dimmer
@onready var inventory_panel: PanelContainer = $InventoryPanel
@onready var close_button: Button = $InventoryPanel/Content/Layout/Header/CloseButton
@onready var tab_container: TabContainer = $InventoryPanel/Content/Layout/Tabs
@onready var inventory_grid: GridContainer = $InventoryPanel/Content/Layout/Tabs/Inventory/InventoryColumn/InventoryGrid
@onready var silver_label: Label = $InventoryPanel/Content/Layout/Footer/CurrencyPanel/SilverLabel
@onready var character_preview: Control = $InventoryPanel/Content/Layout/Tabs/Inventory/CharacterColumn/CharacterPreview
@onready var character_level_label: Label = $InventoryPanel/Content/Layout/Tabs/Inventory/CharacterColumn/CharacterLevelLabel
@onready var character_class_label: Label = $InventoryPanel/Content/Layout/Tabs/Inventory/CharacterColumn/CharacterClassLabel
@onready var weapon_slot: Button = $InventoryPanel/Content/Layout/Tabs/Inventory/EquipmentColumn/EquipmentGrid/WeaponSlot
@onready var stat_points_label: Label = $InventoryPanel/Content/Layout/Footer/StatsPanel/StatControls/StatPointsLabel
@onready var stats_summary_label: Label = $InventoryPanel/Content/Layout/Footer/StatsPanel/StatsSummaryLabel
@onready var vitality_button: Button = $InventoryPanel/Content/Layout/Footer/StatsPanel/StatControls/StatButtons/VitalityButton
@onready var strength_button: Button = $InventoryPanel/Content/Layout/Footer/StatsPanel/StatControls/StatButtons/StrengthButton
@onready var arcana_button: Button = $InventoryPanel/Content/Layout/Footer/StatsPanel/StatControls/StatButtons/ArcanaButton
@onready var attack_speed_button: Button = $InventoryPanel/Content/Layout/Footer/StatsPanel/StatControls/StatButtons/AttackSpeedButton
@onready var map_location_label: Label = $InventoryPanel/Content/Layout/Tabs/Map/MapLayout/MapLocationLabel
@onready var ashen_location_label: Label = $InventoryPanel/Content/Layout/Tabs/Map/MapLayout/Route/AshenLocation
@onready var forest_location_label: Label = $InventoryPanel/Content/Layout/Tabs/Map/MapLayout/Route/ForestLocation
@onready var experience_bar: ProgressBar = $ExperienceBar
@onready var level_label: Label = $LevelLabel
@onready var skill_hotbar: HBoxContainer = $SkillHotbar

var _player: Node
var _inventory_buttons: Array[Button] = []
var _empty_cell_style: StyleBoxFlat
var _item_cell_style: StyleBoxFlat
var _item_cell_hover_style: StyleBoxFlat

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("players")
	_create_cell_styles()
	_create_grid_buttons()
	tab_container.set_tab_title(0, "Инвентарь")
	tab_container.set_tab_title(1, "Карта")
	tab_container.set_tab_title(2, "Таланты")
	close_button.pressed.connect(_close_inventory)
	vitality_button.pressed.connect(_on_vitality_pressed)
	strength_button.pressed.connect(_on_strength_pressed)
	arcana_button.pressed.connect(_on_arcana_pressed)
	attack_speed_button.pressed.connect(_on_attack_speed_pressed)
	vitality_button.tooltip_text = "Живучесть: +5 к максимальному здоровью"
	strength_button.tooltip_text = "Сила: +1 к урону атаки"
	arcana_button.tooltip_text = "Магия: +2 к урону навыка"
	attack_speed_button.tooltip_text = "Скорость атаки: +0,1 удара в секунду"
	weapon_slot.pressed.connect(_on_weapon_slot_pressed)
	if _player != null:
		if _player.has_signal("silver_changed"):
			_player.connect("silver_changed", _on_silver_changed)
			_on_silver_changed(int(_player.get("silver")))
		if _player.has_signal("inventory_changed"):
			_player.connect("inventory_changed", _refresh_inventory)
			_player.connect("inventory_changed", _refresh_character_panel)
		if _player.has_signal("health_changed"):
			_player.connect("health_changed", _on_health_changed)
		if _player.has_signal("progression_changed"):
			_player.connect("progression_changed", _on_progression_changed)
			_on_progression_changed(int(_player.get("level")), int(_player.get("experience")), int(_player.get("experience_to_next_level")), int(_player.get("stat_points")))
		_refresh_inventory()
		_refresh_character_panel()
	_refresh_map()

func _create_cell_styles() -> void:
	_empty_cell_style = _make_cell_style(Color(0.09, 0.095, 0.1, 1), Color(0.28, 0.29, 0.3, 1))
	_item_cell_style = _make_cell_style(Color(0.3, 0.24, 0.16, 1), Color(0.68, 0.49, 0.27, 1))
	_item_cell_hover_style = _make_cell_style(Color(0.42, 0.32, 0.19, 1), Color(0.92, 0.7, 0.36, 1))

func _make_cell_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(1)
	return style

func _create_grid_buttons() -> void:
	for slot_index in SLOT_COUNT:
		var button := Button.new()
		button.custom_minimum_size = Vector2(16.0, 16.0)
		button.add_theme_font_size_override("font_size", 8)
		button.add_theme_stylebox_override("normal", _empty_cell_style)
		button.add_theme_stylebox_override("disabled", _empty_cell_style)
		button.disabled = true
		button.set_meta("slot_index", slot_index)
		button.set_meta("item_id", "")
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_inventory_slot_pressed.bind(button))
		inventory_grid.add_child(button)
		_inventory_buttons.append(button)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_I:
		_set_inventory_visible(not inventory_panel.visible)
		get_viewport().set_input_as_handled()

func _set_inventory_visible(is_visible: bool) -> void:
	inventory_panel.visible = is_visible
	dimmer.visible = is_visible
	skill_hotbar.visible = not is_visible
	if is_visible:
		_refresh_inventory()
		_refresh_character_panel()
		_refresh_map()

func _close_inventory() -> void:
	_set_inventory_visible(false)

func _on_silver_changed(total: int) -> void:
	silver_label.text = "◆  %d серебра" % total

func _on_health_changed(_current: int, _maximum: int) -> void:
	_refresh_character_panel()

func _on_progression_changed(current_level: int, current_xp: int, required_xp: int, unspent_points: int) -> void:
	level_label.text = "Уровень %d  ·  %d / %d опыта" % [current_level, current_xp, required_xp]
	experience_bar.max_value = required_xp
	experience_bar.value = current_xp
	character_level_label.text = "Уровень %d" % current_level
	stat_points_label.text = "Очки: %d" % unspent_points
	vitality_button.disabled = unspent_points <= 0
	strength_button.disabled = unspent_points <= 0
	arcana_button.disabled = unspent_points <= 0
	attack_speed_button.disabled = unspent_points <= 0
	_refresh_character_panel()

func _refresh_inventory() -> void:
	if _player == null:
		return
	for button in _inventory_buttons:
		button.text = ""
		button.tooltip_text = ""
		button.disabled = true
		button.set_meta("item_id", "")
		button.add_theme_stylebox_override("normal", _empty_cell_style)
		button.add_theme_stylebox_override("hover", _empty_cell_style)
		button.add_theme_stylebox_override("pressed", _empty_cell_style)
		button.add_theme_stylebox_override("disabled", _empty_cell_style)

	var items: Array = _player.get("inventory")
	for item_id in items:
		var item_name := String(item_id)
		_place_inventory_item(item_name, _item_label(item_name), _item_tooltip(item_name))

	var potion_count := int(_player.get("health_potions"))
	if potion_count > 0:
		_place_inventory_item("health_potion", "З%d" % potion_count, "Зелье здоровья ×%d — восстанавливает до 40 здоровья. Нажми на занятую клетку, чтобы использовать." % potion_count)

func _place_inventory_item(item_id: String, label: String, tooltip: String) -> void:
	var item_size := _item_size(item_id)
	var origin := _find_free_space(item_size.x, item_size.y)
	if origin.x < 0:
		return
	for row in range(origin.y, origin.y + item_size.y):
		for column in range(origin.x, origin.x + item_size.x):
			var cell_index := row * GRID_COLUMNS + column
			var button := _inventory_buttons[cell_index]
			button.add_theme_stylebox_override("normal", _item_cell_style)
			button.add_theme_stylebox_override("hover", _item_cell_hover_style)
			button.add_theme_stylebox_override("pressed", _item_cell_hover_style)
			button.add_theme_stylebox_override("disabled", _item_cell_style)
			button.disabled = false
			button.tooltip_text = tooltip
			button.set_meta("item_id", item_id)
	_inventory_buttons[origin.y * GRID_COLUMNS + origin.x].text = label

func _item_size(item_id: String) -> Vector2i:
	match item_id:
		"rusty_sword":
			return Vector2i(2, 4)
		"health_potion":
			return Vector2i(2, 2)
		_:
			return Vector2i.ONE

func _find_free_space(width: int, height: int) -> Vector2i:
	for row in range(GRID_ROWS - height + 1):
		for column in range(GRID_COLUMNS - width + 1):
			var space_is_free := true
			for item_row in range(row, row + height):
				for item_column in range(column, column + width):
					var cell_button := _inventory_buttons[item_row * GRID_COLUMNS + item_column]
					if not String(cell_button.get_meta("item_id", "")).is_empty():
						space_is_free = false
						break
				if not space_is_free:
					break
			if space_is_free:
				return Vector2i(column, row)
	return Vector2i(-1, -1)

func _item_label(item_id: String) -> String:
	match item_id:
		"rusty_sword":
			return "М"
		"health_potion":
			return "З"
		_:
			return item_id.substr(0, 1).to_upper()

func _item_tooltip(item_id: String) -> String:
	match item_id:
		"rusty_sword":
			return "Ржавый меч — +5 к урону. Нажми, чтобы экипировать."
		"health_potion":
			return "Зелье здоровья — восстанавливает до 40 здоровья. Нажми, чтобы использовать."
		_:
			return item_id.replace("_", " ").capitalize()

func _on_inventory_slot_pressed(button: Button) -> void:
	if _player == null:
		return
	var item_id := String(button.get_meta("item_id", ""))
	match item_id:
		"rusty_sword":
			if _player.has_method("equip_rusty_sword"):
				_player.call("equip_rusty_sword")
		"health_potion":
			if _player.has_method("use_health_potion"):
				_player.call("use_health_potion")
	_refresh_inventory()
	_refresh_character_panel()

func _refresh_character_panel() -> void:
	if _player == null:
		return
	var equipped := bool(_player.get("rusty_sword_equipped"))
	weapon_slot.text = "Оружие\nРжавый меч" if equipped else "Оружие\nПусто"
	character_class_label.text = "Рыцарь" if String(_player.get("class_id")) == "knight" else "Без класса"
	character_preview.queue_redraw()
	stats_summary_label.text = "ЗДР %d  |  АТК %d  |  СКР %.2f  |  НАВ %d" % [int(_player.get("max_health")), int(_player.get("attack_damage")), float(_player.get("attack_speed")), int(_player.get("skill_damage"))]

func _on_weapon_slot_pressed() -> void:
	if _player == null or not _player.has_method("has_item") or not bool(_player.call("has_item", "rusty_sword")):
		return
	if bool(_player.get("rusty_sword_equipped")):
		_player.call("unequip_rusty_sword")
	else:
		_player.call("equip_rusty_sword")
	_refresh_character_panel()

func _on_vitality_pressed() -> void:
	_spend_stat_point("vitality")

func _on_strength_pressed() -> void:
	_spend_stat_point("strength")

func _on_arcana_pressed() -> void:
	_spend_stat_point("arcana")

func _on_attack_speed_pressed() -> void:
	_spend_stat_point("attack_speed")

func _spend_stat_point(stat_name: String) -> void:
	if _player != null and _player.has_method("spend_stat_point"):
		_player.call("spend_stat_point", stat_name)
	_refresh_character_panel()

func _refresh_map() -> void:
	var world := get_tree().current_scene
	var current_location := "res://scenes/world/TestMap.tscn"
	if world != null:
		current_location = String(world.get("_current_location_path"))
	var is_forest := current_location.contains("ForestRuins")
	map_location_label.text = "Текущая локация: Лесные руины" if is_forest else "Текущая локация: Пепельные поля"
	ashen_location_label.add_theme_color_override("font_color", Color(0.92, 0.72, 0.34, 1) if not is_forest else Color(0.68, 0.68, 0.64, 1))
	forest_location_label.add_theme_color_override("font_color", Color(0.92, 0.72, 0.34, 1) if is_forest else Color(0.68, 0.68, 0.64, 1))
