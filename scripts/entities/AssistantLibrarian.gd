# AssistantLibrarian.gd
# Automation NPC. Patrols the library and collects floor books, shelving them
# automatically. Max 1 can be active (enforced by automation cap).
extends CharacterBody2D

@onready var PATROL_SPEED: float   = GameConstants.ASSISTANT_PATROL_SPEED
@onready var INVENTORY_CAP: int    = GameConstants.ASSISTANT_INVENTORY

var _books_held: int        = 0
var _state: String          = "PATROL"  # PATROL | PICKING_UP | SHELVING | RETURNING
var _target_book: Node      = null
var _target_shelf: Node     = null
var _patrol_timer: float    = 0.0

@onready var _nav: NavigationAgent2D = $NavigationAgent2D
@onready var _sprite: Sprite2D       = $Sprite2D

func _ready() -> void:
	add_to_group("automation_npcs")
	_build_assistant_sprite()
	GameManager.run_ended.connect(queue_free)

func _physics_process(delta: float) -> void:
	if not GameManager.is_running or get_tree().paused:
		return

	match _state:
		"PATROL":    _do_patrol(delta)
		"PICKING_UP": _do_pickup()
		"SHELVING":  _do_shelving()

func _do_patrol(delta: float) -> void:
	_patrol_timer -= delta
	if _patrol_timer <= 0.0:
		_patrol_timer = randf_range(1.5, 3.0)
		# Look for a floor book to pick up
		if _books_held < INVENTORY_CAP:
			_target_book = _find_nearest_floor_book()
			if _target_book:
				_state = "PICKING_UP"
				_nav.target_position = _target_book.global_position
				return
		# All full — find shelf to return books
		if _books_held > 0:
			_target_shelf = _find_active_shelf()
			if _target_shelf:
				_state = "SHELVING"
				_nav.target_position = _target_shelf.global_position
				return
		# Just wander
		_nav.target_position = _random_patrol_point()

	_move_toward_target()

func _do_pickup() -> void:
	if not _target_book or not is_instance_valid(_target_book):
		_state = "PATROL"
		return
	_nav.target_position = _target_book.global_position
	_move_toward_target()

	if global_position.distance_to(_target_book.global_position) < 32.0:
		if _target_book.state == _target_book.State.ON_FLOOR:
			_target_book.pick_up()
			BookManager.notify_book_picked_up(_target_book)
			_books_held += 1
		_target_book = null
		_state = "PATROL"

func _do_shelving() -> void:
	if not _target_shelf or not is_instance_valid(_target_shelf):
		_state = "PATROL"
		return
	_nav.target_position = _target_shelf.global_position
	_move_toward_target()

	if global_position.distance_to(_target_shelf.global_position) < 48.0:
		# Return books
		var to_shelve: int = mini(_books_held, _target_shelf.max_books - _target_shelf.books_on_shelf)
		for _i in range(to_shelve):
			_target_shelf.return_books(1)
			GameManager.add_book_shelved()
			ChaosManager.reduce_chaos(GameConstants.CHAOS_REDUCTION_PER_BOOK)
			AudioManager.play_sfx("book_shelved")
		_books_held = maxi(0, _books_held - to_shelve)
		_target_shelf = null
		_state = "PATROL"

func _move_toward_target() -> void:
	if _nav.is_navigation_finished():
		return
	var next: Vector2 = _nav.get_next_path_position()
	velocity = (next - global_position).normalized() * PATROL_SPEED
	move_and_slide()

func _find_nearest_floor_book() -> Node:
	var nearest: Node = null
	var dist: float = INF
	for book in BookManager.get_all_floor_books():
		if not is_instance_valid(book) or book.state != book.State.ON_FLOOR:
			continue
		var d: float = global_position.distance_to(book.global_position)
		if d < dist:
			dist = d
			nearest = book
	return nearest

func _find_active_shelf() -> Node:
	var shelves: Array = get_tree().get_nodes_in_group("shelves")
	if shelves.is_empty():
		return null
	return shelves[randi() % shelves.size()]

func _random_patrol_point() -> Vector2:
	return Vector2(randf_range(100.0, 2300.0), randf_range(100.0, 1700.0))

func _build_assistant_sprite() -> void:
	_sprite.modulate = Color(0.4, 0.6, 0.9).lightened(0.2)
