extends CharacterBody2D

const SPEED = 130.0
const JUMP_VELOCITY = -300.0
const DASH_SPEED = 300.0 # Dash velocity
const DASH_TIME = 0.2 # Duration of the dash

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

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
	
	# Add gravity if not dashing and not on floor
	if not is_on_floor() and not is_dashing:
		velocity.y += gravity * delta

	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Handle dash
	if Input.is_action_just_pressed("dash") and not is_dashing:
		print("test")
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
		animated_sprite.play("dash")
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
