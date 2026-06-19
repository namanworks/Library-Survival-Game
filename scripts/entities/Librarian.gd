# Librarian.gd
# The player character. Handles movement, pickup, shelving, XP, level-up,
# child interception, and applies upgrade effects.
# All gameplay is automatic except movement and active abilities (Q / E).
extends CharacterBody2D

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var _sprite: Sprite2D              = $Sprite2D
@onready var _anim: AnimationPlayer         = $AnimationPlayer
@onready var _pickup_radius: Area2D         = $PickupRadius
@onready var _pickup_collision: CollisionShape2D = $PickupRadius/CollisionShape2D
@onready var inventory: Node                = $Inventory

# ── Computed stats (base × upgrade multipliers) ─────────────────────────────────
var move_speed: float       = GameConstants.BASE_MOVE_SPEED
var pickup_radius: float    = GameConstants.PICKUP_RADIUS
var shelving_time: float    = GameConstants.SHELVING_TIME

# ── Active ability state ────────────────────────────────────────────────────────
var ability_1_cooldown: float = 0.0   # Story Time
var ability_2_cooldown: float = 0.0   # Parent Phone Call

# ── Upgrade effect flags ────────────────────────────────────────────────────────
var _has_stern_glare: bool       = false
var _has_shushing_aura: bool     = false
var _shush_timer: float          = 0.0
var _has_dewey_vacuum: bool      = false
var _has_book_lasso: bool        = false
var _lasso_timer: float          = 0.0
var _instant_reshelve_chance: float = 0.0

# ── Movement ───────────────────────────────────────────────────────────────────
var _input_direction: Vector2 = Vector2.ZERO

# ── Lifecycle ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("librarian")
	_setup_pickup_radius()

	# Connect signals
	_pickup_radius.area_entered.connect(_on_pickup_radius_area_entered)
	_pickup_radius.body_entered.connect(_on_pickup_radius_body_entered)
	if has_node("InterceptionArea"):
		$InterceptionArea.body_entered.connect(_on_child_body_entered)
	UpgradeManager.upgrade_applied.connect(_on_upgrade_applied)
	GameManager.run_started.connect(_on_run_started)
	GameManager.run_ended.connect(_on_run_ended)

func _physics_process(delta: float) -> void:
	if not GameManager.is_running or get_tree().paused:
		return

	_handle_movement(delta)
	_handle_abilities(delta)
	_handle_passive_upgrades(delta)

# ── Movement ───────────────────────────────────────────────────────────────────
func _handle_movement(delta: float) -> void:
	_input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if _input_direction != Vector2.ZERO:
		velocity = _input_direction.normalized() * move_speed
		_play_walk_animation(_input_direction)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * 8.0 * delta)
		_play_idle_animation()

	move_and_slide()

# ── Active abilities ────────────────────────────────────────────────────────────
func _handle_abilities(delta: float) -> void:
	if ability_1_cooldown > 0.0:
		ability_1_cooldown -= delta
	if ability_2_cooldown > 0.0:
		ability_2_cooldown -= delta

	# Ability 1 — Story Time (Q / LB)
	if Input.is_action_just_pressed("ability_1") and UpgradeManager.has_upgrade("story_time"):
		if ability_1_cooldown <= 0.0:
			_activate_story_time()

	# Ability 2 — Parent Phone Call (E / RB)
	if Input.is_action_just_pressed("ability_2") and UpgradeManager.has_upgrade("parent_phone_call"):
		if ability_2_cooldown <= 0.0:
			_activate_parent_call()

# ── Passive upgrade processing ─────────────────────────────────────────────────
func _handle_passive_upgrades(delta: float) -> void:
	# Shushing Aura pulse
	if _has_shushing_aura:
		_shush_timer -= delta
		if _shush_timer <= 0.0:
			_shush_timer = GameConstants.UPGRADE_SHUSHING_COOLDOWN
			_trigger_shush()

	# Book Lasso pull
	if _has_book_lasso:
		_lasso_timer -= delta
		if _lasso_timer <= 0.0:
			_lasso_timer = GameConstants.UPGRADE_BOOK_LASSO_INTERVAL
			_trigger_book_lasso()

	# Dewey Vacuum — attract nearby floor books
	if _has_dewey_vacuum:
		_attract_nearby_books(delta)

