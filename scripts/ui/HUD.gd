# HUD.gd
# Drives all in-game HUD elements. Reads from GameManager and ChaosManager signals.
# Never polls state — only reacts to signals.
extends CanvasLayer

# ── Node refs ──────────────────────────────────────────────────────────────────
@onready var _chaos_bar: ProgressBar  = $ChaosBar/FillBar
@onready var _chaos_label: Label      = $ChaosBar/ChaosLabel
@onready var _chaos_bg: TextureRect   = $ChaosBar/Background
@onready var _timer_label: Label      = $TimerDisplay
@onready var _xp_bar: ProgressBar     = $XPBar/FillBar
@onready var _level_label: Label      = $XPBar/LevelLabel
@onready var _inventory_belt: HBoxContainer = $InventoryBelt
@onready var _event_banner: Control   = $EventBanner
@onready var _banner_label: Label     = $EventBanner/BannerLabel
@onready var _objective_tracker: VBoxContainer = $ObjectiveTracker

# Inventory slot nodes (built programmatically to match capacity)
var _inv_slots: Array = []

# Color palette for chaos states
const COLOR_SAFE:     Color = Color(0.20, 0.78, 0.35)  # green
const COLOR_WARNING:  Color = Color(0.95, 0.80, 0.10)  # yellow
const COLOR_DANGER:   Color = Color(0.95, 0.50, 0.10)  # orange
const COLOR_CRITICAL: Color = Color(0.90, 0.15, 0.15)  # red

var _banner_tween: Tween = null
var _pulse_tween: Tween  = null

# ── Lifecycle ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Wire to game signals
	ChaosManager.chaos_changed.connect(_on_chaos_changed)
	GameManager.run_time_updated.connect(_on_run_time_updated)
	GameManager.xp_changed.connect(_on_xp_changed)
	GameManager.run_started.connect(_on_run_started)
	GameManager.run_ended.connect(_on_run_ended)
	EventManager.event_started.connect(_on_event_started)
	EventManager.event_warning.connect(_on_event_warning)

	# Wire inventory (after librarian is ready)
	call_deferred("_connect_inventory")

	_hide_banner()
	_refresh_chaos_bar(0.0)
	_refresh_xp_bar(0, 1)
	_refresh_timer("00:00")
	
	SettingsManager.settings_changed.connect(_apply_settings)
	_apply_settings()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if not has_node("SettingsMenu"):
			var settings_scene = load("res://scripts/ui/SettingsMenu.tscn")
			if settings_scene:
				var settings_menu = settings_scene.instantiate()
				settings_menu.name = "SettingsMenu"
				add_child(settings_menu)
				get_tree().paused = true

func _apply_settings() -> void:
	var s = SettingsManager.settings
	var scale_factor: float = s["text_scale"]
	_chaos_label.add_theme_font_size_override("font_size", int(24 * scale_factor))
	_timer_label.add_theme_font_size_override("font_size", int(32 * scale_factor))
	_level_label.add_theme_font_size_override("font_size", int(24 * scale_factor))
	_banner_label.add_theme_font_size_override("font_size", int(48 * scale_factor))
	_on_chaos_changed(_chaos_bar.value) # re-trigger chaos color update


# ── Signal handlers ────────────────────────────────────────────────────────────
func _on_chaos_changed(new_percent: float) -> void:
	_refresh_chaos_bar(new_percent)

func _on_run_time_updated(time_string: String) -> void:
	_refresh_timer(time_string)

func _on_xp_changed(new_xp: int, new_level: int) -> void:
	_refresh_xp_bar(new_xp, new_level)

func _on_run_started() -> void:
	_refresh_chaos_bar(0.0)
	_refresh_xp_bar(0, 1)
	_refresh_timer("00:00")
	_rebuild_inventory_slots()

func _on_run_ended(_won: bool) -> void:
	pass

func _on_event_started(event_data: Dictionary) -> void:
	var text: String = event_data.get("banner_text", "")
	if not text.is_empty():
		_show_banner(text, event_data.get("is_boss", false))

