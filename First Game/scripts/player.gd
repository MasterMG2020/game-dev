extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var collisionShape = $CollisionShape2D
@onready var collisionShapeCrouched = $CollisionShape2D_crouched
@onready var attack_area = $AttackArea

# Basic movement parameters
const MAX_SPEED: float = 900.0
const ACCELERATION: float = 4000.0
const DECELERATION: float = 6000.0

# Jump / Double Jump
const JUMP_AMOUNT: int = 2             # total normal jumps (single + double)
const JUMP_FORCE: float = 1000.0       # first jump force
const DOUBLE_JUMP_FORCE: float = 900.0 # second jump is often slightly lower

# This factor shortens the jump if player releases "jump" early while moving upwards
const SHORT_HOP_FACTOR: float = 0.5

# ---- NEW: For variable (long) jump ----
const EXTRA_JUMP_HOLD_TIME: float = 0.2   # how many seconds we keep boosting if button is held
const EXTRA_JUMP_FORCE: float = 25.0      # how strongly we boost per frame while jump is held

# Wall Slide / Wall Jump
const WALL_SLIDE_SPEED: float = 300.0
const JUMP_AWAY_FROM_WALL_SPEED: float = 1000.0

# ---- NEW: Additional offset when wall jumping ----
const WALL_JUMP_OFFSET: float = 20.0  # how far to nudge the player’s position away from the wall

# Dash
const DASH_SPEED: float = 2500.0
const DASH_TIME: float = 0.3

# Crouch
const MAX_SPEED_CROUCHED: float = 160.0

# Combo system
var attack_stage: int = 0
var combo_timer: float = 0.0
const COMBO_RESET_TIME: float = 1.0

# Attack lock times
const ATTACK_LOCK_TIME_1: float = 0.15
const ATTACK_LOCK_TIME_2: float = 0.15
var attack_lock_time: float = 0.0

# Movement flags
var is_dashing: bool = false
var can_dash: bool = true
var dash_timer: float = 0.0

# Jump count for normal/double jump
var jump_amount: int = 0

# Used to detect landing
var was_on_floor: bool = false
var is_landing: bool = false

# ---- NEW: Track how long jump is being held for variable jump. ----
var _is_jumping: bool = false
var _jump_hold_time: float = 0.0

signal died

func _ready():
	connect("died", _on_died)
	attack_area.body_entered.connect(_on_AttackArea_body_entered)

func _on_died():
	animated_sprite.play("dead")
	set_physics_process(false)

func _physics_process(delta):
	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	var direction: float = Input.get_axis("move_left", "move_right")

	# -------------------------------------------------
	#  COMBO TIMER
	# -------------------------------------------------
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			attack_stage = 0
			attack_lock_time = 0.0

	if Input.is_action_just_pressed("attack"):
		if attack_stage == 0 or combo_timer > 0.0:
			start_attack()

	# -------------------------------------------------
	#  DASH TIMER
	# -------------------------------------------------
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
			velocity.x = 0

	# -------------------------------------------------
	#  GROUND CHECK
	# -------------------------------------------------
	if is_on_floor():
		jump_amount = JUMP_AMOUNT
		can_dash = true
		_is_jumping = false
		_jump_hold_time = 0.0

	# -------------------------------------------------
	#  GRAVITY
	# -------------------------------------------------
	if not is_on_floor() and not is_dashing:
		velocity.y += gravity * delta

	# -------------------------------------------------
	#  SHORT-HOP LOGIC
	# -------------------------------------------------
	if Input.is_action_just_released("jump") and velocity.y < 0:
		# Player released jump early => short hop
		velocity.y *= SHORT_HOP_FACTOR
		_is_jumping = false

	# -------------------------------------------------
	#  LONG-JUMP (VARIABLE JUMP) LOGIC
	# -------------------------------------------------
	if _is_jumping and Input.is_action_pressed("jump") and velocity.y < 0:
		_jump_hold_time += delta
		if _jump_hold_time < EXTRA_JUMP_HOLD_TIME:
			# Keep boosting upward
			velocity.y -= EXTRA_JUMP_FORCE
	else:
		_is_jumping = false

	# -------------------------------------------------
	#  ATTACK LOCK vs. MOVEMENT
	# -------------------------------------------------
	var is_attempting_movement = (
		direction != 0 or
		Input.is_action_just_pressed("jump") or
		Input.is_action_just_pressed("dash")
	)

	if attack_stage != 0:
		if attack_lock_time > 0:
			attack_lock_time -= delta
			move_and_slide()
		else:
			if is_attempting_movement:
				attack_stage = 0
				combo_timer = 0.0

			wall_slide(delta)
			jump(delta)
			crouch()
			movement(direction, delta)

			# Flip sprite
			if direction > 0:
				animated_sprite.flip_h = false
				attack_area.position.x = 100
			elif direction < 0:
				animated_sprite.flip_h = true
				attack_area.position.x = -100

			play_animations(direction)
			move_and_slide()
	else:
		# Not currently attacking
		if Input.is_action_just_pressed("dash") and not is_dashing and can_dash:
			can_dash = false
			start_dash(direction)

		wall_slide(delta)
		jump(delta)
		crouch()
		movement(direction, delta)

		# Flip sprite
		if direction > 0:
			animated_sprite.flip_h = false
			attack_area.position.x = 100
		elif direction < 0:
			animated_sprite.flip_h = true
			attack_area.position.x = -100

		play_animations(direction)
		move_and_slide()

	# -------------------------------------------------
	#  Update was_on_floor
	# -------------------------------------------------
	was_on_floor = is_on_floor()

