# SugarRushKid.gd
# Extends BaseChild. Extreme speed, takes 1 book and drops it immediately next
# to the shelf, then immediately moves to the next shelf with almost no idle time.
extends "res://scripts/entities/BaseChild.gd"

func _ready() -> void:
	type_id = "sugar_rush_kid"
	super._ready()
	_build_sugar_rush_sprite()

# ── Override: always drops locally, minimal idle ──────────────────────────────
func _on_reach_shelf(shelf: Node) -> void:
	if not shelf or not is_instance_valid(shelf):
		_set_state(State.IDLE)
		return

	if not shelf.remove_book():
		_set_state(State.IDLE)
		idle_timer = 0.2
		return

	var book: Node = BookManager.get_book_from_shelf(shelf.genre, global_position)
	if book:
		# Always drops right where it stands — never carries
		var offset := Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))
		book.place_on_floor(global_position + offset)
		BookManager.notify_book_dropped(book)

	# Immediately go find next shelf — Sugar Rush never lingers
	_set_state(State.IDLE)
	idle_timer = randf_range(0.1, 0.3)

# ── Sprite ─────────────────────────────────────────────────────────────────────
func _build_sugar_rush_sprite() -> void:
	_sprite.modulate = Color(0.95, 0.25, 0.55).lightened(0.2)
