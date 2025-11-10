extends CharacterBody3D

# --- Player Detection ---
var player = null

# --- Navigation ---
@onready var nav_agent = $NavigationAgent3D

# --- Stats ---
@export var health = 100
const MAX_HEALTH = 100
# --- NEW: Health Bar Visible Flag ---
var health_bar_visible = false

# --- State Machine ---
var state = 0 # 0 = IDLE, 1 = CHASING

# --- Damage Cooldown ---
@onready var damage_cooldown_timer = $DamageCooldownTimer
var player_in_damage_zone = false

# --- Signals ---
signal monster_died
signal monster_health_changed(current_health, max_health)
signal monster_spotted(current_health, max_health)
signal monster_lost()

# --- Visuals ---
@onready var visual_mesh = $MonsterMesh
@onready var flash_timer = $FlashTimer
var original_material: StandardMaterial3D


func _ready():
	print("[MR. FERRIN] _ready()")
	
	if visual_mesh:
		original_material = visual_mesh.get_active_material(0)
	else:
		print("ERROR: Could not find 'MonsterMesh' node. Flashing effect will not work.")

	
	if not flash_timer.is_connected("timeout", Callable(self, "_on_flash_timer_timeout")):
		flash_timer.connect("timeout", Callable(self, "_on_flash_timer_timeout"))

	var detection_zone = $DetectionZone
	if not detection_zone.is_connected("body_entered", Callable(self, "_on_detection_zone_body_entered")):
		detection_zone.connect("body_entered", Callable(self, "_on_detection_zone_body_entered"))
		
	if not detection_zone.is_connected("body_exited", Callable(self, "_on_detection_zone_body_exited")):
		detection_zone.connect("body_exited", Callable(self, "_on_detection_zone_body_exited"))

	var damage_zone = $DamageZone
	if not damage_zone.is_connected("body_entered", Callable(self, "_on_damage_zone_body_entered")):
		damage_zone.connect("body_entered", Callable(self, "_on_damage_zone_body_entered"))

	if not damage_zone.is_connected("body_exited", Callable(self, "_on_damage_zone_body_exited")):
		damage_zone.connect("body_exited", Callable(self, "_on_damage_zone_body_exited"))
		
	if not damage_cooldown_timer.is_connected("timeout", Callable(self, "_on_damage_cooldown_timer_timeout")):
		damage_cooldown_timer.connect("timeout", Callable(self, "_on_damage_cooldown_timer_timeout"))

	if not monster_died.is_connected(GameState._on_monster_died):
		monster_died.connect(GameState._on_monster_died)
		
	if not monster_health_changed.is_connected(GameState._on_monster_health_changed):
		monster_health_changed.connect(GameState._on_monster_health_changed)

	if not monster_spotted.is_connected(GameState._on_monster_spotted):
		monster_spotted.connect(GameState._on_monster_spotted)
		
	if not monster_lost.is_connected(GameState._on_monster_lost):
		monster_lost.connect(GameState._on_monster_lost)


func _physics_process(_delta):
	
	if health <= 0:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	match state:
		0: # IDLE
			velocity = Vector3.ZERO
			
		1: # CHASING
			if is_instance_valid(player):
				nav_agent.set_target_position(player.global_position)
				
				var next_path_pos = nav_agent.get_next_path_position()
				var direction = (next_path_pos - global_position).normalized()
				
				velocity = direction * 3.0
				
				# --- THIS IS THE NEW CODE ---
				# 1. Get the player's position
				var target_pos = player.global_position
				
				# 2. Set the 'y' (height) to be the same as our 'y'.
				#    This stops Mr. Ferrin from tilting up and down.
				target_pos.y = global_position.y
				
				# 3. Make our entire body look at that flat target position.
				look_at(target_pos, Vector3.UP)
				# --- END NEW CODE ---
				
			else:
				state = 0
				player = null
				# Only hide the bar if it was visible
				if health_bar_visible:
					health_bar_visible = false
					emit_signal("monster_lost")
				
	move_and_slide()
	
	if player_in_damage_zone and damage_cooldown_timer.is_stopped():
		damage_cooldown_timer.start()


func take_damage(amount):
	if health <= 0:
		return
		
	if not is_instance_valid(visual_mesh):
		print("ERROR: 'visual_mesh' node not found, can't flash red.")
		return

	print("[MR. FERRIN] Took damage, new health: %s" % (health - amount))
	health -= amount
	
	# --- SHOW HEALTH ON HIT (Moved here) ---
	# Only emit this signal *once*
	if not health_bar_visible:
		health_bar_visible = true
		emit_signal("monster_spotted", health, MAX_HEALTH)
	
	emit_signal("monster_health_changed", health, MAX_HEALTH)

	if health <= 0:
		print("[MR. FERRIN] Died!")
		emit_signal("monster_died")
		if health_bar_visible: # Hide the bar on death
			emit_signal("monster_lost")
		
		visual_mesh.material_override = null
		queue_free()
	else:
		var flash_material = original_material.duplicate()
		flash_material.albedo_color = Color.RED
		visual_mesh.material_override = flash_material
		flash_timer.start()


# --- Signal Callbacks ---
func _on_detection_zone_body_entered(body):
	if body.is_in_group("player"):
		print("[MR. FERRIN] Player entered zone.")
		player = body
		state = 1
		# --- (We no longer show the health bar here) ---

func _on_detection_zone_body_exited(body):
	if body.is_in_group("player"):
		print("[MR. FERRIN] Player exited zone.")
		player = null
		state = 0
		
		# Only hide the bar if it was visible
		if health_bar_visible:
			health_bar_visible = false
			emit_signal("monster_lost")

func _on_damage_zone_body_entered(body):
	if body.is_in_group("player"):
		player_in_damage_zone = true

func _on_damage_zone_body_exited(body):
	if body.is_in_group("player"):
		player_in_damage_zone = false
		damage_cooldown_timer.stop()

func _on_damage_cooldown_timer_timeout():
	if player_in_damage_zone:
		print("[MR. FERRIN] Dealing damage to player")
		GameState.take_damage(25)
	
	if not player_in_damage_zone:
		damage_cooldown_timer.stop()

func _on_flash_timer_timeout():
	if is_instance_valid(visual_mesh):
		visual_mesh.material_override = null
