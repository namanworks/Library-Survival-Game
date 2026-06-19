# TeenInfluencer.gd
# Extends BaseChild. On spawn creates a ChaosZone Area2D around itself that
# boosts chaos_passive_rate of nearby children by +0.3/sec.
# ChaosZone destroyed on interception or queue_free.
extends "res://scripts/entities/BaseChild.gd"

const CHAOS_ZONE_RADIUS    := 150.0
const CHAOS_PASSIVE_BONUS  := 0.3   # chaos/sec added to nearby children

var _chaos_zone: Area2D    = null
var _influenced_children: Array = []

func _ready() -> void:
	type_id = "teen_influencer"
	super._ready()
	_build_influencer_sprite()
	_spawn_chaos_zone()

func _exit_tree() -> void:
	_destroy_chaos_zone()

# ── Chaos Zone ─────────────────────────────────────────────────────────────────
func _spawn_chaos_zone() -> void:
	_chaos_zone = Area2D.new()
	_chaos_zone.name = "ChaosZone"
	_chaos_zone.collision_layer = 0
	_chaos_zone.collision_mask  = 8  # layer 4 = children physics layer

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = CHAOS_ZONE_RADIUS
	shape.shape = circle
	_chaos_zone.add_child(shape)

	add_child(_chaos_zone)

	_chaos_zone.body_entered.connect(_on_zone_body_entered)
	_chaos_zone.body_exited.connect(_on_zone_body_exited)

func _destroy_chaos_zone() -> void:
	# Remove passive bonus from any children still in range
	for child in _influenced_children:
		if is_instance_valid(child):
			child.chaos_passive_rate = maxf(0.0, child.chaos_passive_rate - CHAOS_PASSIVE_BONUS)
	_influenced_children.clear()

	if _chaos_zone and is_instance_valid(_chaos_zone):
		_chaos_zone.queue_free()
		_chaos_zone = null

func _on_zone_body_entered(body: Node2D) -> void:
	if body == self:
		return
	if body.is_in_group("children") and body.has_method("apply_slow"):
		# Reuse the chaos_passive_rate field to track the boost
		body.chaos_passive_rate += CHAOS_PASSIVE_BONUS
		if not _influenced_children.has(body):
			_influenced_children.append(body)

func _on_zone_body_exited(body: Node2D) -> void:
	if _influenced_children.has(body):
		_influenced_children.erase(body)
		if is_instance_valid(body):
			body.chaos_passive_rate = maxf(0.0, body.chaos_passive_rate - CHAOS_PASSIVE_BONUS)

# ── Override: destroy chaos zone on intercept ─────────────────────────────────
func on_librarian_touch(librarian: Node) -> void:
	_destroy_chaos_zone()
	super.on_librarian_touch(librarian)

# ── Sprite ─────────────────────────────────────────────────────────────────────
func _build_influencer_sprite() -> void:
	_sprite.modulate = Color(0.10, 0.10, 0.15).lightened(0.5)
