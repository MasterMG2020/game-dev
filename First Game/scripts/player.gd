extends CharacterBody2D

const SPEED = 130.0
const JUMP_VELOCITY = -300.0
const DASH_SPEED = 300.0 # Dash velocity
const DASH_TIME = 0.2 # Duration of the dash

const WALL_SLIDE_SPEED = 50.0 # Speed of wall slide
const JUMP_AWAY_FROM_WALL_SPEED = 50


var wall_jump_boost_time = 0
var is_wall_sliding = false

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var can_dash = true

var jump_amount = 2 # number of jumps the player has
var is_wall_jump = false

# Movement parameters
const MAX_SPEED: float = 200.0        # Top speed
const ACCELERATION: float = 700.0   # Acceleration rate
const DECELERATION: float = 1300.0   # Deceleration rate



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

	
	# Check if player has touched ground and update abilities acordingly
	if is_on_floor():
		jump_amount = 2
		can_dash = true


	
	# Handle dash
	if Input.is_action_just_pressed("dash") and not is_dashing and can_dash:
		can_dash = false
		start_dash()
	
	wall_slide(delta)
	
	# Get input direction: -1, 0, 1
	var direction = Input.get_axis("move_left", "move_right")
	
	# Flip the sprite
	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true

	# Play animations
	play_animations(direction)
	
	# Add gravity if not dashing and not on floor
	if not is_on_floor() and not is_dashing:
		velocity.y += gravity * delta

	# Apply movement
	movement(direction, delta)
	
	# Handle jump
	if !is_dashing:
		jump()


	move_and_slide()



func jump():
	if Input.is_action_just_pressed("jump"):
		if jump_amount > 0:
			velocity.y = JUMP_VELOCITY
			jump_amount -= 1
		if is_on_wall() and Input.is_action_pressed("move_left"):
			velocity.y = JUMP_VELOCITY
			velocity.x = JUMP_AWAY_FROM_WALL_SPEED
		if is_on_wall() and Input.is_action_pressed("move_right"):
			velocity.y = JUMP_VELOCITY
			velocity.x = -JUMP_AWAY_FROM_WALL_SPEED


func start_dash():
	is_dashing = true
	dash_timer = DASH_TIME
	dash_direction = Input.get_axis("move_left", "move_right")
	if dash_direction == 0:
		dash_direction = -1 if animated_sprite.flip_h else 1 
		
func play_animations(direction):
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
		
func wall_slide(delta):
	if is_on_wall() and not is_on_floor():
		if Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
			is_wall_sliding = true
		else: 
			is_wall_sliding = false
	else:
		is_wall_sliding = false
		
	if is_wall_sliding:
		velocity.y += WALL_SLIDE_SPEED * delta
		velocity.y = min(velocity.y, WALL_SLIDE_SPEED)
		
		
func movement(direction: int, delta: float) -> void:
	if is_dashing:
		# Dash logic overrides velocity
		velocity.x = dash_direction * DASH_SPEED
	else:
		if direction != 0:
			# Accelerate towards the target speed
			var target_velocity = direction * MAX_SPEED
			velocity.x = move_toward(velocity.x, target_velocity, ACCELERATION * delta)
		else:
			# Decelerate smoothly to 0 when no input is provided
			velocity.x = move_toward(velocity.x, 0, DECELERATION * delta)
