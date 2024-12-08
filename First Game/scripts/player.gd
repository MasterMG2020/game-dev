extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var collisionShape = $CollisionShape2D
@onready var collisionShapeCrouched = $CollisionShape2D_crouched

# Basic movement parameters
const MAX_SPEED: float = 170.0        # Top speed
const ACCELERATION: float = 700.0   # Acceleration rate
const DECELERATION: float = 1700.0   # Deceleration rate

# Advanced movement parameters
const JUMP_VELOCITY: float = -300.0
const JUMP_AMOUNT: int = 2 # number of jumps the player has
const DASH_SPEED: float = 400.0 # Dash velocity
const DASH_TIME: float = 0.2 # Duration of the dash
const MAX_SPEED_CROUCHED: float = 80.0 # speed while crouched

# Wall slide parameters
const WALL_SLIDE_SPEED: float = 50.0 # Speed of wall slide
const JUMP_AWAY_FROM_WALL_SPEED: float = 100.0


# Global movement  variable declaration
var is_dashing: bool = false
var can_dash: bool = true
var dash_timer: float = 0.0
var jump_amount: int = 0

func _physics_process(delta):
	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	var direction: float = Input.get_axis("move_left", "move_right")

	# Update dash timer
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
			velocity.x = 0  # Stop the dash horizontal movement when it ends

	# Check if player has touched ground and update abilities accordingly
	if is_on_floor():
		jump_amount = JUMP_AMOUNT
		can_dash = true

	# Handle dash
	if Input.is_action_just_pressed("dash") and not is_dashing and can_dash:
		can_dash = false
		start_dash(direction)
	
	wall_slide(delta)

	# Handle jump
	jump()
	
	# Handle crouch collition shape
	crouch()
	
	# Apply movement
	movement(direction, delta)

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
	
	# Move the player
	move_and_slide()



func jump() -> void:
	if is_dashing:
		return
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

func start_dash(dash_direction: float) -> void:
	is_dashing = true
	dash_timer = DASH_TIME  # Reset the dash timer
	velocity.y = 0  # Neutralize vertical velocity to ignore gravity
	if dash_direction == 0:
		# Default to the direction the sprite is facing if no input
		dash_direction = -1 if animated_sprite.flip_h else 1 
	velocity.x = DASH_SPEED * dash_direction  # Set constant horizontal dash speed


		
func play_animations(direction: float) -> void:
	if is_on_floor():
		if direction == 0:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("run")
	else:
		animated_sprite.play("jump")
		
	if Input.is_action_pressed("crouch") and is_on_floor():
			animated_sprite.play("crouch")
		
		
func wall_slide(delta: float) -> void:
	var is_wall_sliding: bool = false
	
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
	if direction != 0:
		# Accelerate towards the target speed
		var target_velocity = direction * MAX_SPEED
		
		if Input.is_action_pressed("crouch") and is_on_floor(): # slow player down when crouched
			target_velocity = direction * MAX_SPEED_CROUCHED
			
		velocity.x = move_toward(velocity.x, target_velocity, ACCELERATION * delta)
	else:
		# Decelerate smoothly to 0 when no input is provided
		velocity.x = move_toward(velocity.x, 0, DECELERATION * delta)
		
func crouch() -> void: # swaps the colitions shape when the player crouches
	if Input.is_action_pressed("crouch") and is_on_floor():
		collisionShape.disabled = true
		collisionShapeCrouched.disabled = false
	else:
		collisionShape.disabled = false
		collisionShapeCrouched.disabled = true
