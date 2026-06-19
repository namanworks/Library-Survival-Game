# ChildSpawner.gd
# Spawns children at map-edge Marker2D nodes.
# Spawn interval lerps from SPAWN_INTERVAL_START → SPAWN_INTERVAL_END over 30 min.
# Listens to EventManager for wave spawns.
extends Node

# ── Child scene paths ──────────────────────────────────────────────────────────
const CHILD_SCENES: Dictionary = {
	"curious_child":    "res://scenes/entities/children/CuriousChild.tscn",
	"speed_reader":     "res://scenes/entities/children/SpeedReader.tscn",
	"book_fort_builder":"res://scenes/entities/children/BookFortBuilder.tscn",
	"hide_and_seek_kid":"res://scenes/entities/children/HideAndSeekKid.tscn",
	"sugar_rush_kid":   "res://scenes/entities/children/SugarRushKid.tscn",
	"teen_influencer":  "res://scenes/entities/children/TeenInfluencer.tscn",
}

# ── State ──────────────────────────────────────────────────────────────────────
var _spawn_timer: float             = 0.0
var _spawn_points: Array            = []
var _children_node: Node2D          = null
var _child_data: Array              = []       # loaded from child_types.json
var _loaded_scenes: Dictionary      = {}       # type_id -> PackedScene (cached)
var _event_spawn_rate_mult: float   = 1.0
var _event_speed_mult: float        = 1.0

@onready var _children_container: Node2D = $Children

# ── Lifecycle ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	GameManager.run_started.connect(_on_run_started)
	GameManager.run_ended.connect(_on_run_ended)
	EventManager.event_started.connect(_on_event_started)
	EventManager.event_ended.connect(_on_event_ended)
	_load_child_data()
	_preload_scenes()

func _process(delta: float) -> void:
	if not GameManager.is_running:
		return
	if get_child_count_in_game() >= GameConstants.MAX_CHILDREN_ON_MAP:
		return

	_spawn_timer -= delta * _event_spawn_rate_mult
	if _spawn_timer <= 0.0:
		_spawn_timer = _get_current_spawn_interval()
		_spawn_child(_pick_child_type())

# ── Public API ─────────────────────────────────────────────────────────────────
func get_child_count_in_game() -> int:
	return _children_container.get_child_count()

func spawn_wave(type_id: String, count: int) -> void:
	## Spawns a specific number of a specific child type (for boss events).
	for _i in range(count):
		if get_child_count_in_game() >= GameConstants.MAX_CHILDREN_ON_MAP:
			break
		_spawn_child(type_id)

func spawn_wave_mixed(count: int) -> void:
	## Spawns a wave of mixed child types for generic waves.
	for _i in range(count):
		if get_child_count_in_game() >= GameConstants.MAX_CHILDREN_ON_MAP:
			break
		_spawn_child(_pick_child_type())

func set_event_speed_mult(mult: float) -> void:
	## Called by EventManager when a speed_multiplier effect fires.
	_event_speed_mult = mult

# ── Private ────────────────────────────────────────────────────────────────────
func _spawn_child(type_id: String) -> void:
	if _spawn_points.is_empty():
		_cache_spawn_points()
	if _spawn_points.is_empty():
		push_warning("ChildSpawner: no spawn points found")
		return

	var scene: PackedScene = _get_scene(type_id)
	if not scene:
		# Fallback to CuriousChild if type not found (Phase 1 only has CuriousChild)
		scene = _get_scene("curious_child")
	if not scene:
		return

	var child: Node = scene.instantiate()
	var spawn_point: Node2D = _spawn_points[randi() % _spawn_points.size()]
	_children_container.add_child(child)
	child.global_position = spawn_point.global_position

	# Apply event speed multiplier
	if _event_speed_mult != 1.0 and child.has_method("set_global_boldness_modifier"):
		child.base_move_speed *= _event_speed_mult

func _pick_child_type() -> String:
	## Weighted random selection based on current game phase.
	var run_time: float = GameManager.run_time
	var phase: String
	if run_time < 600.0:
		phase = "early"
	elif run_time < 1200.0:
		phase = "mid"
	else:
		phase = "late"

	var weighted: Array = []
	for entry in _child_data:
		var type: String = entry.get("type_id", "curious_child")
		# Only spawn types that have scenes loaded
		if not type in _loaded_scenes:
			continue
		var weight: float = entry.get("spawn_weight_" + phase, 0.0)
		var weight_int: int = int(weight * 10.0)
		for _w in range(weight_int):
			weighted.append(type)

	if weighted.is_empty():
		return "curious_child"
	return weighted[randi() % weighted.size()]

func _get_current_spawn_interval() -> float:
	var t: float = clampf(GameManager.run_time / GameConstants.RUN_DURATION, 0.0, 1.0)
	return lerpf(GameConstants.SPAWN_INTERVAL_START, GameConstants.SPAWN_INTERVAL_END, t)

func _cache_spawn_points() -> void:
	_spawn_points = get_tree().get_nodes_in_group("spawn_points")

func _get_scene(type_id: String) -> PackedScene:
	if type_id in _loaded_scenes:
		return _loaded_scenes[type_id]
	return null

func _preload_scenes() -> void:
	## Pre-load only scenes that exist (Phase 1: only CuriousChild)
	for type_id in CHILD_SCENES:
		var path: String = CHILD_SCENES[type_id]
		if ResourceLoader.exists(path):
			_loaded_scenes[type_id] = load(path)

func _load_child_data() -> void:
	var file := FileAccess.open("res://data/child_types.json", FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		_child_data = json.get_data()
	file.close()

func _on_run_started() -> void:
	_spawn_timer = 2.0  # short delay before first spawn
	_event_spawn_rate_mult = 1.0
	_event_speed_mult = 1.0
	_cache_spawn_points()
	# Spawn initial children
	for _i in range(GameConstants.INITIAL_CHILD_COUNT):
		_spawn_child("curious_child")

func _on_run_ended(_won: bool) -> void:
	# Clear all children
	for child in _children_container.get_children():
		child.queue_free()

func _on_event_started(event_data: Dictionary) -> void:
	for effect in event_data.get("effects", []):
		match effect.get("type", ""):
			"spawn_wave":
				var target: String = effect.get("target", "all")
				var count: int     = int(effect.get("value", 1.0))
				if target == "all":
					spawn_wave_mixed(count)
				else:
					spawn_wave(target, count)
			"spawn_rate_mult":
				_event_spawn_rate_mult = effect.get("value", 1.0)
			"speed_multiplier":
				_event_speed_mult = effect.get("value", 1.0)

func _on_event_ended(_event_id: String) -> void:
	_event_spawn_rate_mult = 1.0
	_event_speed_mult = 1.0
