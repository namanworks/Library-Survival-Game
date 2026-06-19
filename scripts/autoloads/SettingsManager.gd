extends Node

signal settings_changed

const CONFIG_PATH = "user://settings.cfg"

var settings: Dictionary = {
	"master_volume": 1.0,
	"music_volume": 1.0,
	"sfx_volume": 1.0,
	"screen_shake": true,
	"reduced_motion": false,
	"colorblind_mode": false,
	"text_scale": 1.0
}

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	if err == OK:
		for key in settings.keys():
			if config.has_section_key("Settings", key):
				settings[key] = config.get_value("Settings", key)
	apply_settings()

func save_settings() -> void:
	var config = ConfigFile.new()
	for key in settings.keys():
		config.set_value("Settings", key, settings[key])
	config.save(CONFIG_PATH)
	apply_settings()

func set_setting(key: String, value: Variant) -> void:
	if settings.has(key):
		settings[key] = value
		save_settings()

func apply_settings() -> void:
	settings_changed.emit()
	
	# Apply audio volumes
	# Convert linear [0, 1] to db [-80, 0]
	var master_db = linear_to_db(settings["master_volume"]) if settings["master_volume"] > 0 else -80
	var music_db = linear_to_db(settings["music_volume"]) if settings["music_volume"] > 0 else -80
	var sfx_db = linear_to_db(settings["sfx_volume"]) if settings["sfx_volume"] > 0 else -80
	
	var master_bus = AudioServer.get_bus_index("Master")
	if master_bus != -1:
		AudioServer.set_bus_volume_db(master_bus, master_db)
	
	var music_bus = AudioServer.get_bus_index("Music")
	if music_bus != -1:
		AudioServer.set_bus_volume_db(music_bus, music_db)
		
	var sfx_bus = AudioServer.get_bus_index("SFX")
	if sfx_bus != -1:
		AudioServer.set_bus_volume_db(sfx_bus, sfx_db)
