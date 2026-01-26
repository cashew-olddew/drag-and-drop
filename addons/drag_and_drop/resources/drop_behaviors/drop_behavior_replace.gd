class_name DropBehaviorReplace extends DropBehavior

func evaluate(zone: DropZone, dropped_area: Area2D) -> DropPlan:
	var plan := DropPlan.new()
	var result := DropUtils.evaluate_drop_target(zone, dropped_area, false)
	if not result.can_drop:
		return plan
	plan.can_drop = true
	plan.drop_target = result.target
	
	# If someone is there, we schedule them for eviction
	if plan.drop_target and plan.drop_target.occupant and plan.drop_target.occupant != dropped_area:
		plan.actions.append(ActionEvict.new(plan.drop_target.occupant))
		
	return plan
