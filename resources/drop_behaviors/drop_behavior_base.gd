## Base class for defining drop behaviors for a DropZone.
##
## A DropBehavior decides whether a snapping spot is valid for a given draggable, 
## how snapping points are updated when a drop happens and 
## the final position the draggable should snap to
@abstract 
class_name DropBehavior extends Resource

@abstract
func evaluate(zone: DropZone, dropped_area: Area2D) -> DropPlan
