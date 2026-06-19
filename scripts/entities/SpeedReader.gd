# SpeedReader.gd
# Extends BaseChild. Moves fast, highly likely to carry books far away.
# Prefers the most distant available drop zone on the map.
extends "res://scripts/entities/BaseChild.gd"

func _ready() -> void:
	type_id = "speed_reader"
	super._ready()
	_build_speed_reader_sprite()

# ── Override: carry destination prefers far zones ──────────────────────────────
func _get_carry_destination() -> Vector2:
	## Speed Reader targets the farthest walkable zone from its current position.
	var zones: Array = []
	for area in get_tree().get_nodes_in_group("zones"):
		zones.append(area.global_position)

	# Fallback: random far point
	if zones.is_empty():
		var angle: float = randf() * TAU
		return global_position + Vector2(cos(angle), sin(angle)) * carry_distance_max

	# Pick the zone farthest from current position
	var farthest: Vector2 = zones[0]
	var farthest_dist: float = 0.0
	for zone_pos in zones:
		var d: float = global_position.distance_to(zone_pos)
		if d > farthest_dist:
			farthest_dist = d
			farthest = zone_pos
	return farthest

# ── Sprite ─────────────────────────────────────────────────────────────────────
func _build_speed_reader_sprite() -> void:
	_sprite.modulate = Color(0.20, 0.80, 0.95).lightened(0.2)
