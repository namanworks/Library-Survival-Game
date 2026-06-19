# Main.gd
# Root scene controller. Wires the run lifecycle and scene transitions.
extends Node2D

# ── Node refs ──────────────────────────────────────────────────────────────────


const GAME_OVER_SCENE: String = "res://scenes/main/GameOver.tscn"
const WIN_SCENE: String       = "res://scenes/main/WinScreen.tscn"

# ── Lifecycle ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	GameManager.run_ended.connect(_on_run_ended)
	GameManager.level_up.connect(_on_level_up)
	ChaosManager.start_run()
	# Small delay so all nodes finish _ready() before run starts
	get_tree().create_timer(0.1).timeout.connect(_start_run)

func _start_run() -> void:
	GameManager.start_run()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and GameManager.is_running:
		get_tree().paused = not get_tree().paused

# ── Run lifecycle ──────────────────────────────────────────────────────────────
func _on_run_ended(won: bool) -> void:
	await get_tree().create_timer(0.5).timeout
	var scene_path: String = WIN_SCENE if won else GAME_OVER_SCENE
	var packed: PackedScene = load(scene_path)
	if packed:
		var end_screen: Node = packed.instantiate()
		get_tree().root.add_child(end_screen)
		# Pass run summary data
		if end_screen.has_method("set_summary"):
			end_screen.set_summary(GameManager.get_summary(), won)
	queue_free()

func _on_level_up(new_level: int) -> void:
	## Show upgrade picker if it's in the scene tree
	var picker: Node = get_tree().get_first_node_in_group("upgrade_picker")
	if picker and picker.has_method("show_picker"):
		picker.show_picker(new_level)
