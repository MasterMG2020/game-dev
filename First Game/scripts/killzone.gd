extends Area2D

@onready var timer = $Timer

func _on_body_entered(body):
	print("You died!")
	Engine.time_scale = 0.5
	
	# Free all CollisionShape2D nodes in the body
	for child in body.get_children():
		if child is CollisionShape2D:
			child.queue_free()
	
	timer.start()

func _on_timer_timeout():
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
