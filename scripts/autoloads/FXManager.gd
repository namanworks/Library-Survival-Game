extends Node

var shake_intensity: float = 0.0
var shake_decay: float = 5.0
var default_camera: Camera2D = null

func _ready() -> void:
	ChaosManager.chaos_changed.connect(_on_chaos_changed)
	EventManager.event_started.connect(_on_event_started)
	
	# Wait for first frame so camera is registered
	call_deferred("_find_camera")

func _process(delta: float) -> void:
	if shake_intensity > 0 and default_camera and is_instance_valid(default_camera):
		var s = SettingsManager.settings
		if s["screen_shake"] and not s["reduced_motion"]:
			var offset_x = randf_range(-1.0, 1.0) * shake_intensity
			var offset_y = randf_range(-1.0, 1.0) * shake_intensity
			default_camera.offset = Vector2(offset_x, offset_y)
		else:
			default_camera.offset = Vector2.ZERO
		
		shake_intensity = move_toward(shake_intensity, 0.0, shake_decay * delta)
		if shake_intensity == 0:
			default_camera.offset = Vector2.ZERO

func _find_camera() -> void:
	default_camera = get_viewport().get_camera_2d()

func add_shake(amount: float) -> void:
	shake_intensity = min(shake_intensity + amount, 30.0) # cap

func _on_chaos_changed(new_percent: float) -> void:
	# Small shake when crossing thresholds
	if int(new_percent) == int(GameConstants.CHAOS_THRESHOLD_DANGER):
		add_shake(10.0)
	elif int(new_percent) == int(GameConstants.CHAOS_THRESHOLD_WARN):
		add_shake(5.0)

func _on_event_started(event_data: Dictionary) -> void:
	if event_data.get("is_boss", false):
		add_shake(15.0)

# Particle system spawning
func spawn_particles(pos: Vector2, color: Color) -> void:
	if SettingsManager.settings["reduced_motion"]:
		return
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 10
	particles.explosiveness = 0.8
	particles.lifetime = 0.5
	particles.spread = 180.0
	particles.gravity = Vector2(0, 0)
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 100.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 6.0
	particles.color = color
	particles.position = pos
	
	# Autodestroy
	get_tree().create_timer(1.0).timeout.connect(func(): particles.queue_free())
	
	var main_scene = get_tree().current_scene
	if main_scene:
		main_scene.add_child(particles)
