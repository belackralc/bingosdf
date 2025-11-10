extends Control

var scene_to_load = "res://MainMenu.tscn"

# --- REMOVED: ProgressBar reference ---
@onready var timer: Timer = $Timer
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var load_status = null
var is_load_finished = false
var is_timer_finished = false
var is_fading_out = false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	
	ResourceLoader.load_threaded_request(scene_to_load)
	load_status = ResourceLoader.load_threaded_get_status(scene_to_load)
	timer.timeout.connect(_on_timer_timeout)
	animation_player.animation_finished.connect(_on_animation_finished)


func _process(_delta):
	# We only want to check the load status if we aren't
	# already finished loading or fading out.
	if is_load_finished or is_fading_out:
		return 

	if load_status == null:
		return

	load_status = ResourceLoader.load_threaded_get_status(scene_to_load)

	match load_status:
		ResourceLoader.THREAD_LOAD_LOADED:
			is_load_finished = true
			call_deferred("_check_if_done")
			
		ResourceLoader.THREAD_LOAD_FAILED:
			print("ERROR: Failed to load Main Menu scene!")
			is_load_finished = true
			call_deferred("_check_if_done")
		
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			pass # We just wait patiently


func _on_timer_timeout():
	is_timer_finished = true
	call_deferred("_check_if_done")


func _check_if_done():
	# This function is now the only one that can change scenes.
	# It will only run if BOTH conditions are true AND we aren't
	# already fading out.
	if is_fading_out or not is_load_finished or not is_timer_finished:
		return

	# We are ready! Start the fade out.
	is_fading_out = true
	animation_player.play("fade_out")


# This new function is called *after* any animation finishes.
func _on_animation_finished(anim_name):
	# We only care if the "fade_out" animation finished.
	if anim_name == "fade_out":
		# NOW we can safely change the scene.
		var loaded_scene = ResourceLoader.load_threaded_get(scene_to_load)
		get_tree().paused = false
		get_tree().change_scene_to_packed(loaded_scene)
