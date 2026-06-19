# Bookshelf.gd
# Represents a single shelf zone. Tracks book count, genre, and active state.
# Fires book_shelved when the librarian enters ReturnZone with matching books.
extends Area2D

# ── Exports ────────────────────────────────────────────────────────────────────
@export var genre: String       = "fiction"
@export var active: bool        = true
@export var books_on_shelf: int = 9
@export var max_books: int      = 9

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var _sprite: Sprite2D       = $Sprite2D
@onready var _label: Label           = $ShelfLabel
@onready var _return_zone: Area2D   = $ReturnZone

# ── Signals ────────────────────────────────────────────────────────────────────
signal book_shelved(genre: String)
signal book_removed_from_shelf(genre: String)
signal shelf_depleted(shelf: Area2D)

# ── Lifecycle ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	_label.text = genre.capitalize()
	_label.visible = OS.is_debug_build()  # only visible in debug
	_update_shelf_texture()
	_return_zone.body_entered.connect(_on_return_zone_body_entered)

# ── Public API ─────────────────────────────────────────────────────────────────
func activate() -> void:
	active = true
	_update_sprite()

func deactivate() -> void:
	active = false
	_update_sprite()

func remove_book() -> bool:
	## Called by a child when it takes a book. Returns false if empty.
	if books_on_shelf <= 0 or not active:
		return false
	books_on_shelf -= 1
	_update_sprite()
	book_removed_from_shelf.emit(genre)
	if books_on_shelf <= 0:
		shelf_depleted.emit(self)
	return true

func return_books(count: int) -> void:
	## Called internally when books are shelved. Increases books_on_shelf.
	books_on_shelf = mini(books_on_shelf + count, max_books)
	_update_sprite()

func has_books() -> bool:
	return books_on_shelf > 0 and active

# ── Private ────────────────────────────────────────────────────────────────────
func _on_return_zone_body_entered(body: Node2D) -> void:
	## Triggered when the librarian enters the ReturnZone.
	if not active:
		return
	if not body.is_in_group("librarian"):
		return

	var space: int = max_books - books_on_shelf
	if space <= 0:
		return  # Shelf is full

	var inventory: Node = body.get_node_or_null("Inventory")
	if inventory == null:
		return

	# Remove up to 'space' matching genre books from inventory
	var matching_books: Array = inventory.get_books_of_genre(genre)
	if matching_books.is_empty():
		return

	var to_shelve: int = mini(space, matching_books.size())
	for i in range(to_shelve):
		var book: Node = matching_books[i]
		inventory.remove(book)
		book.shelve()
		BookManager.return_book_to_pool(book)
		book_shelved.emit(genre)
		GameManager.add_book_shelved()
		ChaosManager.reduce_chaos(GameConstants.CHAOS_REDUCTION_PER_BOOK)
		AudioManager.play_sfx("book_shelved")
		if FXManager.has_method("spawn_particles"):
			FXManager.spawn_particles(global_position + Vector2(0, -10), GameConstants.GENRE_COLORS.get(genre, Color.WHITE))

	return_books(to_shelve)

func _update_shelf_texture() -> void:
	var color: Color = GameConstants.GENRE_COLORS.get(genre, Color(0.4, 0.25, 0.1))
	_sprite.modulate = color

func _update_sprite() -> void:
	if not active:
		_sprite.modulate = Color(0.3, 0.3, 0.3, 0.5)
	else:
		_update_shelf_texture()
