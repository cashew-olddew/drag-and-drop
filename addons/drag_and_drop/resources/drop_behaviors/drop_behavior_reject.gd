extends DropBehavior
class_name DropBehaviorReject

func evaluate(zone: DropZone, dropped_area: Area2D) -> DropPlan:
	var plan := DropPlan.new()
	var result = DropUtils.evaluate_drop_target(zone, dropped_area, true)
	if not result.can_drop:
		return plan
	plan.can_drop = true
	plan.drop_target = result.target
	
	return plan
