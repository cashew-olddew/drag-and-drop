class_name DropUtils

static func is_area_type_accepted(zone: DropZone, area: Area2D) -> bool:
	var draggable = area.get_meta("draggable")
	if not draggable:
		return false

	for type in zone.accepted_draggable_types:
		if type.id == draggable.type.id:
			return true
	return false

static func clear_occupant_reference(zone: DropZone, occupant: Area2D) -> void:
	for spot in zone.snapping_points:
		if spot.occupant == occupant:
			spot.occupant = null
			zone.occupant_changed.emit(zone, spot, occupant, null)
			return

static func evaluate_drop_target(
	zone: DropZone,
	area: Area2D,
	require_free: bool
) -> DropTargetResult:
	var result := DropTargetResult.new()

	if not is_area_type_accepted(zone, area):
		return result

	if zone.snap_style == DropZone.SNAP_STYLE.NO_SNAP:
		result.can_drop = true
		result.target = null
		return result

	var target := closest_spot(zone, area, require_free)

	if target:
		result.can_drop = true
		result.target = target
	return result

static func closest_spot(
	zone: DropZone,
	area: Area2D,
	require_free: bool = false
) -> SnappingSpot:
	var best = null
	var best_dist := INF

	for spot in zone.snapping_points:
		if require_free and spot.occupant != null:
			continue

		var d := area.global_position.distance_to(
			spot.point.global_position
		)

		if d < best_dist:
			best_dist = d
			best = spot

	return best
