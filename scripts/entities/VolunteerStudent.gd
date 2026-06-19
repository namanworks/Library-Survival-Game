# VolunteerStudent.gd
# Automation NPC. Follows the librarian at VOLUNTEER_FOLLOW_DISTANCE.
# Picks up floor books as they move alongside the player and holds them
# until the librarian shelves — at that point it deposits its carried books too.
extends CharacterBody2D

@onready var FOLLOW_SPEED: float   = GameConstants.BASE_MOVE_SPEED * 1.1
@onready var FOLLOW_DIST: float    = GameConstants.VOLUNTEER_FOLLOW_DISTANCE
@onready var INVENTORY_CAP: int    = GameConstants.VOLUNTEER_INVENTORY

var _books_held: Array       = []
var _librarian: Node         = null
var _pickup_check_timer: float = 0.0

@onready var _nav: NavigationAgent2D = $NavigationAgent2D
@onready var _sprite: Sprite2D       = $Sprite2D
@onready var _pickup_area: Area2D    = $PickupArea

func _ready() -> void:
	add_to_group("automation_npcs")
	_build_volunteer_sprite()
	_pickup_area.body_entered.connect(_on_pickup_area_entered)
	GameManager.run_ended.connect(queue_free)
	call_deferred("_find_librarian")

func _find_librarian() -> void:
	_librarian = get_tree().get_first_node_in_group("librarian")

func _physics_process(delta: float) -> void:
	if not GameManager.is_running or get_tree().paused:
		return
	if not _librarian or not is_instance_valid(_librarian):
		_find_librarian()
		return

	# Follow the librarian
	var dist: float = global_position.distance_to(_librarian.global_position)
	if dist > FOLLOW_DIST:
		_nav.target_position = _librarian.global_position
		if not _nav.is_navigation_finished():
			var next: Vector2 = _nav.get_next_path_position()
			velocity = (next - global_position).normalized() * FOLLOW_SPEED
		move_and_slide()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FOLLOW_SPEED * 4.0 * delta)
		move_and_slide()

	# Auto-shelve when near a shelf and holding books
	_pickup_check_timer -= delta
	if _pickup_check_timer <= 0.0:
		_pickup_check_timer = 1.0
		if not _books_held.is_empty():
			_try_shelve_nearby()

func _on_pickup_area_entered(body: Node2D) -> void:
	if not body.is_in_group("floor_books"):
		return
	if _books_held.size() >= INVENTORY_CAP:
		return
	if body.state != body.State.ON_FLOOR:
		return
	body.pick_up()
	BookManager.notify_book_picked_up(body)
	_books_held.append(body)
	AudioManager.play_sfx("book_pickup")

func _try_shelve_nearby() -> void:
	for shelf in get_tree().get_nodes_in_group("shelves"):
		if global_position.distance_to(shelf.global_position) < 80.0:
			for book in _books_held.duplicate():
				if shelf.genre == book.genre:
					shelf.return_books(1)
					GameManager.add_book_shelved()
					ChaosManager.reduce_chaos(GameConstants.CHAOS_REDUCTION_PER_BOOK)
					AudioManager.play_sfx("book_shelved")
					BookManager.return_book_to_pool(book)
					_books_held.erase(book)

func _build_volunteer_sprite() -> void:
	_sprite.modulate = Color(0.2, 0.6, 0.3).lightened(0.2)
