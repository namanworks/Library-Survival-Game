# EventManager.gd
# Singleton — schedules and fires all special events and boss events.
# Fully wired for Phase 4: all event effects are now implemented.
extends Node

# ── State ──────────────────────────────────────────────────────────────────────
var event_queue: Array         = []  # sorted by trigger_time, pending events
var active_event: Dictionary   = {}  # currently running event or empty dict
var _elapsed_time: float       = 0.0
var _event_data: Array         = []  # loaded from events.json
var _active_event_timer: float = 0.0
var _warning_shown: Dictionary = {}  # event_id -> bool, tracks if warning fired

# ── Exposed Multipliers ─────────────────────────────────────────────────────────
## Read by GameManager.add_xp() to apply Story Hour bonus
var xp_multiplier: float       = 1.0

# ── Signals ────────────────────────────────────────────────────────────────────
signal event_started(event_data: Dictionary)
signal event_ended(event_id: String)
signal event_warning(event_data: Dictionary)
## Fired when a Book Fair (open_shop) event triggers
signal open_shop_requested()

func _ready() -> void:
	set_process(false)
	GameManager.run_started.connect(_on_run_started)
	GameManager.run_ended.connect(_on_run_ended)

func _process(delta: float) -> void:
	if not GameManager.is_running:
		return

	_elapsed_time += delta

	# Check for event warnings and triggers
	for event in event_queue.duplicate():
		var warn_time: float = event.trigger_time - event.warning_time
		var event_id: String = event.id

		# Fire warning
		if event.warning_time > 0.0 and _elapsed_time >= warn_time and not _warning_shown.get(event_id, false):
			_warning_shown[event_id] = true
			event_warning.emit(event)

		# Fire event
		if _elapsed_time >= event.trigger_time:
			event_queue.erase(event)
			trigger_event(event)

	# Count down active event
	if not active_event.is_empty():
		_active_event_timer -= delta
		if _active_event_timer <= 0.0 and active_event.get("duration", -1) >= 0.0:
			end_event()

# ── Public API ─────────────────────────────────────────────────────────────────
func schedule_events() -> void:
	## Loads events.json and populates the event queue
	var file := FileAccess.open("res://data/events.json", FileAccess.READ)
	if file == null:
		push_error("EventManager: could not open events.json")
		return
	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()
	if parse_result != OK:
		push_error("EventManager: JSON parse error in events.json")
		return
	_event_data = json.get_data()
	event_queue = _event_data.duplicate(true)
	# Sort by trigger time
	event_queue.sort_custom(func(a, b): return a.trigger_time < b.trigger_time)
	_warning_shown.clear()

func trigger_event(event_data: Dictionary) -> void:
	active_event = event_data
	_active_event_timer = event_data.get("duration", -1.0)

	# Apply event effects
	for effect in event_data.get("effects", []):
		_apply_effect(effect, event_data)

	event_started.emit(event_data)

func end_event() -> void:
	if active_event.is_empty():
		return
	var ended_id: String = active_event.get("id", "")

	# Revert temporary event multipliers
	ChaosManager.event_chaos_multiplier = 1.0
	xp_multiplier = 1.0

	# Award survival XP for surviving boss/special events
	var xp_reward: int = active_event.get("xp_reward", 0)
	if xp_reward > 0:
		GameManager.add_xp(xp_reward)

	active_event = {}
	event_ended.emit(ended_id)

func is_boss_active() -> bool:
	return not active_event.is_empty() and active_event.get("is_boss", false)

# ── Private ────────────────────────────────────────────────────────────────────
func _on_run_started() -> void:
	_elapsed_time = 0.0
	active_event = {}
	xp_multiplier = 1.0
	schedule_events()
	set_process(true)

func _on_run_ended(_won: bool) -> void:
	set_process(false)
	active_event = {}
	xp_multiplier = 1.0

func _apply_effect(effect: Dictionary, _event_dict: Dictionary) -> void:
	var effect_type: String = effect.get("type", "")
	var value: float        = effect.get("value", 0.0)
	var target: String      = effect.get("target", "all")

	match effect_type:
		"chaos_multiplier":
			ChaosManager.event_chaos_multiplier = value

		"chaos_spike":
			ChaosManager.add_chaos(value)

		"spawn_wave":
			pass  # ChildSpawner handles this via event_started signal

		"spawn_rate_mult":
			pass  # ChildSpawner handles this via event_started signal

		"speed_multiplier":
			# Apply to ALL currently-active children immediately
			for child in get_tree().get_nodes_in_group("children"):
				if is_instance_valid(child):
					child.base_move_speed *= value
			# Also let ChildSpawner apply to future spawns during this event
			var spawner: Node = _find_node_by_name("ChildSpawner")
			if spawner and spawner.has_method("set_event_speed_mult"):
				spawner.set_event_speed_mult(value)

		"unlock_shelves":
			# DifficultyScaler handles this via its periodic shelf check;
			# we force an immediate check here as well.
			var diff: Node = _find_node_by_name("DifficultyScaler")
			if diff and diff.has_method("force_shelf_check"):
				diff.force_shelf_check()

		"boldness_multiplier":
			# Permanently (for this run) reduce flee radius via DifficultyScaler.
			# The value in events.json is the new absolute multiplier (e.g. 0.65).
			var diff: Node = _find_node_by_name("DifficultyScaler")
			if diff and diff.has_method("apply_event_boldness_cap"):
				diff.apply_event_boldness_cap(value)

		"rare_books_appear":
			# Summer Reading Challenge — scatter rare books on floor
			var count: int = int(value)
			if BookManager.has_method("spawn_rare_books"):
				BookManager.spawn_rare_books(count)

		"open_shop":
			# Book Fair — pause game and open shop
			open_shop_requested.emit()

		"xp_multiplier":
			# Story Hour — XP multiplier for event duration (read by GameManager)
			xp_multiplier = value

		_:
			pass

# ── Tree search helper ─────────────────────────────────────────────────────────
func _find_node_by_name(node_name: String) -> Node:
	var root: Node = Engine.get_main_loop().root if Engine.get_main_loop() else null
	if root == null:
		return null
	return _find_recursive(root, node_name)

func _find_recursive(node: Node, target: String) -> Node:
	if node.name == target:
		return node
	for child in node.get_children():
		var result: Node = _find_recursive(child, target)
		if result:
			return result
	return null
