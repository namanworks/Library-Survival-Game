# ObjectiveTracker.gd
# HUD element that displays up to 2 active objectives with timer and progress.
extends VBoxContainer

const MAX_OBJECTIVES := 2

# Entry template label refs (built dynamically)
var _entry_labels: Array = []

func _ready() -> void:
	add_to_group("objective_tracker")
	_build_entries()
	_connect_signals()
	# Hide all entries initially
	for entry in _entry_labels:
		entry["container"].visible = false

func _build_entries() -> void:
	for i in range(MAX_OBJECTIVES):
		var container := HBoxContainer.new()
		container.name = "Entry%d" % i

		var icon := Label.new()
		icon.name = "Icon"
		icon.text = "📋"
		icon.custom_minimum_size = Vector2(24, 0)
		container.add_child(icon)

		var vbox := VBoxContainer.new()
		vbox.name = "VBox"
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_child(vbox)

		var name_label := Label.new()
		name_label.name = "NameLabel"
		name_label.theme_override_font_sizes["font_size"] = 13
		name_label.theme_override_colors["font_color"] = Color(1.0, 0.95, 0.6)
		vbox.add_child(name_label)

		var progress_label := Label.new()
		progress_label.name = "ProgressLabel"
		progress_label.theme_override_font_sizes["font_size"] = 11
		progress_label.theme_override_colors["font_color"] = Color(0.8, 0.8, 0.85)
		vbox.add_child(progress_label)

		add_child(container)
		_entry_labels.append({
			"container": container,
			"name_label": name_label,
			"progress_label": progress_label,
			"objective_id": ""
		})

func _connect_signals() -> void:
	# ObjectiveSystem is registered as an autoload — connect directly
	if ObjectiveSystem:
		ObjectiveSystem.objective_added.connect(_on_objective_added)
		ObjectiveSystem.objective_updated.connect(_on_objective_updated)
		ObjectiveSystem.objective_completed.connect(_on_objective_removed)
		ObjectiveSystem.objective_expired.connect(_on_objective_removed)

func _on_objective_added(objective: Dictionary) -> void:
	for entry in _entry_labels:
		if entry["objective_id"] == "":
			entry["objective_id"] = objective["id"]
			entry["name_label"].text = objective.get("display_name", "")
			entry["progress_label"].text = _format_progress(objective, 0, objective.get("target_count", 1), objective.get("time_limit", -1.0))
			entry["container"].visible = true
			return

func _on_objective_updated(objective_id: String, current: int, target: int, time_left: float) -> void:
	for entry in _entry_labels:
		if entry["objective_id"] == objective_id:
			entry["progress_label"].text = _format_progress(null, current, target, time_left)
			return

func _on_objective_removed(objective_id: String, _extra = null) -> void:
	for entry in _entry_labels:
		if entry["objective_id"] == objective_id:
			entry["objective_id"] = ""
			entry["container"].visible = false
			return

func _format_progress(_obj, current: int, target: int, time_left: float) -> String:
	var s: String = "%d/%d" % [current, target]
	if time_left >= 0.0:
		var minutes: int = int(time_left / 60.0)
		var seconds: int = int(time_left) % 60
		s += "  [%02d:%02d]" % [minutes, seconds]
	return s
