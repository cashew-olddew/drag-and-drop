class_name ActionEvict extends DropAction

var previous_occupant: Area2D

func _init(p_previous_occupant: Area2D): 
	previous_occupant = p_previous_occupant

func execute(zone: DropZone) -> void:
	DropUtils.clear_occupant_reference(zone, previous_occupant)
	previous_occupant.queue_free()