# -------------------------------------------------
#  ATTACK / COMBO
# -------------------------------------------------
func start_attack() -> void:
	if attack_stage == 0:
		attack_stage = 1
		animated_sprite.play("attack_1")
		attack_lock_time = ATTACK_LOCK_TIME_1
	elif attack_stage == 1:
		attack_stage = 2
		animated_sprite.play("attack_2")
		attack_lock_time = ATTACK_LOCK_TIME_2
	elif attack_stage == 2:
		attack_stage = 1
		animated_sprite.play("attack_1")
		attack_lock_time = ATTACK_LOCK_TIME_1
	combo_timer = COMBO_RESET_TIME

func _on_animation_finished() -> void:
	if animated_sprite.animation in ["attack_1", "attack_2"]:
		if combo_timer <= 0:
			attack_stage = 0
			animated_sprite.play("idle")

	if animated_sprite.animation == "landing":
		is_landing = false
		if abs(velocity.x) > 10:
			animated_sprite.play("run")
		else:
			animated_sprite.play("idle")

# -------------------------------------------------
#  HITBOX ENABLE/DISABLE
# -------------------------------------------------
func _enable_hitbox():
	$AttackArea/CollisionShape2D.disabled = false

func _disable_hitbox():
	$AttackArea/CollisionShape2D.disabled = true

func _on_animated_sprite_2d_frame_changed() -> void:
	if animated_sprite.animation == "attack_1" and animated_sprite.frame > 2:
		_enable_hitbox()
	elif animated_sprite.animation == "attack_2" and animated_sprite.frame > 2:
		_enable_hitbox()
	else:
		_disable_hitbox()

func _on_AttackArea_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(10)

# -------------------------------------------------
#  JUMP (with UNLIMITED WALL JUMPS)
# -------------------------------------------------
func jump(delta: float) -> void:
	if is_dashing:
		return

	if Input.is_action_just_pressed("jump"):
		# 1) If we are on a wall and NOT on the floor => infinite wall jumps
		if is_on_wall() and not is_on_floor():
			velocity.y = -JUMP_FORCE
			# Increase horizontal push
			if Input.is_action_pressed("move_left"):
				velocity.x = JUMP_AWAY_FROM_WALL_SPEED
				# Nudge the position to the right so we don't "stick"
				position.x += WALL_JUMP_OFFSET
			elif Input.is_action_pressed("move_right"):
				velocity.x = -JUMP_AWAY_FROM_WALL_SPEED
				# Nudge position to the left
				position.x -= WALL_JUMP_OFFSET
			else:
				# If we're on a wall but no left/right input,
				# check the wall's normal to decide which way to push
				var collision = get_slide_collision(0)
				if collision:
					velocity.x = -collision.normal.x * JUMP_AWAY_FROM_WALL_SPEED
					position.x -= collision.normal.x * WALL_JUMP_OFFSET

			_is_jumping = true
			_jump_hold_time = 0.0

		# 2) Otherwise do a normal jump (or double jump) if we have jumps left
		elif jump_amount > 0:
			if jump_amount == JUMP_AMOUNT:
				# First jump
				velocity.y = -JUMP_FORCE
			else:
				# Second jump
				velocity.y = -DOUBLE_JUMP_FORCE

			jump_amount -= 1
			_is_jumping = true
			_jump_hold_time = 0.0

# -------------------------------------------------
#  DASH
# -------------------------------------------------
func start_dash(dash_direction: float) -> void:
	is_dashing = true
	dash_timer = DASH_TIME
	velocity.y = 0

	if dash_direction == 0:
		# Default dash direction = facing direction
		dash_direction = -1 if animated_sprite.flip_h else 1

	velocity.x = DASH_SPEED * dash_direction

# -------------------------------------------------
#  ANIMATIONS
# -------------------------------------------------
func play_animations(direction: float) -> void:
	if attack_stage != 0:
		return
	if is_dashing:
		animated_sprite.play("dash")
		return
	if is_landing:
		return

	if not is_on_floor():
		if velocity.y < 0:
			if animated_sprite.animation != "jump":
				animated_sprite.play("jump")
		else:
			animated_sprite.play("falling")
	else:
		if not was_on_floor:
			animated_sprite.play("landing")
			is_landing = true
			return
		if Input.is_action_pressed("crouch"):
			animated_sprite.play("crouch")
		elif abs(direction) > 0:
			animated_sprite.play("run")
		else:
			animated_sprite.play("idle")

# -------------------------------------------------
#  WALL SLIDE
# -------------------------------------------------
func wall_slide(delta: float) -> void:
	var is_wall_sliding = false
	if is_on_wall() and not is_on_floor():
		if Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
			is_wall_sliding = true

	if is_wall_sliding:
		velocity.y = min(velocity.y + WALL_SLIDE_SPEED * delta, WALL_SLIDE_SPEED)

# -------------------------------------------------
#  LEFT/RIGHT MOVEMENT
# -------------------------------------------------
func movement(direction: float, delta: float) -> void:
	if direction != 0:
		var target_velocity = direction * MAX_SPEED
		if Input.is_action_pressed("crouch") and is_on_floor():
			target_velocity = direction * MAX_SPEED_CROUCHED
		velocity.x = move_toward(velocity.x, target_velocity, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, DECELERATION * delta)

# -------------------------------------------------
#  CROUCH
# -------------------------------------------------
func crouch() -> void:
	if collisionShape == null or collisionShapeCrouched == null:
		return
	if Input.is_action_pressed("crouch") and is_on_floor():
		collisionShape.disabled = true
		collisionShapeCrouched.disabled = false
	else:
		collisionShape.disabled = false
		collisionShapeCrouched.disabled = true
