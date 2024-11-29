## A node to manage health
class_name Health extends Node

## The maximum health
@export var max_health: float = 100.0
## The current health
@export var current_health: float = max_health
## Only use hitboxes if one is present
@export var hitbox_only: bool = true

## current_health has reached zero
signal health_depleted
## current_health has been reduced
signal health_lost(old_health: float, new_health: float)
## current_health has been increased
signal health_gained(old_health: float, new_health: float)
## current_health has changed
signal health_changed(old_health: float, new_health: float)

## Offsets current_health by the modifier
func add_health(modifier: float) -> void:
	if modifier == 0:
		return
	var old_health: float = current_health
	var new_health: float = current_health + modifier
	if new_health <= 0:
		current_health = 0
		health_depleted.emit()
	else:
		if new_health > max_health:
			current_health = max_health
		else:
			current_health = new_health

		if modifier < 0:
			health_lost.emit(old_health, new_health)
		else:
			health_gained.emit(old_health, new_health)
	health_changed.emit(old_health, new_health)


## Sets the current_health to a specific value
func set_health(new_value: float) -> void:
	var health_difference = new_value - current_health
	add_health(health_difference)
