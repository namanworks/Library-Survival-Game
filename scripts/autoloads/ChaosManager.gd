# ChaosManager.gd
# Singleton — single source of truth for chaos state.
# All chaos reads and writes MUST go through this singleton.
extends Node

# ── State ──────────────────────────────────────────────────────────────────────
var chaos_percent: float      = 0.0   # 0.0 to 100.0
var floor_book_count: int     = 0     # updated by BookManager every frame
var cluster_bonus: float      = 0.0   # cached cluster chaos bonus rate
var passive_chaos_rate: float = 0.0   # from elite children (Teen Influencer etc.)
var event_chaos_multiplier: float = 1.0  # set by EventManager during events
var _chaos_shield: float = 0.0  # Book Fair shield — absorbs chaos

# ── Signals ────────────────────────────────────────────────────────────────────
signal chaos_changed(new_percent: float)
signal chaos_critical()        # fires when > 80%
signal chaos_maxed()           # fires at >= 100% → triggers game over

# ── Internals ──────────────────────────────────────────────────────────────────
var _cluster_timer: float   = 0.0
var _was_critical: bool     = false
var _all_floor_books: Array = []  # reference updated by BookManager

func _ready() -> void:
	set_process(false)  # only process when a run is active

func _process(delta: float) -> void:
	if not GameManager.is_running:
		return

	# Cluster detection runs on interval, not every frame (performance)
	_cluster_timer += delta
	if _cluster_timer >= GameConstants.CHAOS_CLUSTER_CHECK_INTERVAL:
		_cluster_timer = 0.0
		cluster_bonus = _calculate_cluster_bonus()

	# Base chaos from floor books
	var base_rate: float = floor_book_count * GameConstants.CHAOS_RATE_PER_BOOK

	# Cluster bonus (already calculated on interval above)
	# Total passive from elite children
	# Event multiplier
	var total_rate: float = (base_rate + cluster_bonus + passive_chaos_rate) * event_chaos_multiplier

	add_chaos(total_rate * delta)

# ── Public API ─────────────────────────────────────────────────────────────────
func start_run() -> void:
	chaos_percent = 0.0
	floor_book_count = 0
	cluster_bonus = 0.0
	passive_chaos_rate = 0.0
	event_chaos_multiplier = 1.0
	_chaos_shield = 0.0
	_cluster_timer = 0.0
	_was_critical = false
	set_process(true)
	chaos_changed.emit(chaos_percent)

func stop_run() -> void:
	set_process(false)

func set_chaos_shield(amount: float) -> void:
	## Book Fair — absorb the next N chaos points before chaos actually rises.
	_chaos_shield += amount

func add_chaos(amount: float) -> void:
	# Absorb from shield first
	if _chaos_shield > 0.0:
		var absorbed: float = minf(amount, _chaos_shield)
		_chaos_shield -= absorbed
		amount -= absorbed
		if amount <= 0.0:
			return

	chaos_percent = clampf(chaos_percent + amount, 0.0, 100.0)
	chaos_changed.emit(chaos_percent)

	if chaos_percent >= 100.0:
		chaos_maxed.emit()
	elif chaos_percent >= 80.0 and not _was_critical:
		_was_critical = true
		chaos_critical.emit()
	elif chaos_percent < 80.0:
		_was_critical = false

func reduce_chaos(amount: float) -> void:
	chaos_percent = clampf(chaos_percent - amount, 0.0, 100.0)
	chaos_changed.emit(chaos_percent)
	if chaos_percent < 80.0:
		_was_critical = false

func update_floor_books(count: int, books_array: Array) -> void:
	## Called by BookManager to update the floor book count and reference array
	floor_book_count = count
	_all_floor_books = books_array

func add_passive_chaos(rate: float) -> void:
	## Called by TeenInfluencer or elite children to add their passive chaos rate
	passive_chaos_rate += rate

func remove_passive_chaos(rate: float) -> void:
	passive_chaos_rate = maxf(0.0, passive_chaos_rate - rate)

func get_chaos_rate() -> float:
	## Returns total chaos being added per second at this moment
	var base_rate: float = floor_book_count * GameConstants.CHAOS_RATE_PER_BOOK
	return (base_rate + cluster_bonus + passive_chaos_rate) * event_chaos_multiplier

func get_visual_state() -> String:
	## Returns a string representing the current chaos visual state
	if chaos_percent >= GameConstants.CHAOS_THRESHOLD_DANGER:
		return "critical"
	elif chaos_percent >= GameConstants.CHAOS_THRESHOLD_WARN:
		return "danger"
	elif chaos_percent >= GameConstants.CHAOS_THRESHOLD_SAFE:
		return "warning"
	return "safe"

# ── Private ────────────────────────────────────────────────────────────────────
func _calculate_cluster_bonus() -> float:
	## Detects book clusters and returns total bonus chaos rate from them.
	## Runs every CHAOS_CLUSTER_CHECK_INTERVAL seconds, not every frame.
	if _all_floor_books.is_empty():
		return 0.0

	var cluster_count: int = 0
	var checked: Dictionary = {}

	for book in _all_floor_books:
		if not is_instance_valid(book):
			continue
		if book in checked:
			continue
		var nearby: Array = _get_books_within_radius(book.global_position, GameConstants.CHAOS_CLUSTER_RADIUS)
		if nearby.size() >= GameConstants.CHAOS_CLUSTER_THRESHOLD:
			cluster_count += 1
			for b in nearby:
				checked[b] = true

	# Bonus = each cluster multiplies the base rate by (MULTIPLIER - 1.0)
	var base_rate: float = floor_book_count * GameConstants.CHAOS_RATE_PER_BOOK
	return cluster_count * base_rate * (GameConstants.CHAOS_CLUSTER_MULTIPLIER - 1.0)

func _get_books_within_radius(origin: Vector2, radius: float) -> Array:
	var result: Array = []
	for book in _all_floor_books:
		if not is_instance_valid(book):
			continue
		if origin.distance_to(book.global_position) <= radius:
			result.append(book)
	return result
