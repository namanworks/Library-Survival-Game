# LibraryCat.gd
# Automation NPC. Wanders slowly around the library.
# Children within LIBRARY_CAT_RADIUS have their boldness reduced by 30%
# (making them more likely to flee the librarian).
extends CharacterBody2D

@onready var CAT_RADIUS: float         = GameConstants.LIBRARY_CAT_RADIUS
@onready var BOLDNESS_REDUCTION: float = GameConstants.LIBRARY_CAT_BOLDNESS_REDUCTION
const WANDER_SPEED: float       = 35.0

var _wander_timer: float = 0.0
var _wander_target: Vector2 = Vector2.ZERO
var _influence_update_timer: float = 0.0

@onready var _nav: NavigationAgent2D  = $NavigationAgent2D
@onready var _sprite: Sprite2D        = $Sprite2D
@onready var _influence_area: Area2D  = $InfluenceArea
var _influenced_children: Array       = []

func _ready() -> void:
	add_to_group("automation_npcs")
	_build_cat_sprite()
	_influence_area.body_entered.connect(_on_child_entered)
	_influence_area.body_exited.connect(_on_child_exited)
	GameManager.run_ended.connect(queue_free)

func _physics_process(delta: float) -> void:
	if not GameManager.is_running or get_tree().paused:
		return

	# Lazy wander
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(3.0, 7.0)
		_wander_target = Vector2(
			randf_range(120.0, 2280.0),
			randf_range(120.0, 1680.0)
		)
		_nav.target_position = _wander_target

	if not _nav.is_navigation_finished():
		var next: Vector2 = _nav.get_next_path_position()
		velocity = (next - global_position).normalized() * WANDER_SPEED
		move_and_slide()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, WANDER_SPEED * 4.0 * delta)
		move_and_slide()

	# Clean up invalid children
	_influence_update_timer -= delta
	if _influence_update_timer <= 0.0:
		_influence_update_timer = 0.5
		_influenced_children = _influenced_children.filter(func(c): return is_instance_valid(c))

func _on_child_entered(body: Node2D) -> void:
	if not body.is_in_group("children"):
		return
	if body.has_method("set_global_boldness_modifier"):
		# Reduce their boldness modifier by our amount (makes them more skittish)
		body.set_global_boldness_modifier(
			maxf(0.0, body._global_boldness_modifier - BOLDNESS_REDUCTION)
		)
	if not _influenced_children.has(body):
		_influenced_children.append(body)

func _on_child_exited(body: Node2D) -> void:
	if _influenced_children.has(body):
		_influenced_children.erase(body)
		if is_instance_valid(body) and body.has_method("set_global_boldness_modifier"):
			# Restore boldness — add our amount back
			body.set_global_boldness_modifier(
				minf(1.0, body._global_boldness_modifier + BOLDNESS_REDUCTION)
			)

func _exit_tree() -> void:
	# Restore all influenced children's boldness
	for child in _influenced_children:
		if is_instance_valid(child) and child.has_method("set_global_boldness_modifier"):
			child.set_global_boldness_modifier(
				minf(1.0, child._global_boldness_modifier + BOLDNESS_REDUCTION)
			)

func _build_cat_sprite() -> void:
	_sprite.modulate = Color(0.9, 0.5, 0.1).lightened(0.2)
