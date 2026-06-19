# BaseChild.gd
# Parent AI for all child types. Implements the full state machine.
# Child types extend this and override specific virtual methods.
# States: IDLE | MOVING_TO_SHELF | AT_SHELF | CARRYING_BOOK | DROPPING_BOOK | FLEEING
extends CharacterBody2D

# ── Enums ──────────────────────────────────────────────────────────────────────
enum State { IDLE, MOVING_TO_SHELF, AT_SHELF, CARRYING_BOOK, DROPPING_BOOK, FLEEING }

# ── Stats (loaded from child_types.json via _get_stats()) ──────────────────────
var type_id: String             = "curious_child"
var base_move_speed: float      = 70.0
var flee_speed_multiplier: float = 1.6
var flee_radius: float          = 240.0
var boldness: float             = 0.05
var carry_probability: float    = 0.5
var carry_distance_max: float   = 400.0
var books_per_visit: int        = 1
var chaos_passive_rate: float   = 0.0
var xp_intercept_bonus: int     = 10

# ── Runtime state ──────────────────────────────────────────────────────────────
var current_state: State        = State.IDLE
var carried_book: Node          = null
var target_shelf: Node          = null
var drop_destination: Vector2   = Vector2.ZERO
var flee_direction: Vector2     = Vector2.ZERO
var idle_timer: float           = 0.0
var _at_shelf_timer: float      = 0.0
var _nav_update_timer: float    = 0.0

# Upgrade-driven modifiers (applied by Librarian's stern glare etc.)
var _slow_factor: float         = 1.0
var _is_frozen: bool            = false
var _freeze_timer: float        = 0.0
var _gathered_position: Vector2 = Vector2.ZERO
var _gather_timer: float        = 0.0

# Boldness ramp — modified by DifficultyScaler
var _global_boldness_modifier: float = 0.0  # 0.0 = none, 1.0 = fully bold

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var _sprite: Sprite2D              = $Sprite2D
@onready var _anim: AnimationPlayer         = $AnimationPlayer
@onready var _nav_agent: NavigationAgent2D  = $NavigationAgent2D
@onready var _awareness: Area2D             = $AwarenessRadius
@onready var _awareness_col: CollisionShape2D = $AwarenessRadius/CollisionShape2D
@onready var _carry_slot: Node2D            = $BookCarrySlot
@onready var _state_label: Label            = $StateLabel  # debug only

# ── Lifecycle ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("children")
	_load_stats()
	_setup_awareness_radius()
	_awareness.body_entered.connect(_on_awareness_body_entered)
	_awareness.body_exited.connect(_on_awareness_body_exited)
	_state_label.visible = false
	idle_timer = randf_range(0.5, 2.0)

func _physics_process(delta: float) -> void:
	if not GameManager.is_running:
		return

	# Handle freeze (Shushing Aura)
	if _is_frozen:
		_freeze_timer -= delta
		if _freeze_timer <= 0.0:
			_is_frozen = false
		return

	# Story Time gather
	if _gather_timer > 0.0:
		_gather_timer -= delta
		_navigate_toward(_gathered_position)
		return

	# Stagger navigation updates across children for performance
	_nav_update_timer -= delta

	# Always check flee first
	_check_flee_condition()

	match current_state:
		State.IDLE:            _handle_idle(delta)
		State.MOVING_TO_SHELF: _handle_moving_to_shelf(delta)
		State.AT_SHELF:        _handle_at_shelf(delta)
		State.CARRYING_BOOK:   _handle_carrying(delta)
		State.DROPPING_BOOK:   _handle_dropping(delta)
		State.FLEEING:         _handle_fleeing(delta)

	# State label hidden — debug display removed

# ── State Handlers ─────────────────────────────────────────────────────────────
func _handle_idle(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, base_move_speed * 4.0 * delta)
	move_and_slide()
	idle_timer -= delta
	if idle_timer <= 0.0:
		target_shelf = _find_nearest_active_shelf()
		if target_shelf:
			_navigate_to(target_shelf.global_position)
			_set_state(State.MOVING_TO_SHELF)
		else:
			idle_timer = randf_range(1.0, 3.0)

