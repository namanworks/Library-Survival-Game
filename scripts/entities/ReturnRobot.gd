# ReturnRobot.gd
# Automation NPC. Stationary (or slow mover). Auto-shelves any floor books
# within RETURN_ROBOT_RADIUS every second. Max 2 can be active.
extends CharacterBody2D

@onready var ROBOT_RADIUS: float   = GameConstants.RETURN_ROBOT_RADIUS
const SHELVE_INTERVAL: float = 1.2   # seconds between auto-shelve cycles

var _shelve_timer: float = 0.0

@onready var _sprite: Sprite2D      = $Sprite2D
@onready var _range_area: Area2D    = $RangeArea

func _ready() -> void:
	add_to_group("automation_npcs")
	_build_robot_sprite()
	GameManager.run_ended.connect(queue_free)

func _process(delta: float) -> void:
	if not GameManager.is_running or get_tree().paused:
		return

	_shelve_timer -= delta
	if _shelve_timer <= 0.0:
		_shelve_timer = SHELVE_INTERVAL
		_auto_shelve_nearby()

func _auto_shelve_nearby() -> void:
	## Picks the first floor book within radius and shelves it if a matching shelf exists.
	var floor_books: Array = BookManager.get_floor_books_within(global_position, ROBOT_RADIUS)
	for book in floor_books:
		if not is_instance_valid(book) or book.state != book.State.ON_FLOOR:
			continue

		# Find matching shelf
		var shelf: Node = _find_shelf_for_genre(book.genre)
		if not shelf:
			continue

		# Shelve it
		book.shelve()
		BookManager.return_book_to_pool(book)
		shelf.return_books(1)
		GameManager.add_book_shelved()
		ChaosManager.reduce_chaos(GameConstants.CHAOS_REDUCTION_PER_BOOK)
		AudioManager.play_sfx("book_shelved")
		break  # one book per cycle keeps it balanced

func _find_shelf_for_genre(genre: String) -> Node:
	var nearest: Node = null
	var nearest_dist: float = INF
	for shelf in get_tree().get_nodes_in_group("shelves"):
		if shelf.genre == genre and shelf.active:
			var d: float = global_position.distance_to(shelf.global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest = shelf
	return nearest

func _build_robot_sprite() -> void:
	_sprite.modulate = Color(0.8, 0.8, 0.85).darkened(0.1)
