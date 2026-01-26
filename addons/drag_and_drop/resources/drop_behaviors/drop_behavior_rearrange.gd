class_name DropBehaviorRearrange extends DropBehavior

func evaluate(zone: DropZone, dropped_area: Area2D) -> DropPlan:
	var plan := DropPlan.new()
	var result := DropUtils.evaluate_drop_target(zone, dropped_area, false)
	if not result.can_drop:
		return plan
	plan.can_drop = true
	plan.drop_target = result.target

	if plan.drop_target and plan.drop_target.occupant and plan.drop_target.occupant != dropped_area:
		var free_spot = DropUtils.closest_spot(zone, plan.drop_target.occupant, true)
		if free_spot:
			plan.actions.append(ActionRelocate.new(plan.drop_target.occupant, free_spot))
		else:
			plan.can_drop = false 
			
	return plan
