extends CharacterBody2D

const SPEED = 130.0
const JUMP_VELOCITY = -300.0
const DASH_SPEED = 300.0 # Dash velocity
const DASH_TIME = 0.2 # Duration of the dash

const DOUBLE_JUMP_CONSISTANCY = 0.1 # lets the player prefor a double jump even if he is in the air for x seconds


var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var can_dash = true
var can_double_jump = true

var air_time = 0

@onready var animated_sprite = $AnimatedSprite2D

var is_dashing = false
var dash_timer = 0.0
var dash_direction = 0

func _physics_process(delta):
	# Update dash timer
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
	
	# keep track of air time to make double jumb more consistant
	if not is_on_floor():
		air_time += delta
	else:
		air_time = 0
	
	# Check if player has touched ground and update abilities acordingly
	if is_on_floor():
		can_dash = true
		can_double_jump = true
	
	# Add gravity if not dashing and not on floor
	if not is_on_floor() and not is_dashing:
		velocity.y += gravity * delta

	# Handle jump
	if Input.is_action_just_pressed("jump") and air_time < DOUBLE_JUMP_CONSISTANCY:
		velocity.y = JUMP_VELOCITY
		
	# Handle double jump
	
	if Input.is_action_just_pressed("jump") and can_double_jump and not is_on_floor() and air_time > DOUBLE_JUMP_CONSISTANCY:
		can_double_jump = false
		velocity.y = JUMP_VELOCITY

	# Handle dash
	if Input.is_action_just_pressed("dash") and not is_dashing and can_dash:
		can_dash = false
		start_dash()

	# Get input direction: -1, 0, 1
	var direction = Input.get_axis("move_left", "move_right")
	
	# Flip the sprite
	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true

	# Play animations
	if is_dashing:
		#animated_sprite.play("dash") # put dash animation here when we have one
		pass
	elif is_on_floor():
		if direction == 0:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("run")
	else:
		animated_sprite.play("jump")

	# Apply movement
	if is_dashing:
		velocity.x = dash_direction * DASH_SPEED
	else:
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func start_dash():
	is_dashing = true
	dash_timer = DASH_TIME
	dash_direction = Input.get_axis("move_left", "move_right")
	if dash_direction == 0:
		dash_direction = -1 if animated_sprite.flip_h else 1 # GDScript ternary operator
