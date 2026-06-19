# GameManager.gd
# Singleton — manages run state, timer, score, win/lose flow.
# Signals drive UI and other systems; do not query state by polling.
extends Node

# ── Run State ──────────────────────────────────────────────────────────────────
var run_time: float         = 0.0    # seconds elapsed this run
var score: int              = 0
var books_shelved: int      = 0
var children_intercepted: int = 0
var peak_chaos: float       = 0.0
var is_running: bool        = false
var current_level: int      = 1
var current_xp: int         = 0
var total_xp_earned: int    = 0

# ── Signals ────────────────────────────────────────────────────────────────────
signal run_started()
signal run_ended(won: bool)
signal closing_time_triggered()
signal score_changed(new_score: int)
signal xp_changed(new_xp: int, new_level: int)
signal level_up(new_level: int)
signal run_time_updated(time_string: String)

var _closing_time_triggered: bool = false

# ── Lifecycle ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	ChaosManager.chaos_maxed.connect(_on_chaos_maxed)
	ChaosManager.chaos_changed.connect(_on_chaos_changed)

func _process(delta: float) -> void:
	if not is_running:
		return

	run_time += delta
	run_time_updated.emit(get_run_time_string())

	# Closing Time trigger
	if run_time >= GameConstants.RUN_DURATION and not _closing_time_triggered:
		_closing_time_triggered = true
		closing_time_triggered.emit()
		# EventManager will handle the chaos spike + final wave
		# Then after CLOSING_TIME_WAVE_DURATION, check win
		get_tree().create_timer(GameConstants.CLOSING_TIME_WAVE_DURATION).timeout.connect(_check_win)

# ── Public API ─────────────────────────────────────────────────────────────────
func start_run() -> void:
	run_time = 0.0
	score = 0
	books_shelved = 0
	children_intercepted = 0
	peak_chaos = 0.0
	current_level = 1
	current_xp = 0
	total_xp_earned = 0
	is_running = true
	_closing_time_triggered = false
	run_started.emit()

func end_run(won: bool) -> void:
	if not is_running:
		return
	is_running = false
	get_tree().paused = false
	run_ended.emit(won)

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)

func add_xp(amount: int) -> void:
	# Apply Story Hour / event XP multiplier if active
	var multiplied: int = int(float(amount) * EventManager.xp_multiplier)
	current_xp += multiplied
	total_xp_earned += multiplied
	_check_level_up()
	xp_changed.emit(current_xp, current_level)

func add_book_shelved() -> void:
	books_shelved += 1
	add_score(GameConstants.SCORE_PER_BOOK_SHELVED)
	add_xp(GameConstants.XP_PER_BOOK_SHELVED)

func add_child_intercepted(xp_bonus: int = 0) -> void:
	children_intercepted += 1
	add_score(GameConstants.SCORE_INTERCEPT_BONUS)
	add_xp(GameConstants.XP_INTERCEPT_BASE + xp_bonus)
	ChaosManager.reduce_chaos(GameConstants.CHAOS_INTERCEPT_REDUCTION)

func get_run_time_string() -> String:
	var minutes: int = int(run_time / 60.0)
	var seconds: int = int(run_time) % 60
	return "%02d:%02d" % [minutes, seconds]

func get_xp_for_next_level() -> int:
	if current_level >= GameConstants.XP_CURVE.size():
		return GameConstants.XP_CURVE[-1]
	return GameConstants.XP_CURVE[current_level]  # index = next level threshold

func get_xp_progress() -> float:
	## Returns 0.0–1.0 progress toward next level
	var prev_threshold: int = GameConstants.XP_CURVE[current_level - 1]
	var next_threshold: int = get_xp_for_next_level()
	if next_threshold <= prev_threshold:
		return 1.0
	return float(current_xp - prev_threshold) / float(next_threshold - prev_threshold)

func get_summary() -> Dictionary:
	return {
		"survival_time": get_run_time_string(),
		"books_shelved": books_shelved,
		"children_intercepted": children_intercepted,
		"peak_chaos": peak_chaos,
		"total_xp": total_xp_earned,
		"final_score": score,
		"level_reached": current_level,
	}

# ── Private ────────────────────────────────────────────────────────────────────
var _pending_level_ups: int = 0

func _check_level_up() -> void:
	var next_threshold: int = get_xp_for_next_level()
	var leveled_up_this_frame = false
	while current_xp >= next_threshold and current_level < GameConstants.XP_CURVE.size():
		current_level += 1
		_pending_level_ups += 1
		leveled_up_this_frame = true
		next_threshold = get_xp_for_next_level()
	
	if leveled_up_this_frame:
		_process_pending_level_ups()

func process_next_level_up() -> void:
	_process_pending_level_ups()

func _process_pending_level_ups() -> void:
	if _pending_level_ups > 0:
		_pending_level_ups -= 1
		var level_to_grant = current_level - _pending_level_ups
		level_up.emit(level_to_grant)

func _check_win() -> void:
	if ChaosManager.chaos_percent < 100.0:
		end_run(true)
	else:
		end_run(false)

func _on_chaos_maxed() -> void:
	end_run(false)

func _on_chaos_changed(new_percent: float) -> void:
	if new_percent > peak_chaos:
		peak_chaos = new_percent
