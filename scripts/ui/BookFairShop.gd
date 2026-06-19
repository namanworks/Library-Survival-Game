# BookFairShop.gd
# Score-based shop UI that appears during the Book Fair event.
# Pauses the game, shows purchasable upgrades, resumes when closed.
extends CanvasLayer

# ── Constants ──────────────────────────────────────────────────────────────────
const SHOP_ITEMS: Array = [
	{
		"id": "book_fair_speed",
		"display_name": "Speed Boost",
		"description": "Gulp a juice box. +15% move speed for the rest of the run.",
		"cost": 200,
		"icon": "🏃",
		"effect_type": "stat_boost",
		"effect_target": "move_speed",
		"effect_value": 0.15,
	},
	{
		"id": "book_fair_chaos",
		"display_name": "Calm the Crowd",
		"description": "A timely announcement reduces library chaos by 10%.",
		"cost": 150,
		"icon": "📢",
		"effect_type": "chaos_reduction",
		"effect_value": 10.0,
	},
	{
		"id": "book_fair_xp",
		"display_name": "Study Group",
		"description": "An impromptu study session grants 250 bonus XP.",
		"cost": 100,
		"icon": "📚",
		"effect_type": "xp_bonus",
		"effect_value": 250.0,
	},
	{
		"id": "book_fair_inventory",
		"display_name": "Library Tote Bag",
		"description": "A sturdy tote expands your carrying capacity by 2 books.",
		"cost": 300,
		"icon": "👜",
		"effect_type": "inventory_expand",
		"effect_value": 2.0,
	},
	{
		"id": "book_fair_shield",
		"display_name": "Chaos Shield",
		"description": "A noise-dampening barrier. Next 20 chaos points are absorbed for free.",
		"cost": 250,
		"icon": "🛡️",
		"effect_type": "chaos_shield",
		"effect_value": 20.0,
	},
]

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var _panel: Control          = $ShopPanel
@onready var _title: Label            = $ShopPanel/VBox/TitleLabel
@onready var _score_label: Label      = $ShopPanel/VBox/ScoreLabel
@onready var _items_grid: GridContainer = $ShopPanel/VBox/ItemsGrid
@onready var _close_btn: Button       = $ShopPanel/VBox/CloseButton
@onready var _timer_label: Label      = $ShopPanel/VBox/TimerLabel

# ── State ──────────────────────────────────────────────────────────────────────
var _purchased: Dictionary = {}
var _shop_timer: float = 60.0
var _is_open: bool = false
var _item_buttons: Array = []

# ── Lifecycle ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("book_fair_shop")
	hide()
	EventManager.open_shop_requested.connect(_on_open_shop)
	EventManager.event_ended.connect(_on_event_ended)
	_close_btn.pressed.connect(_close_shop)
	_build_items()

func _process(delta: float) -> void:
	if not _is_open:
		return
	_shop_timer -= delta
	if _shop_timer <= 0.0:
		_close_shop()
		return
	_timer_label.text = "Shop closes in: %ds" % int(ceil(_shop_timer))
	_score_label.text = "Your Score: %d points" % GameManager.score

# ── Public API ─────────────────────────────────────────────────────────────────
func open_shop(duration: float = 60.0) -> void:
	_purchased.clear()
	_shop_timer = duration
	_is_open = true
	_refresh_buttons()
	show()
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS

func _close_shop() -> void:
	_is_open = false
	hide()
	get_tree().paused = false

# ── Signal handlers ────────────────────────────────────────────────────────────
func _on_open_shop() -> void:
	open_shop(60.0)

func _on_event_ended(event_id: String) -> void:
	if event_id == "book_fair" and _is_open:
		_close_shop()

# ── Build UI ───────────────────────────────────────────────────────────────────
func _build_items() -> void:
	for child in _items_grid.get_children():
		child.queue_free()
	_item_buttons.clear()

	for item in SHOP_ITEMS:
		var card := _make_item_card(item)
		_items_grid.add_child(card)
		_item_buttons.append({"item": item, "btn": card.get_node("BuyButton")})

func _make_item_card(item: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(200, 220)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.22, 0.97)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.6, 1.0, 0.6)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var icon_lbl := Label.new()
	icon_lbl.text = item.get("icon", "🔖")
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 36)
	vbox.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = item["display_name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = item["description"]
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "💰 %d pts" % item["cost"]
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 14)
	cost_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	vbox.add_child(cost_lbl)

	var buy_btn := Button.new()
	buy_btn.name = "BuyButton"
	buy_btn.text = "BUY"
	buy_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	buy_btn.pressed.connect(_on_buy_pressed.bind(item))
	vbox.add_child(buy_btn)

	return card

func _refresh_buttons() -> void:
	for entry in _item_buttons:
		var item: Dictionary = entry["item"]
		var btn: Button = entry["btn"]
		if not is_instance_valid(btn):
			continue
		var already_bought: bool = _purchased.get(item["id"], false)
		var can_afford: bool = GameManager.score >= item["cost"]
		btn.disabled = already_bought or not can_afford
		btn.text = "SOLD" if already_bought else "BUY"
		if already_bought:
			btn.modulate = Color(0.5, 0.5, 0.5)
		elif not can_afford:
			btn.modulate = Color(0.8, 0.4, 0.4)
		else:
			btn.modulate = Color(1, 1, 1)

# ── Purchase logic ─────────────────────────────────────────────────────────────
func _on_buy_pressed(item: Dictionary) -> void:
	if GameManager.score < item["cost"]:
		return
	if _purchased.get(item["id"], false):
		return

	# Deduct cost
	GameManager.score -= item["cost"]
	GameManager.score_changed.emit(GameManager.score)
	_purchased[item["id"]] = true

	# Apply effect
	_apply_item_effect(item)
	_refresh_buttons()

func _apply_item_effect(item: Dictionary) -> void:
	var effect_type: String = item.get("effect_type", "")
	var value: float = item.get("effect_value", 0.0)

	match effect_type:
		"stat_boost":
			var target: String = item.get("effect_target", "")
			if target == "move_speed":
				var librarian: Node = get_tree().get_first_node_in_group("librarian")
				if librarian:
					librarian.move_speed *= (1.0 + value)

		"chaos_reduction":
			ChaosManager.reduce_chaos(value)

		"xp_bonus":
			GameManager.add_xp(int(value))

		"inventory_expand":
			var librarian: Node = get_tree().get_first_node_in_group("librarian")
			if librarian and librarian.has_node("Inventory"):
				librarian.get_node("Inventory").expand_capacity(int(value))

		"chaos_shield":
			if ChaosManager.has_method("set_chaos_shield"):
				ChaosManager.set_chaos_shield(value)
