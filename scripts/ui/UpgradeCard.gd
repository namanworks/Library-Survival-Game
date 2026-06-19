# UpgradeCard.gd
extends PanelContainer

signal selected(upgrade_id: String)

@onready var _icon: TextureRect = $VBox/Icon
@onready var _name_lbl: Label = $VBox/UpgradeName
@onready var _category_lbl: Label = $VBox/Category
@onready var _desc_lbl: Label = $VBox/Description
@onready var _select_btn: Button = $VBox/SelectButton

var upgrade_id: String = ""

func _ready() -> void:
	_select_btn.pressed.connect(_on_select_pressed)
	# Premium visual hover animations
	custom_minimum_size = Vector2(220, 320)
	pivot_offset = custom_minimum_size / 2.0
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup(upgrade_data: Dictionary) -> void:
	upgrade_id = upgrade_data.get("id", "")
	_name_lbl.text = upgrade_data.get("display_name", "Upgrade")
	_category_lbl.text = upgrade_data.get("category", "").capitalize()
	_desc_lbl.text = upgrade_data.get("description", "")
	
	# Load icon if it exists, otherwise use fallback procedural texture
	var icon_path: String = upgrade_data.get("icon", "")
	if ResourceLoader.exists(icon_path):
		_icon.texture = load(icon_path)
	else:
		var color := Color(0.2, 0.6, 0.9)
		if upgrade_data.get("rarity", "") == "rare":
			color = Color(0.95, 0.8, 0.1) # Gold
		var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
		img.fill(color)
		
		# Draw simple inner frame to make it look premium
		for x in range(2, 46):
			img.set_pixel(x, 2, Color.WHITE)
			img.set_pixel(x, 45, Color.WHITE)
		for y in range(2, 46):
			img.set_pixel(2, y, Color.WHITE)
			img.set_pixel(45, y, Color.WHITE)
			
		_icon.texture = ImageTexture.create_from_image(img)

func _on_select_pressed() -> void:
	selected.emit(upgrade_id)

func _on_mouse_entered() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	modulate = Color(1.1, 1.1, 1.1, 1.0) # Subtle brightness boost

func _on_mouse_exited() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	modulate = Color.WHITE
