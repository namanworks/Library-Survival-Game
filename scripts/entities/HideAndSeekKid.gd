# HideAndSeekKid.gd
# Extends BaseChild. Uses a zigzag navigation path with random waypoints.
# Drops books at completely random walkable map positions.
extends "res://scripts/entities/BaseChild.gd"

# Waypoints for zigzag path
var _waypoints: Array = []
var _current_waypoint: int = 0

# Map bounds for random destination — mirrors Library.tscn map size
const MAP_MIN := Vector2(80.0, 80.0)
const MAP_MAX := Vector2(2320.0, 1720.0)

func _ready() -> void:
	type_id = "hide_and_seek_kid"
	super._ready()
	_build_hide_seek_sprite()

# ── Override: random map destination ──────────────────────────────────────────
func _get_carry_destination() -> Vector2:
	## Drop book at a random walkable point anywhere on the map.
	return Vector2(
		randf_range(MAP_MIN.x, MAP_MAX.x),
		randf_range(MAP_MIN.y, MAP_MAX.y)
	)

# ── Override: navigate via waypoints for zigzag effect ────────────────────────
func _handle_carrying(_delta: float) -> void:
	if carried_book and is_instance_valid(carried_book) and _carry_slot:
		carried_book.global_position = _carry_slot.global_position

	# On first call, build the zigzag waypoints
	if _waypoints.is_empty():
		_build_waypoints(drop_destination)
		_current_waypoint = 0

	if _current_waypoint < _waypoints.size():
		var target: Vector2 = _waypoints[_current_waypoint]
		_navigate_to(target)
		_move_along_nav_path()

		if global_position.distance_to(target) < 40.0:
			_current_waypoint += 1
	else:
		# Reached final waypoint
		_waypoints.clear()
		_set_state(State.DROPPING_BOOK)

func _build_waypoints(final_dest: Vector2) -> void:
	_waypoints.clear()
	# Insert 1–2 random intermediate points for zigzag
	var zigzag_count: int = randi_range(1, 2)
	for i in range(zigzag_count):
		var random_point := Vector2(
			randf_range(MAP_MIN.x, MAP_MAX.x),
			randf_range(MAP_MIN.y, MAP_MAX.y)
		)
		_waypoints.append(random_point)
	_waypoints.append(final_dest)

# ── Override: clear waypoints on state change ─────────────────────────────────
func _set_state(new_state: State) -> void:
	if new_state != State.CARRYING_BOOK:
		_waypoints.clear()
	super._set_state(new_state)

# ── Sprite ─────────────────────────────────────────────────────────────────────
func _build_hide_seek_sprite() -> void:
	_sprite.modulate = Color(0.55, 0.35, 0.80).lightened(0.2)
