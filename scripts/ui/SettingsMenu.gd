extends Control

@onready var master_slider = $CenterContainer/VBoxContainer/GridContainer/MasterSlider
@onready var music_slider = $CenterContainer/VBoxContainer/GridContainer/MusicSlider
@onready var sfx_slider = $CenterContainer/VBoxContainer/GridContainer/SFXSlider
@onready var shake_check = $CenterContainer/VBoxContainer/GridContainer2/ScreenShakeCheck
@onready var motion_check = $CenterContainer/VBoxContainer/GridContainer2/ReducedMotionCheck
@onready var colorblind_check = $CenterContainer/VBoxContainer/GridContainer2/ColorblindCheck
@onready var text_scale_slider = $CenterContainer/VBoxContainer/GridContainer2/TextScaleSlider

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Initialize UI with current settings
	var s = SettingsManager.settings
	master_slider.value = s["master_volume"]
	music_slider.value = s["music_volume"]
	sfx_slider.value = s["sfx_volume"]
	shake_check.button_pressed = s["screen_shake"]
	motion_check.button_pressed = s["reduced_motion"]
	colorblind_check.button_pressed = s["colorblind_mode"]
	text_scale_slider.value = s["text_scale"]

func _on_master_slider_value_changed(value: float) -> void:
	SettingsManager.set_setting("master_volume", value)

func _on_music_slider_value_changed(value: float) -> void:
	SettingsManager.set_setting("music_volume", value)

func _on_sfx_slider_value_changed(value: float) -> void:
	SettingsManager.set_setting("sfx_volume", value)

func _on_screen_shake_check_toggled(button_pressed: bool) -> void:
	SettingsManager.set_setting("screen_shake", button_pressed)

func _on_reduced_motion_check_toggled(button_pressed: bool) -> void:
	SettingsManager.set_setting("reduced_motion", button_pressed)

func _on_colorblind_check_toggled(button_pressed: bool) -> void:
	SettingsManager.set_setting("colorblind_mode", button_pressed)

func _on_text_scale_slider_value_changed(value: float) -> void:
	SettingsManager.set_setting("text_scale", value)

func _unpause_and_close() -> void:
	get_tree().paused = false
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Prevent HUD from immediately re-opening it
		get_viewport().set_input_as_handled()
		_unpause_and_close()

func _on_close_button_pressed() -> void:
	_unpause_and_close()
