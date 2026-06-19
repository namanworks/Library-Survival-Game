# RunSummary.gd
# End-of-run screen. Shows win/lose header and all run statistics.
# Populated by GameManager.get_summary() on run_ended signal.
extends Control

@onready var _header_label: Label      = $Panel/VBox/HeaderLabel
@onready var _time_value: Label        = $Panel/VBox/StatsGrid/TimeValue
@onready var _books_value: Label       = $Panel/VBox/StatsGrid/BooksValue
@onready var _intercepts_value: Label  = $Panel/VBox/StatsGrid/InterceptsValue
@onready var _peak_chaos_value: Label  = $Panel/VBox/StatsGrid/PeakChaosValue
@onready var _xp_value: Label          = $Panel/VBox/StatsGrid/XPValue
@onready var _score_value: Label       = $Panel/VBox/StatsGrid/ScoreValue
@onready var _level_value: Label       = $Panel/VBox/StatsGrid/LevelValue
@onready var _play_again_btn: Button   = $Panel/VBox/ButtonRow/PlayAgainButton
@onready var _main_menu_btn: Button    = $Panel/VBox/ButtonRow/MainMenuButton

const WIN_COLOR  := Color(1.0, 0.85, 0.2)   # gold
const LOSE_COLOR := Color(0.9, 0.2, 0.2)    # red

func _ready() -> void:
	visible = false
	GameManager.run_ended.connect(_on_run_ended)
	_play_again_btn.pressed.connect(_on_play_again)
	_main_menu_btn.pressed.connect(_on_main_menu)

func _on_run_ended(won: bool) -> void:
	var summary: Dictionary = GameManager.get_summary()
	_populate(won, summary)
	visible = true
	_animate_in()

func _populate(won: bool, summary: Dictionary) -> void:
	if won:
		_header_label.text = "The Library Closes In Perfect Order."
		_header_label.modulate = WIN_COLOR
	else:
		_header_label.text = "The Library Has Fallen Into Complete Disorder."
		_header_label.modulate = LOSE_COLOR

	_time_value.text         = summary.get("survival_time", "00:00")
	_books_value.text        = str(summary.get("books_shelved", 0))
	_intercepts_value.text   = str(summary.get("children_intercepted", 0))
	_peak_chaos_value.text   = "%d%%" % int(summary.get("peak_chaos", 0.0))
	_xp_value.text           = _format_number(summary.get("total_xp", 0))
	_score_value.text        = _format_number(summary.get("final_score", 0))
	_level_value.text        = "Level %d" % summary.get("level_reached", 1)

func _animate_in() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.6)

func _on_play_again() -> void:
	get_tree().paused = false
	visible = false
	GameManager.start_run()

func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _format_number(n: int) -> String:
	## Formats large numbers with commas: 28450 → "28,450"
	var s: String = str(n)
	var result: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result
