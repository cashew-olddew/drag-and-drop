class_name ActionRelocate extends DropAction

var occupant: Area2D
var target_spot: SnappingSpot

func _init(p_occupant: Area2D, p_spot: SnappingSpot):
	occupant = p_occupant
	target_spot = p_spot

func execute(zone: DropZone) -> void:
	DropUtils.clear_occupant_reference(zone, occupant)
	target_spot.occupant = occupant
	zone.occupant_changed.emit(zone, target_spot, null, occupant)

	var draggable = occupant.get_meta("draggable")
	if draggable:
		draggable.move_to(target_spot.point.global_position)
