class_name ActionEvict extends DropAction

var previous_occupant: Area2D

func _init(p_item: Area2D): 
	previous_occupant = p_item

func execute(zone: DropZone) -> void:
	DropUtils.clear_occupant_reference(zone, previous_occupant)
	previous_occupant.queue_free()
