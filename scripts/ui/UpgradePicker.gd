# UpgradePicker.gd
extends CanvasLayer

const CARD_SCENE: String = "res://scenes/ui/UpgradeCard.tscn"

@onready var _card_container: HBoxContainer = $Panel/CardContainer
@onready var _title_label: Label = $Panel/Title

func _ready() -> void:
	add_to_group("upgrade_picker")
	visible = false
	process_mode = PROCESS_MODE_ALWAYS # Allows UI interaction when tree is paused

func show_picker(_level: int) -> void:
	# Clear any previous cards
	for child in _card_container.get_children():
		child.queue_free()
		
	var upgrades := UpgradeManager.get_random_upgrades(3)
	if upgrades.is_empty():
		# No eligible upgrades left, resume playing
		get_tree().paused = false
		visible = false
		GameManager.process_next_level_up()
		return
		
	var card_packed := load(CARD_SCENE)
	if not card_packed:
		push_error("UpgradePicker: Failed to load card scene: " + CARD_SCENE)
		get_tree().paused = false
		visible = false
		GameManager.process_next_level_up()
		return
		
	for upgrade_data in upgrades:
		var card = card_packed.instantiate()
		_card_container.add_child(card)
		card.setup(upgrade_data)
		card.selected.connect(_on_upgrade_selected)
		
	visible = true
	get_tree().paused = true
	AudioManager.play_sfx("level_up")

func _on_upgrade_selected(upgrade_id: String) -> void:
	UpgradeManager.apply_upgrade(upgrade_id)
	AudioManager.play_sfx("upgrade_select")
	visible = false
	get_tree().paused = false
	GameManager.process_next_level_up()