func _on_event_warning(event_data: Dictionary) -> void:
	var text: String = event_data.get("banner_text", "")
	if not text.is_empty():
		_show_banner("⚠ " + text, false)

# ── UI Refresh helpers ─────────────────────────────────────────────────────────
func _refresh_chaos_bar(chaos_percent: float) -> void:
	_chaos_bar.value = chaos_percent
	_chaos_label.text = "CHAOS  %d%%" % int(chaos_percent)

	var color: Color
	var is_cb = SettingsManager.settings["colorblind_mode"]
	if chaos_percent >= GameConstants.CHAOS_THRESHOLD_DANGER:
		color = Color(0.1, 0.5, 0.9) if is_cb else COLOR_CRITICAL
		_start_pulse()
	elif chaos_percent >= GameConstants.CHAOS_THRESHOLD_WARN:
		color = Color(0.9, 0.6, 0.1) if is_cb else COLOR_DANGER
		_stop_pulse()
	elif chaos_percent >= GameConstants.CHAOS_THRESHOLD_SAFE:
		color = Color(0.8, 0.8, 0.1) if is_cb else COLOR_WARNING
		_stop_pulse()
	else:
		color = Color(0.2, 0.8, 0.8) if is_cb else COLOR_SAFE
		_stop_pulse()

	_chaos_bar.modulate = color
	_chaos_label.modulate = color

func _refresh_timer(time_string: String) -> void:
	_timer_label.text = time_string

func _refresh_xp_bar(current_xp: int, level: int) -> void:
	_level_label.text = "LVL %d" % level
	var progress: float = GameManager.get_xp_progress()
	_xp_bar.value = progress * 100.0

# ── Inventory belt ─────────────────────────────────────────────────────────────
func _rebuild_inventory_slots() -> void:
	for slot in _inv_slots:
		slot.queue_free()
	_inv_slots.clear()

	var capacity: int = GameConstants.STARTING_INVENTORY
	for i in range(capacity):
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(44, 44)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.10, 0.08, 0.85)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.75, 0.65, 0.45, 1.0)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		slot.add_theme_stylebox_override("panel", style)
		_inventory_belt.add_child(slot)
		_inv_slots.append(slot)

func _refresh_inventory(books: Array, capacity: int) -> void:
	# Rebuild if capacity changed
	if _inv_slots.size() != capacity:
		_rebuild_inventory_slots()

	for i in range(_inv_slots.size()):
		var slot: Panel = _inv_slots[i]
		var style: StyleBoxFlat = slot.get_theme_stylebox("panel")
		if i < books.size():
			var genre: String = books[i].genre
			style.bg_color = GameConstants.GENRE_COLORS.get(genre, Color.WHITE)
		else:
			style.bg_color = Color(0.1, 0.1, 0.1, 0.5)

func _connect_inventory() -> void:
	var librarian: Node = get_tree().get_first_node_in_group("librarian")
	if librarian and librarian.has_node("Inventory"):
		var inventory: Node = librarian.get_node("Inventory")
		inventory.inventory_changed.connect(_refresh_inventory)

# ── Event Banner ───────────────────────────────────────────────────────────────
func _show_banner(text: String, is_boss: bool) -> void:
	_banner_label.text = text
	_event_banner.modulate = Color(0.9, 0.2, 0.2) if is_boss else Color(0.2, 0.6, 0.9)
	_event_banner.visible = true

	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_event_banner, "modulate:a", 1.0, 0.2)
	_banner_tween.tween_interval(2.5)
	_banner_tween.tween_property(_event_banner, "modulate:a", 0.0, 0.5)
	_banner_tween.tween_callback(_hide_banner)

func _hide_banner() -> void:
	_event_banner.visible = false

# ── Chaos pulse animation ──────────────────────────────────────────────────────
func _start_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_running():
		return
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_chaos_bar, "modulate:a", 0.5, 0.4)
	_pulse_tween.tween_property(_chaos_bar, "modulate:a", 1.0, 0.4)

func _stop_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	_chaos_bar.modulate.a = 1.0
