extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var collisionShape = $CollisionShape2D
@onready var collisionShapeCrouched = $CollisionShape2D_crouched


# Basic movement parameters
const MAX_SPEED: float = 900.0        # Top speed
const ACCELERATION: float = 4000.0   # Acceleration rate
const DECELERATION: float = 6000.0   # Deceleration rate

# Advanced movement parameters
const JUMP_VELOCITY: float = -1000.0
const JUMP_AMOUNT: int = 2 # number of jumps the player has
const DASH_SPEED: float = 2000.0 # Dash velocity
const DASH_TIME: float = 0.4 # Duration of the dash
const MAX_SPEED_CROUCHED: float = 160.0 # speed while crouched

# -- WALL SLIDE PARAMETERS --
const WALL_SLIDE_SPEED: float = 300.0
const JUMP_AWAY_FROM_WALL_SPEED: float = 200.0

# -- COMBO VARIABLES --
var attack_stage: int = 0
var combo_timer: float = 0.0
const COMBO_RESET_TIME: float = 1.0

# If you want the player briefly “locked” at the start of each attack:
# e.g., 0.15 seconds of no movement for the first/second attacks
const ATTACK_LOCK_TIME_1: float = 0.15
const ATTACK_LOCK_TIME_2: float = 0.15

# This tracks how much longer the current attack “locks” movement.
var attack_lock_time: float = 0.0

# -- MOVEMENT FLAGS --
var is_dashing: bool = false
var can_dash: bool = true
var dash_timer: float = 0.0
var jump_amount: int = 0

# Signal for dying animation
signal died

func _ready():
	# Connect the `died` signal to the `die` function
	connect("died", _on_died)
	$AttackArea.body_entered.connect(_on_AttackArea_body_entered)


func _on_died():
	# Play the death animation
	animated_sprite.play("dead")
	# Disable player input or other logic here if needed
	set_physics_process(false)  # Disable movement

func _physics_process(delta):
	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	var direction: float = Input.get_axis("move_left", "move_right")
	
	# ----- Combo Timer Updates -----
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			attack_stage = 0
			attack_lock_time = 0.0

	# ----- Attack Input -----
	if Input.is_action_just_pressed("attack"):
	# If not attacking or we still have time to continue combo...
		if attack_stage == 0 or combo_timer > 0.0:
			start_attack()

	# ----- Dash Timer -----
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
			velocity.x = 0

	# ----- Ground Check -----
	if is_on_floor():
		jump_amount = JUMP_AMOUNT
		can_dash = true

	# ----- Gravity -----
	# Even if attacking, we generally still want gravity to apply 
	# (unless you specifically want an “air stall” while attacking).
	if not is_on_floor() and not is_dashing:
		velocity.y += gravity * delta

	# =============================
	#    ATTACK / MOVEMENT LOGIC
	# =============================
	#
	# If we are in the "attack lock" period, we partially or fully disable movement.
	# If the player *tries* to move/dash/jump, they lose the combo (punishment).
	#
	# After the lock time ends, they can move freely BUT that still cancels the combo
	# to avoid "walk + keep swinging" with no penalty.

	var is_attempting_movement = (direction != 0 or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("dash"))

	if attack_stage != 0:
		# If currently attacking...
		if attack_lock_time > 0:
			# We are "locked" for this many seconds. Decrement and block movement.
			attack_lock_time -= delta

			# But still do move_and_slide() so gravity & collisions work
			move_and_slide()
		else:
			# Attack lock expired -> if we detect new movement input, reset combo
			if is_attempting_movement:
				# The user moved or jumped or dashed - cancel combo.
				attack_stage = 0
				combo_timer = 0.0
				# (Optionally play a short "canceled" animation or effect.)

			# Normal movement (no lock, but still in combo):
			# Because we said "movement will stop the combo", once they 
			# physically press left/right or dash, the combo is canceled above.
			# But if they're holding direction from before the attack started, 
			# you can decide if that also cancels it or not. 
			# For this example, we'll cancel if direction != 0.

			wall_slide(delta)
			jump()
			crouch()
			movement(direction, delta)
			if direction > 0:
				animated_sprite.flip_h = false
				$AttackArea.position.x = 100  # Place the hitbox to the right side
			elif direction < 0:
				animated_sprite.flip_h = true
				$AttackArea.position.x = -100  # Place the hitbox to the right side
			play_animations(direction)

			move_and_slide()
	else:
		# Not attacking at all -> normal movement
		if Input.is_action_just_pressed("dash") and not is_dashing and can_dash:
			can_dash = false
			start_dash(direction)

		wall_slide(delta)
		jump()
		crouch()
		movement(direction, delta)

		if direction > 0:
			animated_sprite.flip_h = false
			$AttackArea.position.x = 100
		elif direction < 0:
			animated_sprite.flip_h = true
			$AttackArea.position.x = -100

		play_animations(direction)
		move_and_slide()

