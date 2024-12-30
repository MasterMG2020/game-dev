extends Node2D

const SPEED = 60

var direction = 1

@onready var ray_cast_right = $RayCastRight
@onready var ray_cast_left = $RayCastLeft
@onready var animated_sprite = $AnimatedSprite2D

# Called every frame. 'delta' is the elapsed time since the previous frame.


# --- NEW METHOD ---
func take_damage(amount = 0):
	print("Slime got hit!")
	# For now, just print a message.
	# Later, you can subtract health, play an animation, or queue_free().
