extends KinematicBody

signal page_on_pickup()

export var speed = 18
export var sprint_spd = 27
export var chase_spd = 33
export var accel = 40

export var hp = 3

var cam_accel = 40
var mouse_sens = 0.1
var snap

var stamina = 100
var stamina_rate = 0.5
var stamina_regen = false
var timer_started = false
var adrenaline = false
var sprinting = false

var direction = Vector3()
var movement = Vector3()

onready var head = $Head
onready var camera = $Head/Camera
onready var raycast = $Head/Camera/RayCast
onready var popup = $CanvasLayer/Control/Popup
onready var enemy = get_owner().get_node("Navigation").get_node("Enemy")
onready var stamina_bar = $CanvasLayer/Control/StaminaBar

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	enemy.connect("player_collide", self, "_on_enemy_player_collide")

func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(deg2rad(-event.relative.x * mouse_sens))
		head.rotate_x(deg2rad(-event.relative.y * mouse_sens))
		head.rotation.x = clamp(head.rotation.x, deg2rad(-89), deg2rad(89))

func _process(delta):
	if hp == 0:
		get_tree().reload_current_scene()
	elif hp > 3:
		hp = 3
	elif hp < 0:
		hp = 0
	# camera physics interpolation in the case that physics get jittery from high refresh-rate monitor
	if Engine.get_frames_per_second() > Engine.iterations_per_second:
		camera.set_as_toplevel(true)
		camera.global_transform.origin = camera.global_transform.origin.linear_interpolate(head.global_transform.origin, cam_accel * delta)
		camera.rotation.y = rotation.y
		camera.rotation.x = head.rotation.x
	else:
		camera.set_as_toplevel(false)
		camera.global_transform = head.global_transform
	# check if enemy is on patrol
	if enemy.current_state == enemy.STATE.PATROL:
		adrenaline = false
	# stamina code
	stamina_bar.value = stamina
	if stamina_regen:
		stamina += stamina_rate
	if stamina <= 0:
		stamina = 0
	elif stamina >= 100:
		stamina = 100
	if timer_started == false:
		if sprinting == false:
			$StaminaTimer.start()
			timer_started = true
	if sprinting:
		$StaminaTimer.stop()
		timer_started = false
		stamina_regen = false
		
func _physics_process(delta):
	direction = Vector3.ZERO

	var h_rot = global_transform.basis.get_euler().y
	var f_input = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	var h_input = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	# move the player, taking into account its rotation
	direction = Vector3(h_input, 0, f_input).rotated(Vector3.UP, h_rot).normalized()
	snap = get_floor_normal()
	# its move time!!
	if adrenaline:
		movement = Vector3().linear_interpolate(direction * chase_spd, accel * delta)
		sprinting = false
	elif Input.is_action_pressed("sprint") and stamina > 0:
		movement = Vector3().linear_interpolate(direction * sprint_spd, accel * delta)
		sprinting = true
		stamina -= stamina_rate
	else:
		movement = Vector3().linear_interpolate(direction * speed, accel * delta)
		sprinting = false
	move_and_slide_with_snap(movement, snap, Vector3.UP)
	if raycast.is_colliding():
		popup.visible = true
		page_pickup()
	else:
		popup.visible = false
	
func page_pickup():
	emit_signal("page_on_pickup")
	
func _on_enemy_player_collide():
	adrenaline = true
	hp -= 1
	$Hurt.play()

func _on_StaminaTimer_timeout():
	stamina_regen = true
	timer_started = false

func _on_HealthRegen_timeout():
	hp += 1