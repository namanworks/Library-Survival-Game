# Library.gd
# Procedurally builds the library layout at runtime for Phase 1.
# Sets up shelves, spawn points, navigation polygon, and zones.
# Replace with TileMap-based design in Phase 5 art pass.
extends Node2D

const BOOKSHELF_SCENE: String = "res://scenes/library/Bookshelf.tscn"
@onready var MAP_WIDTH:  int = GameConstants.MAP_WIDTH
@onready var MAP_HEIGHT: int = GameConstants.MAP_HEIGHT

# Shelf layout: [x_start, x_end, y, [genre1, genre2, genre3, genre4]]
const SHELF_LAYOUT: Array = [
	[1000, 1400, 750, ["fiction", "science", "history", "biography"]],
	[1000, 1400, 850, ["mystery", "reference", "children", "rare"]],
	[1000, 1400, 950, ["fiction", "science", "children", "rare"]],
]

# Spawn point positions (map edges)
const SPAWN_POSITIONS: Array = [
	Vector2(600,   50),  Vector2(1200,  50),  Vector2(1800,  50),
	Vector2(600, 1750),  Vector2(1200,1750),  Vector2(1800,1750),
	Vector2(50,   600),  Vector2(50,  1200),
	Vector2(2350, 600),  Vector2(2350,1200),
]

@onready var _shelves_node:      Node2D = $Shelves
@onready var _spawn_points_node: Node2D = $SpawnPoints
@onready var _nav_region:        NavigationRegion2D = $NavigationRegion2D
@onready var _bg_rect:           TextureRect = $BackgroundRect
@onready var _walls:             StaticBody2D = $Walls

var _bookshelf_scene: PackedScene

# ── Lifecycle ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	_bookshelf_scene = load(BOOKSHELF_SCENE)
	_setup_background()
	_setup_walls()
	_build_shelves()
	_build_spawn_points()
	_build_nav_polygon()
	_build_zones()

# ── Setup helpers ──────────────────────────────────────────────────────────────
func _setup_background() -> void:
	_bg_rect.size     = Vector2(MAP_WIDTH, MAP_HEIGHT)

func _setup_walls() -> void:
	## Create 4 wall segments as thin CollisionShape2D children of $Walls
	var thickness: int = 40
	var wall_data: Array = [
		# top
		[Vector2(MAP_WIDTH / 2.0, thickness / 2.0), Vector2(MAP_WIDTH, thickness)],
		# bottom
		[Vector2(MAP_WIDTH / 2.0, MAP_HEIGHT - thickness / 2.0), Vector2(MAP_WIDTH, thickness)],
		# left
		[Vector2(thickness / 2.0, MAP_HEIGHT / 2.0), Vector2(thickness, MAP_HEIGHT)],
		# right
		[Vector2(MAP_WIDTH - thickness / 2.0, MAP_HEIGHT / 2.0), Vector2(thickness, MAP_HEIGHT)],
	]
	for data in wall_data:
		var shape := RectangleShape2D.new()
		shape.size = data[1]
		var col := CollisionShape2D.new()
		col.shape = shape
		col.position = data[0]
		_walls.add_child(col)

func _build_shelves() -> void:
	for row in SHELF_LAYOUT:
		var x_start: int = row[0]
		var x_end:   int = row[1]
		var y:       int = row[2]
		var genres:  Array = row[3]
		var shelf_width: int = 80

		var x: int = x_start
		var idx: int = 0
		while x + shelf_width <= x_end and idx < genres.size():
			var shelf_inst: Node = _bookshelf_scene.instantiate()
			shelf_inst.genre = genres[idx]  # must be set before add_child so _ready() sees it
			_shelves_node.add_child(shelf_inst)
			shelf_inst.global_position = Vector2(x + shelf_width / 2.0, y)
			shelf_inst.add_to_group("shelves")
			x += shelf_width + 4  # small gap between shelf sections
			idx += 1

func _build_spawn_points() -> void:
	for pos in SPAWN_POSITIONS:
		var marker := Marker2D.new()
		marker.global_position = pos
		marker.add_to_group("spawn_points")
		_spawn_points_node.add_child(marker)

func _build_nav_polygon() -> void:
	## Creates a simple walkable polygon covering the map interior.
	## Complex nav mesh with shelf obstacles baked in editor during Phase 5.
	var nav_poly := NavigationPolygon.new()
	var border_margin: float = 45.0

	# Outer walkable boundary
	var outline := PackedVector2Array([
		Vector2(border_margin,             border_margin),
		Vector2(MAP_WIDTH - border_margin, border_margin),
		Vector2(MAP_WIDTH - border_margin, MAP_HEIGHT - border_margin),
		Vector2(border_margin,             MAP_HEIGHT - border_margin),
	])
	nav_poly.add_outline(outline)

	# Add shelf rows as nav obstacles (rectangles to cut from walkable area)
	for row in SHELF_LAYOUT:
		var x_start: int = row[0]
		var x_end:   int = row[1]
		var y:       int = row[2]
		var half_h: float = 22.0
		var hole := PackedVector2Array([
			Vector2(x_start,      y - half_h),
			Vector2(x_end,        y - half_h),
			Vector2(x_end,        y + half_h),
			Vector2(x_start,      y + half_h),
		])
		nav_poly.add_outline(hole)

	nav_poly.make_polygons_from_outlines()
	_nav_region.navigation_polygon = nav_poly

func _build_zones() -> void:
	## Creates named Area2D zones used by objectives and child AI destinations.
	var zone_data: Array = [
		["ReadingTables",    Rect2(200,  1100, 500, 500)],
		["StudyArea",        Rect2(1700, 200,  500, 500)],
		["ChildrensSection", Rect2(1700, 1100, 500, 500)],
	]
	var zones_node: Node2D = $Zones
	for zone_entry in zone_data:
		var zone_name: String = zone_entry[0]
		var rect: Rect2       = zone_entry[1]
		var zone := Area2D.new()
		zone.name = zone_name
		zone.add_to_group("zones")
		zone.add_to_group(zone_name.to_lower())
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var col := CollisionShape2D.new()
		col.shape = shape
		zone.add_child(col)
		zone.position = rect.get_center()
		zones_node.add_child(zone)
