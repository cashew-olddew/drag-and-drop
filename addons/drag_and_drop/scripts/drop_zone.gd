@tool
extends Node2D
class_name DropZone

signal drop_evaluated(zone: DropZone, area: Area2D, plan: DropPlan)
signal drop_rejected(zone: DropZone, area: Area2D, plan: DropPlan)
signal drop_accepted(zone: DropZone, area: Area2D, plan: DropPlan)
signal drop_applied(zone: DropZone, area: Area2D, plan: DropPlan)
signal occupant_changed(zone: DropZone, spot: SnappingSpot, old_occupant: Area2D, new_occupant: Area2D)

enum SNAP_STYLE { 
	## Draggable won't snap. It will, instead, stay at its position when dragging stops. 
	NO_SNAP, 
	## Draggable snaps to the transform center of the parent area 
	SNAP_CENTER, 
	## Draggable snaps to marker children of the DropZone. If there are no marker children, defaults to NO_SNAP 
	SNAP_MARKERS 
}

@export_group("Config")
## Optional explicit reference to the target Area2D. Overwrites parent and owner references.
## The Area2D has to be an ancestor of this node.
@export var area_reference: Area2D = null:
	set(value):
		area_reference = value
		update_configuration_warnings()
## The node under which draggables will be reparented
@export var attach_spot: Node2D

@export_group("Behavior")
## Defines what happens when a Draggable is dropped onto this DropZone. 
## A DropBehavior's role is to determine if the Draggable is accepted and 
## what `DropActions` will be executed.
@export var drop_behavior: DropBehavior = DropBehaviorReject.new()
@export var snap_style := SNAP_STYLE.SNAP_MARKERS
## Information used for checking if Draggable is accepted.
## The base DraggableType has an id that's checked by the
## dropzone for matching
@export var accepted_draggable_types: Array[DraggableType] = []
var snapping_points: Array[SnappingSpot] = []
var a: Area2D = null

#region Lifecycle

func _ready():
	var candidate: Area2D = null
	if area_reference != null:
		assert(area_reference is Area2D, "Selected node for 'area_reference' must be an Area2D")
		assert(area_reference.is_ancestor_of(self), "Selected Area2D must be an ancestor of this DropZone")
		candidate = area_reference
	elif get_parent() is Area2D:
		candidate = get_parent() as Area2D
	elif owner is Area2D:
		candidate = owner as Area2D
	a = candidate
	assert(a != null, "DropZone node '%s' must be linked to an Area2D (export, parent, or owner)" % name)
	if a != null and not Engine.is_editor_hint():
		a.set_meta("dropzone", self)
	if not attach_spot:
		attach_spot = a
	if accepted_draggable_types.size() == 0:
		accepted_draggable_types.append(DraggableType.new())
	_initialize_snapping_positions()

#endregion

#region Exposed Functions

func try_dropping(area: Area2D):
	var plan := drop_behavior.evaluate(self, area)
	drop_evaluated.emit(self, area, plan)
	
	if plan.can_drop:
		drop_accepted.emit(self, area, plan)
		_apply_plan(plan, area)
		drop_applied.emit(self, area, plan)
		
		if plan.drop_target:
			return plan.drop_target
		
		if snap_style == SNAP_STYLE.NO_SNAP:
			return _find_ephemeral_spot_for(area)
	
	drop_rejected.emit(self, area, plan)
	return null

#endregion

#region Internal Functions

func _initialize_snapping_positions():
	snapping_points.clear()

	match snap_style:
		SNAP_STYLE.NO_SNAP:
			# No snapping points at all
			return

		SNAP_STYLE.SNAP_CENTER:
			var spot := SnappingSpot.new()
			spot.point = a
			spot.occupant = null
			snapping_points.append(spot)

		SNAP_STYLE.SNAP_MARKERS:
			for child in get_children():
				if child is Marker2D:
					var spot := SnappingSpot.new()
					spot.point = child
					spot.occupant = null
					snapping_points.append(spot)

			if snapping_points.is_empty():
				return
	
