# Inventory.gd
# Manages the librarian's carried book collection.
# Array-backed, signal-driven. Never access the array directly from outside.
extends Node

# ── State ──────────────────────────────────────────────────────────────────────
var _books: Array       = []          # Array of Book nodes
var capacity: int       = GameConstants.STARTING_INVENTORY

# ── Signals ────────────────────────────────────────────────────────────────────
signal book_added(book: Node)
signal book_removed(book: Node)
signal inventory_full()
signal inventory_changed(books: Array, capacity: int)

# ── Public API ─────────────────────────────────────────────────────────────────
func reset() -> void:
	_books.clear()
	capacity = GameConstants.STARTING_INVENTORY
	inventory_changed.emit(_books.duplicate(), capacity)

func try_add(book: Node) -> bool:
	## Returns true if book was added, false if inventory is full.
	if _books.size() >= capacity:
		inventory_full.emit()
		return false
	if _books.has(book):
		return false  # already in inventory
	_books.append(book)
	book_added.emit(book)
	inventory_changed.emit(_books.duplicate(), capacity)
	return true

func remove(book: Node) -> bool:
	## Returns true if the book was found and removed.
	var idx: int = _books.find(book)
	if idx == -1:
		return false
	_books.remove_at(idx)
	book_removed.emit(book)
	inventory_changed.emit(_books.duplicate(), capacity)
	return true

func remove_by_genre(genre: String) -> Array:
	## Removes and returns all books matching the given genre.
	var removed: Array = []
	for book in _books.duplicate():
		if book.genre == genre:
			_books.erase(book)
			removed.append(book)
	if not removed.is_empty():
		inventory_changed.emit(_books.duplicate(), capacity)
	return removed

func get_books_of_genre(genre: String) -> Array:
	var result: Array = []
	for book in _books:
		if book.genre == genre:
			result.append(book)
	return result

func is_full() -> bool:
	return _books.size() >= capacity

func is_empty() -> bool:
	return _books.is_empty()

func count() -> int:
	return _books.size()

func get_all_books() -> Array:
	return _books.duplicate()

func set_capacity(new_capacity: int) -> void:
	capacity = new_capacity
	inventory_changed.emit(_books.duplicate(), capacity)

func expand_capacity(amount: int) -> void:
	capacity += amount
	inventory_changed.emit(_books.duplicate(), capacity)