func _handle_moving_to_shelf(_delta: float) -> void:
	if _nav_update_timer <= 0.0:
		_nav_update_timer = GameConstants.NAV_UPDATE_STAGGER
		if target_shelf and is_instance_valid(target_shelf):
			_navigate_to(target_shelf.global_position)

	_move_along_nav_path()

	if _nav_agent.is_navigation_finished():
		_set_state(State.AT_SHELF)
		_at_shelf_timer = 0.3  # brief pause before taking book

func _handle_at_shelf(delta: float) -> void:
	## Override per child type. Base: take one book, decide carry or local drop.
	_at_shelf_timer -= delta
	if _at_shelf_timer > 0.0:
		return

	_on_reach_shelf(target_shelf)

func _handle_carrying(_delta: float) -> void:
	if carried_book and is_instance_valid(carried_book) and _carry_slot:
		carried_book.global_position = _carry_slot.global_position

	if _nav_update_timer <= 0.0:
		_nav_update_timer = GameConstants.NAV_UPDATE_STAGGER
		_navigate_to(drop_destination)

	_move_along_nav_path()

	if _nav_agent.is_navigation_finished():
		_set_state(State.DROPPING_BOOK)

func _handle_dropping(_delta: float) -> void:
	if carried_book and is_instance_valid(carried_book):
		carried_book.place_on_floor(global_position)
		BookManager.notify_book_dropped(carried_book)
		carried_book = null
	_set_state(State.IDLE)
	idle_timer = randf_range(1.0, 3.0)

func _handle_fleeing(_delta: float) -> void:
	var flee_target: Vector2 = global_position + flee_direction.normalized() * 200.0
	_navigate_to(flee_target)
	_move_along_nav_path(flee_speed_multiplier)

# ── Flee Logic ─────────────────────────────────────────────────────────────────
func _check_flee_condition() -> void:
	pass  # Handled by _on_awareness_body_entered signal

func _on_awareness_body_entered(body: Node2D) -> void:
	if not body.is_in_group("librarian"):
		return
	if _boldness_check_passes():
		flee_direction = (global_position - body.global_position).normalized()
		_set_state(State.FLEEING)

func _on_awareness_body_exited(body: Node2D) -> void:
	if not body.is_in_group("librarian"):
		return
	if current_state == State.FLEEING:
		_set_state(State.IDLE)
		idle_timer = randf_range(0.5, 1.5)

func _boldness_check_passes() -> bool:
	var effective_boldness: float = boldness * (1.0 - _global_boldness_modifier)
	effective_boldness = clampf(effective_boldness, 0.0, 1.0)
	return randf() > effective_boldness

# ── Interception ───────────────────────────────────────────────────────────────
func on_librarian_touch(librarian: Node) -> void:
	## Called by Librarian when bodies overlap. Drop book, emit intercepted signal.
	if carried_book and is_instance_valid(carried_book):
		var drop_pos: Vector2 = global_position
		carried_book.place_on_floor(drop_pos)
		BookManager.notify_book_dropped(carried_book)

		# Librarian auto-picks up via PickupRadius — no manual call needed
		var xp_bonus: int = xp_intercept_bonus
		GameManager.add_child_intercepted(xp_bonus)
		AudioManager.play_sfx("intercept")
		carried_book = null

	flee_direction = (global_position - librarian.global_position).normalized()
	_set_state(State.FLEEING)