# ── Pickup ─────────────────────────────────────────────────────────────────────
func _on_pickup_radius_body_entered(body: Node2D) -> void:
	## Auto-pickup books that enter the pickup radius
	if body.is_in_group("floor_books"):
		_try_pick_up_book(body)

func _on_pickup_radius_area_entered(_area: Area2D) -> void:
	pass  # reserved for future use

func _try_pick_up_book(book: Node) -> void:
	if inventory.is_full():
		return
	if book.state != book.State.ON_FLOOR:
		return

	# Instant re-shelve chance (upgrade)
	if _instant_reshelve_chance > 0.0 and randf() < _instant_reshelve_chance:
		var matching_shelf := _find_nearest_shelf_for_genre(book.genre)
		if matching_shelf:
			book.shelve()
			BookManager.return_book_to_pool(book)
			matching_shelf.return_books(1)
			GameManager.add_book_shelved()
			ChaosManager.reduce_chaos(GameConstants.CHAOS_REDUCTION_PER_BOOK)
			AudioManager.play_sfx("book_shelved")
			return

	if inventory.try_add(book):
		book.pick_up()
		BookManager.notify_book_picked_up(book)
		ChaosManager.reduce_chaos(GameConstants.CHAOS_REDUCTION_PER_BOOK_PICKUP)
		AudioManager.play_sfx("book_pickup")
		if FXManager.has_method("spawn_particles"):
			FXManager.spawn_particles(book.global_position, GameConstants.GENRE_COLORS.get(book.genre, Color.WHITE))

# ── Child interception ─────────────────────────────────────────────────────────
func _on_child_body_entered(child_body: Node2D) -> void:
	## Called when librarian overlaps with a child carrying a book.
	## Set up in scene: Librarian has its own collision detection.
	if not child_body.is_in_group("children"):
		return
	if child_body.has_method("on_librarian_touch"):
		child_body.on_librarian_touch(self)

# ── Upgrade application ────────────────────────────────────────────────────────
func _on_upgrade_applied(_upgrade_id: String) -> void:
	_recalculate_stats()

func _recalculate_stats() -> void:
	## Recalculates all stats from base values × upgrade stacks.
	var speed_mult: float = 1.0
	speed_mult += UpgradeManager.get_stack_count("comfortable_shoes") * GameConstants.UPGRADE_COMFORTABLE_SHOES_SPEED
	speed_mult += UpgradeManager.get_stack_count("library_scooter") * GameConstants.UPGRADE_LIBRARY_SCOOTER_SPEED
	move_speed = GameConstants.BASE_MOVE_SPEED * speed_mult

	var radius_mult: float = 1.0
	radius_mult += UpgradeManager.get_stack_count("magnetic_bookmark") * GameConstants.UPGRADE_MAGNETIC_BOOKMARK_RADIUS
	pickup_radius = GameConstants.PICKUP_RADIUS * radius_mult
	_setup_pickup_radius()

	var shelve_mult: float = 1.0
	shelve_mult -= UpgradeManager.get_stack_count("lightning_shelver") * GameConstants.UPGRADE_LIGHTNING_SHELVER_TIME
	shelve_mult -= UpgradeManager.get_stack_count("auto_sorter") * 0.20
	shelving_time = maxf(0.05, GameConstants.SHELVING_TIME * shelve_mult)

	_has_stern_glare       = UpgradeManager.has_upgrade("stern_glare")
	_has_shushing_aura     = UpgradeManager.has_upgrade("shushing_aura")
	_has_dewey_vacuum      = UpgradeManager.has_upgrade("dewey_vacuum")
	_has_book_lasso        = UpgradeManager.has_upgrade("book_lasso")
	_instant_reshelve_chance = UpgradeManager.get_effect_value("instant_reshelving")

	if UpgradeManager.has_upgrade("staff_passages"):
		_unlock_shortcut_doors()

# ── Active Abilities ────────────────────────────────────────────────────────────
func _activate_story_time() -> void:
	ability_1_cooldown = GameConstants.UPGRADE_STORY_TIME_COOLDOWN
	AudioManager.play_sfx("story_time")
	# Gather nearby children — signal handled by child AI
	var children_in_range := _get_nearby_children(150.0)
	for child in children_in_range:
		if child.has_method("force_gather"):
			child.force_gather(global_position, GameConstants.UPGRADE_STORY_TIME_DURATION)

