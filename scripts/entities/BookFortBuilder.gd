# BookFortBuilder.gd
# Extends BaseChild. Removes multiple books per shelf visit and drops them ALL
# locally next to the shelf, creating a dense pile (cluster chaos bonus).
# Never carries books away.
extends "res://scripts/entities/BaseChild.gd"

func _ready() -> void:
	type_id = "book_fort_builder"
	super._ready()
	_build_fort_builder_sprite()

# ── Override: multi-book local drop, never carries ────────────────────────────
func _on_reach_shelf(shelf: Node) -> void:
	if not shelf or not is_instance_valid(shelf):
		_set_state(State.IDLE)
		return

	# Remove books_per_visit books (2–4 per JSON stats)
	for i in range(books_per_visit):
		if not shelf.remove_book():
			break  # shelf ran out
		var book: Node = BookManager.get_book_from_shelf(shelf.genre, global_position)
		if book:
			# Scatter books in a tight pile around shelf position
			var offset := Vector2(
				randf_range(-35.0, 35.0),
				randf_range(-35.0, 35.0)
			)
			book.place_on_floor(global_position + offset)
			BookManager.notify_book_dropped(book)

	_set_state(State.IDLE)
	idle_timer = randf_range(0.8, 2.0)

# ── Sprite ─────────────────────────────────────────────────────────────────────
func _build_fort_builder_sprite() -> void:
	_sprite.modulate = Color(0.85, 0.35, 0.15).lightened(0.2)