# ── Virtual methods (override in child types) ───────────────────────────────────
func _on_reach_shelf(shelf: Node) -> void:
	## Base: remove one book, either carry or drop locally.
	if not shelf or not is_instance_valid(shelf):
		_set_state(State.IDLE)
		return
	if not shelf.remove_book():
		_set_state(State.IDLE)
		idle_timer = randf_range(0.5, 1.5)
		return

	var book: Node = BookManager.get_book_from_shelf(shelf.genre, global_position)
	if not book:
		_set_state(State.IDLE)
		return

	if randf() < carry_probability:
		carried_book = book
		carried_book.carried_by = self
		carried_book.set_state(carried_book.State.CARRIED)
		if _carry_slot:
			carried_book.global_position = _carry_slot.global_position
		drop_destination = _get_carry_destination()
		_set_state(State.CARRYING_BOOK)
	else:
		# Drop locally next to shelf
		var offset: Vector2 = Vector2(randf_range(-30, 30), randf_range(-30, 30))
		book.place_on_floor(global_position + offset)
		BookManager.notify_book_dropped(book)
		_set_state(State.IDLE)
		idle_timer = randf_range(1.0, 3.0)

func _get_flee_direction() -> Vector2:
	## Override for Hide and Seek Kid's unpredictable flee.
	return flee_direction

func _get_carry_destination() -> Vector2:
	## Override for Speed Reader (prefers far zones) and Hide & Seek (random).
	# Base: random point within carry_distance_max
	var angle: float = randf() * TAU
	var dist: float  = randf_range(50.0, carry_distance_max)
	return global_position + Vector2(cos(angle), sin(angle)) * dist

# ── Upgrade interactions (called by Librarian) ─────────────────────────────────
func apply_slow(factor: float) -> void:
	_slow_factor = 1.0 - factor

func remove_slow() -> void:
	_slow_factor = 1.0

func freeze_briefly(duration: float) -> void:
	_is_frozen = true
	_freeze_timer = duration

func force_gather(target_pos: Vector2, duration: float) -> void:
	_gathered_position = target_pos
	_gather_timer = duration

func set_global_boldness_modifier(modifier: float) -> void:
	_global_boldness_modifier = modifier
	var circle: CircleShape2D = _awareness_col.shape as CircleShape2D
	if circle:
		circle.radius = flee_radius * (1.0 - modifier)

# ── Navigation helpers ─────────────────────────────────────────────────────────
func _navigate_to(target: Vector2) -> void:
	_nav_agent.target_position = target

func _navigate_toward(target: Vector2) -> void:
	_navigate_to(target)
	_move_along_nav_path()

func _move_along_nav_path(speed_multiplier: float = 1.0) -> void:
	if _nav_agent.is_navigation_finished():
		return
	var next_pos: Vector2 = _nav_agent.get_next_path_position()
	var direction: Vector2 = (next_pos - global_position).normalized()
	velocity = direction * base_move_speed * speed_multiplier * _slow_factor
	move_and_slide()

func _find_nearest_active_shelf() -> Node:
	var nearest: Node = null
	var nearest_dist: float = INF
	for shelf in get_tree().get_nodes_in_group("shelves"):
		if not shelf.active or not shelf.has_books():
			continue
		var d: float = global_position.distance_to(shelf.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = shelf
	return nearest

# ── State helper ───────────────────────────────────────────────────────────────
func _set_state(new_state: State) -> void:
	current_state = new_state

# ── Setup ──────────────────────────────────────────────────────────────────────
func _load_stats() -> void:
	## Loads stats from the child_types.json data via child type id.
	var file := FileAccess.open("res://data/child_types.json", FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return
	file.close()
	for entry in json.get_data():
		if entry.get("type_id", "") == type_id:
			base_move_speed      = entry.get("base_move_speed", base_move_speed)
			flee_speed_multiplier = entry.get("flee_speed_multiplier", flee_speed_multiplier)
			flee_radius          = entry.get("flee_radius", flee_radius)
			boldness             = entry.get("boldness", boldness)
			carry_probability    = entry.get("carry_probability", carry_probability)
			carry_distance_max   = entry.get("carry_distance_max", carry_distance_max)
			books_per_visit      = entry.get("books_per_visit", books_per_visit)
			chaos_passive_rate   = entry.get("chaos_passive_rate", chaos_passive_rate)
			xp_intercept_bonus   = entry.get("xp_intercept_bonus", xp_intercept_bonus)
			break

func _setup_awareness_radius() -> void:
	var circle: CircleShape2D = _awareness_col.shape as CircleShape2D
	if circle:
		circle.radius = flee_radius
