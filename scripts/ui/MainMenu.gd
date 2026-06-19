extends Control

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Focus play button for keyboard/controller support
	play_button.grab_focus()

func _on_play_pressed() -> void:
	AudioManager.play_sfx("book_pickup") # simple beep
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

func _on_settings_pressed() -> void:
	AudioManager.play_sfx("upgrade_select")
	var settings_scene = load("res://scripts/ui/SettingsMenu.tscn")
	if settings_scene:
		var settings_menu = settings_scene.instantiate()
		settings_menu.name = "SettingsMenu"
		add_child(settings_menu)
		# It's an overlay, it will handle its own closing

func _on_quit_pressed() -> void:
	AudioManager.play_sfx("book_dropped")
	get_tree().quit()
