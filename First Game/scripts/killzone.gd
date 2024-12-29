extends Area2D

@onready var timer = $Timer

func _on_body_entered(body):
	# Check if the body has the `died` signal (is a player)
	if body.has_signal("died"):
		print("You died!")
		# Emit the `died` signal to trigger the player's death animation
		body.emit_signal("died")
	
	
	timer.start()

func _on_timer_timeout():
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
