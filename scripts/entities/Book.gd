# Book.gd
# A single book object. Uses an object pool — call reset() instead of free().
# State machine: SHELVED | ON_FLOOR | CARRIED
extends RigidBody2D

# ── Enums ──────────────────────────────────────────────────────────────────────
enum State { SHELVED, ON_FLOOR, CARRIED }

# ── Properties ─────────────────────────────────────────────────────────────────
@export var genre: String       = "fiction"
@export var is_rare: bool       = false
@export var chaos_weight: float = 1.0

var state: State                = State.SHELVED
var carried_by: Node            = null   # reference to child node carrying this book

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var _sprite: Sprite2D          = $Sprite2D
@onready var _highlight: Node2D         = $HighlightEffect
@onready var _collision: CollisionShape2D = $CollisionShape2D

# Placeholder sprite texture (generated programmatically for Phase 1)
var _placeholder_texture: ImageTexture

# ── Signals ────────────────────────────────────────────────────────────────────
signal state_changed(new_state: State)
signal picked_up(book: Node)
signal shelved(book: Node)
signal dropped(book: Node)

# ── Lifecycle ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	_apply_genre_color()
	gravity_scale = 0.0         # top-down — no gravity
	set_state(State.SHELVED)

# ── Public API ─────────────────────────────────────────────────────────────────
func reset(new_genre: String = "fiction", rare: bool = false) -> void:
	## Called by BookPool to reinitialize a recycled book.
	genre      = new_genre
	is_rare    = rare
	chaos_weight = 0.5 if rare else 1.0
	carried_by = null
	_apply_genre_color()
	set_state(State.SHELVED)
	show()

func set_state(new_state: State) -> void:
	state = new_state
	match state:
		State.SHELVED:
			_collision.set_deferred("disabled", true)
			freeze           = true
			_highlight.visible = false
			visible          = false   # shelved books are invisible (on shelf sprite handles it)

		State.ON_FLOOR:
			_collision.set_deferred("disabled", false)
			freeze           = false
			linear_velocity  = Vector2.ZERO
			angular_velocity = 0.0
			_highlight.visible = true
			visible          = true

		State.CARRIED:
			_collision.set_deferred("disabled", true)
			freeze           = true
			_highlight.visible = false
			visible          = true   # still visible in child's hands or belt

	state_changed.emit(new_state)

func place_on_floor(world_position: Vector2) -> void:
	global_position = world_position
	set_state(State.ON_FLOOR)
	dropped.emit(self)

func pick_up() -> void:
	set_state(State.CARRIED)
	picked_up.emit(self)

func shelve() -> void:
	set_state(State.SHELVED)
	shelved.emit(self)

func return_to_pool() -> void:
	## Hides and resets the book for pool reuse without freeing it.
	carried_by = null
	set_state(State.SHELVED)
	hide()

# ── Private ────────────────────────────────────────────────────────────────────
func _apply_genre_color() -> void:
	var color: Color
	if is_rare:
		color = Color(1.0, 0.84, 0.0)  # gold
	else:
		color = GameConstants.GENRE_COLORS.get(genre, Color.WHITE)
	_sprite.modulate = color