func start_attack() -> void:
	# Advance or reset attack_stage
	if attack_stage == 0:
		attack_stage = 1
		animated_sprite.play("attack_1")
		attack_lock_time = ATTACK_LOCK_TIME_1
	elif attack_stage == 1:
		attack_stage = 2
		animated_sprite.play("attack_2")
		attack_lock_time = ATTACK_LOCK_TIME_2
	elif attack_stage == 2:
		attack_stage = 1  # or 3 if you want to do a third distinct attack
		animated_sprite.play("attack_1")
		attack_lock_time = ATTACK_LOCK_TIME_1
	# Reset the combo timer so the player has time to chain more attacks
	combo_timer = COMBO_RESET_TIME

func _on_animation_finished() -> void:
	# If the current animation is an attack AND the combo timer is done,
	# revert to idle
	if animated_sprite.animation in ["attack_1", "attack_2"]:
		# Reset to idle if the combo isn't continued
		if combo_timer <= 0:
			attack_stage = 0
			animated_sprite.play("idle")
			
func _enable_hitbox():
	$AttackArea/CollisionShape2D.disabled = false

func _disable_hitbox():
	$AttackArea/CollisionShape2D.disabled = true

func _on_animated_sprite_2d_frame_changed() -> void:
	# If we are in an attack animation...
	if animated_sprite.animation == "attack_1" and animated_sprite.frame > 2:
		# If frame == 2 means the 3rd frame (0-based indexing)
		_enable_hitbox()
	elif animated_sprite.animation == "attack_2" and animated_sprite.frame > 2:
		_enable_hitbox()
	else:
		# You might disable it on any other frame,
		# or wait until the animation finishes. Up to you:
		_disable_hitbox()

func _on_AttackArea_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(10)  # or however much damage


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
	if attack_stage != 0:
		return
	if is_dashing:
		animated_sprite.play("dash")
		return
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
		
		
func movement(direction: float, delta: float) -> void:
	if direction != 0:
		# Accelerate towards the target speed
		var target_velocity = direction * MAX_SPEED
		
		if Input.is_action_pressed("crouch") and is_on_floor(): # slow player down when crouched
			target_velocity = direction * MAX_SPEED_CROUCHED
			
		velocity.x = move_toward(velocity.x, target_velocity, ACCELERATION * delta)
	else:
		# Decelerate smoothly to 0 when no input is provided
		velocity.x = move_toward(velocity.x, 0, DECELERATION * delta)
		
func crouch() -> void:
	if collisionShape == null or collisionShapeCrouched == null:
		return  # Exit if collision shapes are missing

	# Check for crouch input and if the player is on the floor
	if Input.is_action_pressed("crouch") and is_on_floor():
		collisionShape.disabled = true
		collisionShapeCrouched.disabled = false
	else:
		collisionShape.disabled = false
		collisionShapeCrouched.disabled = true
