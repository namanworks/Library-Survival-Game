# UpgradeManager.gd
# Singleton — manages the upgrade pool, active upgrades, and effect application.
# Applies stat modifier upgrades directly; spawns automation NPCs on unlock upgrades.
extends Node


# ── State ──────────────────────────────────────────────────────────────────────
var upgrade_pool: Array         = []  # all upgrades from upgrades.json
var active_upgrades: Dictionary = {}  # upgrade_id -> stack_count
var _automation_count: int      = 0

# ── Signals ────────────────────────────────────────────────────────────────────
signal upgrade_applied(upgrade_id: String)
signal pool_loaded()

func _ready() -> void:
	GameManager.run_started.connect(_on_run_started)
	GameManager.run_ended.connect(_on_run_ended)

# ── Public API ─────────────────────────────────────────────────────────────────
func load_pool() -> void:
	var file := FileAccess.open("res://data/upgrades.json", FileAccess.READ)
	if file == null:
		push_error("UpgradeManager: could not open upgrades.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("UpgradeManager: JSON parse error in upgrades.json")
		file.close()
		return
	file.close()
	upgrade_pool = json.get_data()
	pool_loaded.emit()

func get_random_upgrades(count: int) -> Array:
	## Returns `count` unique upgrade dicts, weighted by rarity and filtered by eligibility.
	var eligible: Array = _get_eligible_upgrades()
	if eligible.is_empty():
		return []

	var selected: Array = []
	var used_ids: Dictionary = {}

	# Weighted random selection
	for _i in range(count):
		var weighted: Array = []
		for upgrade in eligible:
			if upgrade.id in used_ids:
				continue
			var weight: int = 3 if upgrade.rarity == "common" else 1
			for _w in range(weight):
				weighted.append(upgrade)

		if weighted.is_empty():
			break
		var pick: Dictionary = weighted[randi() % weighted.size()]
		selected.append(pick)
		used_ids[pick.id] = true

	return selected

func apply_upgrade(upgrade_id: String) -> void:
	var upgrade: Dictionary = _find_upgrade(upgrade_id)
	if upgrade.is_empty():
		push_error("UpgradeManager: unknown upgrade id: " + upgrade_id)
		return

	# Increment stack count
	if upgrade_id in active_upgrades:
		active_upgrades[upgrade_id] += 1
	else:
		active_upgrades[upgrade_id] = 1

	# Track automation upgrades and spawn NPCs
	if upgrade.get("category", "") == "automation":
		_automation_count += 1
		_spawn_automation_npc(upgrade_id)

	upgrade_applied.emit(upgrade_id)
	# Stat application is handled by Librarian.gd listening to this signal

func has_upgrade(upgrade_id: String) -> bool:
	return upgrade_id in active_upgrades

func get_stack_count(upgrade_id: String) -> int:
	return active_upgrades.get(upgrade_id, 0)

func get_effect_value(upgrade_id: String) -> float:
	var upgrade: Dictionary = _find_upgrade(upgrade_id)
	if upgrade.is_empty():
		return 0.0
	var stacks: int = get_stack_count(upgrade_id)
	return upgrade.get("effect_value", 0.0) * stacks

func get_automation_count() -> int:
	return _automation_count

# ── Private ────────────────────────────────────────────────────────────────────
func _on_run_started() -> void:
	active_upgrades.clear()
	_automation_count = 0
	load_pool()

func _on_run_ended(_won: bool) -> void:
	pass  # Keep active upgrades for run summary display

func _get_eligible_upgrades() -> Array:
	var eligible: Array = []
	var current_level: int = GameManager.current_level

	for upgrade in upgrade_pool:
		var uid: String  = upgrade.get("id", "")
		var min_lvl: int = upgrade.get("min_level", 1)
		var max_stacks: int = upgrade.get("max_stacks", 1)
		var current_stacks: int = active_upgrades.get(uid, 0)

		# Filter: level gate
		if current_level < min_lvl:
			continue
		# Filter: maxed stacks
		if current_stacks >= max_stacks:
			continue
		# Filter: automation cap
		if upgrade.get("category", "") == "automation" and _automation_count >= GameConstants.MAX_AUTOMATION_UPGRADES:
			continue

		eligible.append(upgrade)

	return eligible

func _find_upgrade(upgrade_id: String) -> Dictionary:
	for upgrade in upgrade_pool:
		if upgrade.get("id", "") == upgrade_id:
			return upgrade
	return {}

# ── Automation NPC Spawning ────────────────────────────────────────────────────
const AUTOMATION_SCENES: Dictionary = {
	"assistant_librarian": "res://scenes/automation/AssistantLibrarian.tscn",
	"volunteer_student":   "res://scenes/automation/VolunteerStudent.tscn",
	"library_cat":         "res://scenes/automation/LibraryCat.tscn",
	"return_robot":        "res://scenes/automation/ReturnRobot.tscn",
}

func _spawn_automation_npc(upgrade_id: String) -> void:
	if not upgrade_id in AUTOMATION_SCENES:
		return
	var path: String = AUTOMATION_SCENES[upgrade_id]
	if not ResourceLoader.exists(path):
		return

	# Find the AutomationUnits container in the scene tree
	var container: Node = _find_automation_container()
	if not container:
		push_warning("UpgradeManager: AutomationUnits node not found — NPC not spawned")
		return

	var scene: PackedScene = load(path)
	var npc: Node = scene.instantiate()
	container.add_child(npc)

	# Spawn near the center of the map
	if npc is Node2D:
		npc.global_position = Vector2(1200.0, 900.0)

func _find_automation_container() -> Node:
	var candidates: Array = ["AutomationUnits", "automation_units"]
	for cand_name in candidates:
		var node: Node = _get_tree_node(cand_name)
		if node:
			return node
	return null

func _get_tree_node(node_name: String) -> Node:
	var root: Node = Engine.get_main_loop().root if Engine.get_main_loop() else null
	if root == null:
		return null
	return _find_node_recursive(root, node_name)

func _find_node_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var result: Node = _find_node_recursive(child, target_name)
		if result:
			return result
	return null