func _activate_parent_call() -> void:
	ability_2_cooldown = GameConstants.UPGRADE_PARENT_CALL_COOLDOWN
	AudioManager.play_sfx("parent_call")
	# Remove one random disruptive child
	var children := get_tree().get_nodes_in_group("children")
	if not children.is_empty():
		var target: Node = children[randi() % children.size()]
		target.queue_free()

# ── Passive Helpers ────────────────────────────────────────────────────────────
func _trigger_shush() -> void:
	AudioManager.play_sfx("shush")
	for child in _get_nearby_children(GameConstants.UPGRADE_STERN_GLARE_RADIUS * 1.5):
		if child.has_method("freeze_briefly"):
			child.freeze_briefly(GameConstants.UPGRADE_SHUSHING_FREEZE_DURATION)

func _trigger_book_lasso() -> void:
	for book in BookManager.get_floor_books_within(global_position, GameConstants.UPGRADE_BOOK_LASSO_RADIUS):
		if book.state == book.State.ON_FLOOR and not inventory.is_full():
			_try_pick_up_book(book)

func _attract_nearby_books(delta: float) -> void:
	var speed: float = GameConstants.UPGRADE_DEWEY_VACUUM_STRENGTH
	for book in BookManager.get_floor_books_within(global_position, GameConstants.UPGRADE_DEWEY_VACUUM_RADIUS):
		if book.state == book.State.ON_FLOOR:
			var dir: Vector2 = (global_position - book.global_position).normalized()
			book.global_position += dir * speed * delta

func _get_nearby_children(radius: float) -> Array:
	var result: Array = []
	for child in get_tree().get_nodes_in_group("children"):
		if is_instance_valid(child) and global_position.distance_to(child.global_position) <= radius:
			result.append(child)
	return result

func _find_nearest_shelf_for_genre(book_genre: String) -> Node:
	var nearest: Node = null
	var nearest_dist: float = INF
	for shelf in get_tree().get_nodes_in_group("shelves"):
		if shelf.genre == book_genre and shelf.active:
			var d: float = global_position.distance_to(shelf.global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest = shelf
	return nearest

func _unlock_shortcut_doors() -> void:
	for door in get_tree().get_nodes_in_group("shortcut_doors"):
		if door.has_method("unlock"):
			door.unlock()
			AudioManager.play_sfx("shortcut_door")

# ── Stern Glare aura ────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if not _has_stern_glare or not GameManager.is_running:
		return
	for child in get_tree().get_nodes_in_group("children"):
		if not is_instance_valid(child):
			continue
		var dist: float = global_position.distance_to(child.global_position)
		if dist <= GameConstants.UPGRADE_STERN_GLARE_RADIUS:
			if child.has_method("apply_slow"):
				child.apply_slow(GameConstants.UPGRADE_STERN_GLARE_SLOW)
		else:
			if child.has_method("remove_slow"):
				child.remove_slow()

# ── Run events ─────────────────────────────────────────────────────────────────
func _on_run_started() -> void:
	inventory.reset()
	move_speed     = GameConstants.BASE_MOVE_SPEED
	pickup_radius  = GameConstants.PICKUP_RADIUS
	shelving_time  = GameConstants.SHELVING_TIME
	ability_1_cooldown = 0.0
	ability_2_cooldown = 0.0
	_shush_timer   = 0.0
	_lasso_timer   = 0.0

func _on_run_ended(_won: bool) -> void:
	velocity = Vector2.ZERO

# ── Setup helpers ───────────────────────────────────────────────────────────────
func _setup_pickup_radius() -> void:
	var shape: CircleShape2D = _pickup_collision.shape as CircleShape2D
	if shape:
		shape.radius = pickup_radius

# ── Animation helpers ───────────────────────────────────────────────────────────
func _play_walk_animation(direction: Vector2) -> void:
	if _anim.has_animation("walk"):
		if not _anim.is_playing() or _anim.current_animation != "walk":
			_anim.play("walk")
	# Flip sprite on horizontal movement (Phase 5: replace with directional anims)
	if direction.x < 0:
		_sprite.flip_h = true
	elif direction.x > 0:
		_sprite.flip_h = false

func _play_idle_animation() -> void:
	if _anim.has_animation("idle"):
		if not _anim.is_playing() or _anim.current_animation != "idle":
			_anim.play("idle")
