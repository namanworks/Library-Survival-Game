# CuriousChild.gd
# The basic child archetype. No stat overrides — purely base behavior.
# This IS the reference implementation. All other child types extend from here.
extends "res://scripts/entities/BaseChild.gd"

func _ready() -> void:
	type_id = "curious_child"
	super._ready()
	# Override placeholder sprite color to match type
	_set_type_color(Color(0.96, 0.78, 0.26))  # warm yellow

func _set_type_color(color: Color) -> void:
	# Tint the base pixel art sprite slightly to distinguish child types
	_sprite.modulate = color.lightened(0.2)
