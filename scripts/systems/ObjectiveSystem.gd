# ObjectiveSystem.gd
# Manages mid-run objectives. Max 2 active simultaneously.
# Loads definitions from objectives.json. Fires signals for UI.
# Objectives are optional; no penalty for ignoring them.
extends Node

# ── Data ───────────────────────────────────────────────────────────────────────
var _objective_pool: Array       = []   # all objectives loaded from JSON
var _active_objectives: Array    = []   # currently active (max 2)
var _completed_ids: Array        = []   # used this run (don't repeat)
var _refresh_timer: float        = 0.0
const REFRESH_DELAY: float       = 30.0 # seconds after complete/expire before new

# ── Signals ────────────────────────────────────────────────────────────────────
signal objective_added(objective: Dictionary)
signal objective_updated(objective_id: String, current: int, target: int, time_left: float)
signal objective_completed(objective_id: String, reward: Dictionary)
signal objective_expired(objective_id: String)

func _ready() -> void:
	set_process(false)
	GameManager.run_started.connect(_on_run_started)
	GameManager.run_ended.connect(_on_run_ended)
	EventManager.event_started.connect(_on_event_started)
	EventManager.event_ended.connect(_on_event_ended)
	_load_objectives()

func _process(delta: float) -> void:
	if not GameManager.is_running:
		return

	# Tick active objectives
	for obj in _active_objectives.duplicate():
		_tick_objective(obj, delta)

	# Refresh timer between objectives
	if _active_objectives.size() < 2 and not _objective_pool.is_empty():
		_refresh_timer -= delta
		if _refresh_timer <= 0.0:
			_refresh_timer = 0.0
			_try_offer_objective()

# ── Public API ─────────────────────────────────────────────────────────────────
func notify_book_shelved(book: Node, _shelf: Node) -> void:
	## Called by Bookshelf when a book is shelved. Checks zone/count objectives.
	for obj in _active_objectives:
		match obj.get("completion_condition", ""):
			"books_returned":
				obj["_current"] = obj.get("_current", 0) + 1
				_on_objective_progress(obj)
			"zone_cleared":
				pass  # handled by zone tracking below
			"specific_book_returned":
				if book.get("is_objective_book") == true and obj.get("_target_book") == book:
					obj["_current"] = 1
					_on_objective_progress(obj)

func notify_child_intercepted(child: Node) -> void:
	## Called by GameManager/Librarian on interception.
	for obj in _active_objectives:
		if obj.get("completion_condition", "") == "specific_child_intercepted":
			if obj.get("_target_child") == child or obj.get("target_child_type", "") == child.type_id:
				obj["_current"] = 1
				_on_objective_progress(obj)

func get_active_objectives() -> Array:
	return _active_objectives.duplicate()

# ── Private ────────────────────────────────────────────────────────────────────
func _tick_objective(obj: Dictionary, delta: float) -> void:
	if obj.get("_paused", false):
		return  # don't tick timers during boss events
	if obj.get("time_limit", -1.0) < 0.0:
		return  # no time limit

	obj["_time_left"] = obj.get("_time_left", obj.get("time_limit", 60.0)) - delta
	var time_left: float = obj["_time_left"]

	objective_updated.emit(
		obj["id"],
		obj.get("_current", 0),
		obj.get("target_count", 1),
		time_left
	)

	if time_left <= 0.0:
		_expire_objective(obj)

func _on_objective_progress(obj: Dictionary) -> void:
	var current: int = obj.get("_current", 0)
	var target: int  = obj.get("target_count", 1)

	objective_updated.emit(
		obj["id"],
		current,
		target,
		obj.get("_time_left", -1.0)
	)

	if current >= target:
		_complete_objective(obj)

func _complete_objective(obj: Dictionary) -> void:
	_active_objectives.erase(obj)
	_completed_ids.append(obj["id"])

	# Grant rewards
	var xp: int = obj.get("xp_reward", 0)
	var score: int = obj.get("score_reward", 0)
	var chaos_reduction: float = obj.get("chaos_reduction_reward", 0.0)

	if xp > 0:
		GameManager.add_xp(xp)
	if score > 0:
		GameManager.add_score(score)
	if chaos_reduction > 0.0:
		ChaosManager.reduce_chaos(chaos_reduction)

	objective_completed.emit(obj["id"], {
		"xp": xp,
		"score": score,
		"chaos_reduction": chaos_reduction
	})

	_refresh_timer = REFRESH_DELAY

func _expire_objective(obj: Dictionary) -> void:
	_active_objectives.erase(obj)
	_completed_ids.append(obj["id"])
	objective_expired.emit(obj["id"])
	_refresh_timer = REFRESH_DELAY

func _try_offer_objective() -> void:
	if _active_objectives.size() >= 2:
		return
	if EventManager.is_boss_active():
		return  # no objectives during boss events

	var available: Array = []
	for obj in _objective_pool:
		if not _completed_ids.has(obj["id"]):
			available.append(obj)

	if available.is_empty():
		return

	var chosen: Dictionary = available[randi() % available.size()].duplicate(true)
	chosen["_current"] = 0
	chosen["_time_left"] = chosen.get("time_limit", 60.0)
	_active_objectives.append(chosen)
	objective_added.emit(chosen)

func _load_objectives() -> void:
	var file := FileAccess.open("res://data/objectives.json", FileAccess.READ)
	if file == null:
		push_error("ObjectiveSystem: could not open objectives.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		_objective_pool = json.get_data()
	file.close()

func _on_run_started() -> void:
	_active_objectives.clear()
	_completed_ids.clear()
	_refresh_timer = 30.0  # first objective offered 30s into run
	set_process(true)

func _on_run_ended(_won: bool) -> void:
	_active_objectives.clear()
	set_process(false)

func _on_event_started(event_data: Dictionary) -> void:
	if event_data.get("is_boss", false):
		# Pause all active objective timers during boss events
		for obj in _active_objectives:
			obj["_paused"] = true

func _on_event_ended(_event_id: String) -> void:
	for obj in _active_objectives:
		obj["_paused"] = false
