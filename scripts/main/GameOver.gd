# GameOver.gd
extends Control

@onready var _title:   Label  = $Panel/VBox/TitleLabel
@onready var _stats:   VBoxContainer = $Panel/VBox/StatsPanel
@onready var _restart: Button = $Panel/VBox/Buttons/RestartButton
@onready var _menu:    Button = $Panel/VBox/Buttons/MenuButton

const MAIN_SCENE: String    = "res://scenes/main/Main.tscn"
const MENU_SCENE: String    = "res://scenes/ui/MainMenu.tscn"

func _ready() -> void:
	_restart.pressed.connect(_on_restart)
	_menu.pressed.connect(_on_menu)
	get_tree().paused = false

func set_summary(summary: Dictionary, _won: bool) -> void:
	_build_stats(summary)

func _build_stats(summary: Dictionary) -> void:
	for child in _stats.get_children():
		child.queue_free()
	var lines: Array = [
		["Survival Time",        summary.get("survival_time", "00:00")],
		["Books Shelved",        str(summary.get("books_shelved", 0))],
		["Children Intercepted", str(summary.get("children_intercepted", 0))],
		["Peak Chaos",           "%d%%" % int(summary.get("peak_chaos", 0))],
		["Total XP Earned",      str(summary.get("total_xp", 0))],
		["Final Score",          str(summary.get("final_score", 0))],
	]
	for line in lines:
		var row := HBoxContainer.new()
		var key_lbl := Label.new()
		key_lbl.text = line[0] + ":"
		key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var val_lbl := Label.new()
		val_lbl.text = line[1]
		row.add_child(key_lbl)
		row.add_child(val_lbl)
		_stats.add_child(row)

func _on_restart() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)

func _on_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
