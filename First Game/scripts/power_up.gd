extends Node2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var area_2d = $Area2D

func _ready():
	# Connect the body_entered signal to detect when the player collects the power-up
	area_2d.body_entered.connect(_on_area_2d_body_entered)


func _on_area_2d_body_entered(body: Node2D) -> void:
	print("Body entered")
	if body is CharacterBody2D:  # Ensure it's the player
		body.has_dash_power_up = true  # Grant the dash power-up
		queue_free()  # Remove the power-up from the scene