func _apply_plan(plan: DropPlan, dropped_area: Area2D) -> void:
	# 1. In case I move the draggable within the same area, I detach it first
	_detach(dropped_area)

	# 2. Execute side-effects (Evictions, Relocations, anything really)
	for action in plan.actions:
		action.execute(self)

	# 3. Finalize drop
	if plan.drop_target:
		var current_occupant = plan.drop_target.occupant
		if current_occupant and current_occupant != dropped_area:
			_detach(current_occupant)
		
		plan.drop_target.occupant = dropped_area
		occupant_changed.emit(self, plan.drop_target, null, dropped_area)
		_attach(dropped_area)
	else:
		# NO_SNAP: still track occupancy so signals and utilities work
		if snap_style == SNAP_STYLE.NO_SNAP:
			_attach(dropped_area)
			_make_ephemeral_spot(dropped_area)
	
func _attach(area: Area2D):
	if area.get_parent():
		area.reparent(attach_spot)
	else:
		attach_spot.add_child(area)
	
	var draggable = area.get_meta("draggable")
	if draggable:
		if not draggable.drag_started.is_connected(_on_draggable_drag_started):
			draggable.drag_started.connect(_on_draggable_drag_started)
		if not draggable.drag_ended.is_connected(_on_draggable_drag_ended):
			draggable.drag_ended.connect(_on_draggable_drag_ended)
func _detach(area: Area2D):
	DropUtils.clear_occupant_reference(self, area)
	
	var draggable = area.get_meta("draggable")
	if draggable and draggable.drag_started.is_connected(_on_draggable_drag_started):
			draggable.drag_started.disconnect(_on_draggable_drag_started)
	if draggable and draggable.drag_ended.is_connected(_on_draggable_drag_ended):
		draggable.drag_ended.disconnect(_on_draggable_drag_ended)

	# For NO_SNAP, remove ephemeral spots that tracked this area
	if snap_style == SNAP_STYLE.NO_SNAP:
		_remove_ephemeral_spots_for(area)
#endregion

#region Signal Handlers

func _on_draggable_drag_started(area: Area2D):
	# For NO_SNAP, remove ephemeral spots that were tracking this area
	if snap_style == SNAP_STYLE.NO_SNAP:
		_remove_ephemeral_spots_for(area)

func _on_draggable_drag_ended(area: Area2D, drop_spot: SnappingSpot):
	# If drop_spot is null, the draggable is returning
	if drop_spot != null:
		if not snapping_points.has(drop_spot):
			_detach(area)
		return
	
	var draggable = area.get_meta("draggable")
	
	if snap_style == SNAP_STYLE.NO_SNAP:
		_attach(area)
		_make_ephemeral_spot(area)
	else:
		for spot in snapping_points:
			if spot.occupant == area:
				_attach(area)
				break

#endregion

#region Ephemeral Spot Helpers (NO_SNAP)

func _make_ephemeral_spot(area: Area2D) -> SnappingSpot:
	var spot := SnappingSpot.new()
	spot.point = area
	spot.occupant = area
	spot.ephemeral = true
	snapping_points.append(spot)
	occupant_changed.emit(self, spot, null, area)
	return spot

func _remove_ephemeral_spots_for(area: Area2D) -> void:
	for i in range(snapping_points.size() - 1, -1, -1):
		var s: SnappingSpot = snapping_points[i]
		if s.ephemeral and s.point == area:
			snapping_points.remove_at(i)

func _find_ephemeral_spot_for(area: Area2D) -> SnappingSpot:
	for s in snapping_points:
		if s.ephemeral and s.point == area:
			return s
	return null

#endregion

func _get_configuration_warnings() -> PackedStringArray:
	var warnings = PackedStringArray()
	if area_reference != null and not (area_reference is Area2D):
		warnings.append("Selected node for 'area_reference' is not an Area2D")
	if area_reference != null and area_reference is Area2D and not area_reference.is_ancestor_of(self):
		warnings.append("Selected Area2D is not an ancestor of this DropZone; prefer parent/grandparent to avoid cross-branch issues")
	if area_reference == null and not (get_parent() is Area2D) and not (owner is Area2D):
		warnings.append("No Area2D found via export, parent, or owner; DropZone requires an Area2D")
	return warnings
