# BookManager.gd
# Manages the Book object pool. ALL book creation/destruction goes through here.
# Never call Book.new() or book.queue_free() directly — use this API only.
# Also tracks floor_book_count and notifies ChaosManager every frame.
extends Node

# ── Pool ───────────────────────────────────────────────────────────────────────
const POOL_SIZE: int                  = 200   # pre-allocate in Phase 1
const BOOK_SCENE: String              = "res://scenes/entities/Book.tscn"

var _pool: Array                      = []    # all Book nodes (active + inactive)
var _active_floor_books: Array        = []    # books currently ON_FLOOR
var _book_scene_resource: PackedScene = null

var _floor_books_node: Node2D         # parent node for floor books

# ── Signals ────────────────────────────────────────────────────────────────────
signal floor_book_count_changed(new_count: int)

# ── Lifecycle ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	_floor_books_node = Node2D.new()
	_floor_books_node.name = "FloorBooks"
	_floor_books_node.z_index = 10  # Ensure books draw over the background
	add_child(_floor_books_node)
	_book_scene_resource = load(BOOK_SCENE)
	_prewarm_pool()
	GameManager.run_started.connect(_on_run_started)
	GameManager.run_ended.connect(_on_run_ended)

func _process(_delta: float) -> void:
	# Update ChaosManager with current floor book count every frame
	if GameManager.is_running:
		ChaosManager.update_floor_books(_active_floor_books.size(), _active_floor_books)

# ── Public API ─────────────────────────────────────────────────────────────────
func get_book_from_shelf(genre: String, spawn_position: Vector2) -> Node:
	## Retrieves a book from the pool, sets it up as a floor book.
	var book: Node = _get_pooled_book()
	if not book:
		return null
	book.reset(genre)
	book.global_position = spawn_position
	# Don't place on floor yet — caller decides state
	return book

func notify_book_dropped(book: Node) -> void:
	## Called when a book lands on the floor (by child or on interception).
	if not _active_floor_books.has(book):
		_active_floor_books.append(book)
		book.add_to_group("floor_books")
		floor_book_count_changed.emit(_active_floor_books.size())

func notify_book_picked_up(book: Node) -> void:
	## Called when librarian picks up a floor book.
	_active_floor_books.erase(book)
	book.remove_from_group("floor_books")
	floor_book_count_changed.emit(_active_floor_books.size())

func return_book_to_pool(book: Node) -> void:
	## Called when a book is shelved. Resets and hides it for pool reuse.
	_active_floor_books.erase(book)
	book.remove_from_group("floor_books")
	book.return_to_pool()
	floor_book_count_changed.emit(_active_floor_books.size())

func get_floor_books_within(origin: Vector2, radius: float) -> Array:
	## Returns all currently-active floor books within radius of origin.
	var result: Array = []
	for book in _active_floor_books:
		if is_instance_valid(book) and origin.distance_to(book.global_position) <= radius:
			result.append(book)
	return result

func get_floor_book_count() -> int:
	return _active_floor_books.size()

func get_all_floor_books() -> Array:
	return _active_floor_books

func spawn_books_at_shelves(shelves: Array, _total_count: int) -> void:
	## Called by DifficultyScaler to populate the world with books.
	## Books start SHELVED (on shelf, invisible) — removed by children during play.
	for shelf in shelves:
		if shelf and is_instance_valid(shelf):
			shelf.books_on_shelf = 9
			shelf.max_books      = 9

func spawn_rare_books(count: int) -> void:
	## Summer Reading Challenge: spawn rare books at random floor positions.
	var shelves: Array = get_tree().get_nodes_in_group("shelves")
	if shelves.is_empty():
		return
	for _i in range(count):
		var shelf: Node = shelves[randi() % shelves.size()]
		var book: Node  = get_book_from_shelf("rare", shelf.global_position)
		if book:
			var offset: Vector2 = Vector2(randf_range(-80, 80), randf_range(-80, 80))
			book.is_rare = true
			book.place_on_floor(shelf.global_position + offset)
			notify_book_dropped(book)
			AudioManager.play_sfx("rare_book_spawn")

# ── Pool management ────────────────────────────────────────────────────────────
func _prewarm_pool() -> void:
	if not _book_scene_resource:
		push_error("BookManager: Book scene not found at " + BOOK_SCENE)
		return
	for _i in range(POOL_SIZE):
		var book: Node = _book_scene_resource.instantiate()
		_floor_books_node.add_child(book)
		book.hide()
		_pool.append(book)

func _get_pooled_book() -> Node:
	## Finds an available (shelved/hidden) book from the pool.
	## Grows pool if needed (emergency expansion).
	for book in _pool:
		if book.state == book.State.SHELVED and not book.visible:
			book.show()
			return book
	# Pool exhausted — grow it
	if _book_scene_resource:
		var book: Node = _book_scene_resource.instantiate()
		_floor_books_node.add_child(book)
		_pool.append(book)
		push_warning("BookManager: pool expanded to " + str(_pool.size()))
		return book
	return null

func _on_run_started() -> void:
	# Return all books to pool
	for book in _pool:
		if is_instance_valid(book):
			book.return_to_pool()
	_active_floor_books.clear()

func _on_run_ended(_won: bool) -> void:
	pass
