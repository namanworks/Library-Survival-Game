# DifficultyScaler.gd
# Drives the active book count ramp and child boldness ramp over the 30-minute run.
# All values come from GameConstants — never hardcoded here.
extends Node

# ── State ──────────────────────────────────────────────────────────────────────
var _current_active_book_target: int = GameConstants.ACTIVE_BOOKS_MINUTE_0
var _current_boldness_modifier: float = 0.0  # 0.0 = full flee, 1.0 = ignore librarian
var _shelf_unlock_timer: float = 0.0
const SHELF_CHECK_INTERVAL: float = 5.0  # re-check every 5 seconds

# ── Lifecycle ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	GameManager.run_started.connect(_on_run_started)
	GameManager.run_ended.connect(_on_run_ended)
	set_process(false)

func _process(delta: float) -> void:
	if not GameManager.is_running:
		return

	var run_time: float = GameManager.run_time
	var t: float = clampf(run_time / GameConstants.RUN_DURATION, 0.0, 1.0)

	# ── Active book count ramp ────────────────────────────────────────────────
	_shelf_unlock_timer -= delta
	if _shelf_unlock_timer <= 0.0:
		_shelf_unlock_timer = SHELF_CHECK_INTERVAL
		var new_target: int = _interpolate_book_count(run_time)
		if new_target != _current_active_book_target:
			_current_active_book_target = new_target
			_update_shelf_capacities(new_target)

	# ── Boldness ramp ─────────────────────────────────────────────────────────
	# As time progresses, children become bolder (flee radius shrinks)
	var new_modifier: float = lerpf(
		0.0,
		1.0 - GameConstants.BOLDNESS_MULTIPLIER_MIN_30,
		t
	)
	if abs(new_modifier - _current_boldness_modifier) > 0.01:
		_current_boldness_modifier = new_modifier
		_apply_boldness_to_children()

# ── Public API ─────────────────────────────────────────────────────────────────
func get_current_boldness_modifier() -> float:
	return _current_boldness_modifier

func get_current_active_book_target() -> int:
	return _current_active_book_target

func force_shelf_check() -> void:
	## Called by EventManager for instant shelf-unlock events.
	var new_target: int = _interpolate_book_count(GameManager.run_time)
	_current_active_book_target = new_target
	_update_shelf_capacities(new_target)

func apply_event_boldness_cap(cap_value: float) -> void:
	## Called by EventManager boldness_multiplier events.
	## cap_value is the flee-radius scale floor (e.g. 0.65 means no more than 65% flee radius).
	## We clamp the current modifier so it reaches at least (1 - cap_value).
	var min_modifier: float = 1.0 - cap_value
	if _current_boldness_modifier < min_modifier:
		_current_boldness_modifier = min_modifier
		_apply_boldness_to_children()

# ── Private ────────────────────────────────────────────────────────────────────
func _interpolate_book_count(run_time_seconds: float) -> int:
	## Piecewise linear interpolation between the 4 book count milestones.
	var minute: float = run_time_seconds / 60.0
	if minute <= 10.0:
		return int(lerpf(
			GameConstants.ACTIVE_BOOKS_MINUTE_0,
			GameConstants.ACTIVE_BOOKS_MINUTE_10,
			minute / 10.0
		))
	elif minute <= 20.0:
		return int(lerpf(
			GameConstants.ACTIVE_BOOKS_MINUTE_10,
			GameConstants.ACTIVE_BOOKS_MINUTE_20,
			(minute - 10.0) / 10.0
		))
	else:
		return int(lerpf(
			GameConstants.ACTIVE_BOOKS_MINUTE_20,
			GameConstants.ACTIVE_BOOKS_MINUTE_30,
			(minute - 20.0) / 10.0
		))

func _update_shelf_capacities(_target_total: int) -> void:
	## Bookshelf capacities are fixed at 9, disable scaling.
	pass

func _apply_boldness_to_children() -> void:
	for child in get_tree().get_nodes_in_group("children"):
		if is_instance_valid(child) and child.has_method("set_global_boldness_modifier"):
			child.set_global_boldness_modifier(_current_boldness_modifier)

func _on_run_started() -> void:
	_current_active_book_target = GameConstants.ACTIVE_BOOKS_MINUTE_0
	_current_boldness_modifier  = 0.0
	_shelf_unlock_timer         = 0.0
	# Initial shelf population
	var shelves: Array = get_tree().get_nodes_in_group("shelves")
	BookManager.spawn_books_at_shelves(shelves, GameConstants.ACTIVE_BOOKS_MINUTE_0)
	set_process(true)

func _on_run_ended(_won: bool) -> void:
	set_process(false)
