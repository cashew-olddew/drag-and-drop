@tool
extends Node

class_name Draggable

enum DRAGGABLE_STATE {IDLE, DRAGGING, DROPPING, RETURNING, AUTO_MOVING}
@export_group("Config")
## Optional explicit reference to the target Area2D. Overwrites parent and owner references.
## The Area2D has to be an ancestor of this node.
@export var area_reference: Area2D = null:
	set(value):
		area_reference = value
		update_configuration_warnings()
## Name of the InputMap action that handles drag start and end
@export var drag_input_name: StringName = &"draggable_click":
	set(value):
		drag_input_name = value
		update_configuration_warnings()

@export_group("Behavior")
## Controls the speed at which the draggable node moves towards the cursor or towards the drop zone when dropped or returning.
@export_range(1.0, 100.0, 1.0) var dragging_speed: float = 50.0
## Z_Index dragged area will take. It is recommended to not
## set it to maximum as z_index is additive for children if 
## z_as_relative is set and they also have to be outside of the defined range
@export_range(-4096, 4096) var drag_z_index: int = 1000
## Information used by dropzones for checking if Draggable is accepted.
## The base DraggableType has an id that's checked by the
## dropzone for matching
@export var type: DraggableType = DraggableType.new()
		
var state = DRAGGABLE_STATE.IDLE

var initial_z_index = 0
var previous_position := Vector2.ZERO
var next_position := Vector2.ZERO

var a: Area2D = null

signal drag_started(area: Area2D)
signal drag_ended(area: Area2D)
signal state_changed(area: Area2D, state: DRAGGABLE_STATE)

#region Lifecycle

func _ready():
	var candidate: Area2D = null

	if area_reference != null:
		assert(area_reference is Area2D, "Selected node for 'area_reference' must be an Area2D")
		assert(area_reference.is_ancestor_of(self), "Selected Area2D must be an ancestor of this Draggable")
		candidate = area_reference
	elif get_parent() is Area2D:
		candidate = get_parent() as Area2D
	elif owner is Area2D:
		candidate = owner as Area2D
	a = candidate
	assert(a != null, "Draggable node '%s' must be linked to an Area2D (export, parent, or owner)" % name)
	if a != null and not Engine.is_editor_hint():
		a.set_meta("draggable", self)

	initial_z_index = a.z_index
	previous_position = a.global_position
	next_position = a.global_position
	a.input_event.connect(_on_input_event)

func _process(delta):
	match state:
		DRAGGABLE_STATE.IDLE:
			pass
		DRAGGABLE_STATE.DRAGGING:
			_handle_dragging(delta)
		DRAGGABLE_STATE.DROPPING:
			_handle_dropping(delta)	
		DRAGGABLE_STATE.RETURNING:
			_handle_returning(delta)
		DRAGGABLE_STATE.AUTO_MOVING:
			_handle_auto_moving(delta)

func _handle_dragging(delta: float) -> void:
	_move_toward(a.get_global_mouse_position(), delta)

func _handle_dropping(delta: float) -> void:
	_move_toward(next_position, delta)
	
	# TODO: Find a better way of "arriving" to the next_position
	if a.global_position.distance_to(next_position) <= 2.0:
		previous_position = next_position
		a.global_position = next_position
		_change_state_to(DRAGGABLE_STATE.IDLE)

func _handle_returning(delta: float) -> void:
	_move_toward(previous_position, delta)
	
	if a.global_position.distance_to(previous_position) <= 2.0:
		a.global_position = previous_position
		_change_state_to(DRAGGABLE_STATE.IDLE)

func _handle_auto_moving(delta: float) -> void:
	_move_toward(next_position, delta)
	
	if a.global_position.distance_to(next_position) <= 2.0:
		previous_position = next_position
		a.global_position = next_position
		_change_state_to(DRAGGABLE_STATE.IDLE)
		
func _move_toward(target: Vector2, delta: float) -> void:
	a.global_position = lerp(a.global_position, target, delta * dragging_speed)

#endregion

#region Input Handling

func _on_input_event(_viewport, event, _shape_idx):
	if event.is_action_pressed(drag_input_name) and state == DRAGGABLE_STATE.IDLE:
		previous_position = a.global_position
		_change_state_to(DRAGGABLE_STATE.DRAGGING)
		drag_started.emit(a)

func _input(event):
	if event.is_action_released(drag_input_name) and state == DRAGGABLE_STATE.DRAGGING:
		drag_ended.emit(a)
		var overlapping_areas = a.get_overlapping_areas()
		var droparea: DropZone = _is_over_dropzone(overlapping_areas)
		
		if not droparea:
			move_to(previous_position, DRAGGABLE_STATE.RETURNING)
			return
			
		var drop_spot = droparea.try_dropping(a)
		if drop_spot:
			move_to(drop_spot, DRAGGABLE_STATE.DROPPING)
			return
			
		move_to(previous_position, DRAGGABLE_STATE.RETURNING)
#endregion

#region Exposed Functions

func move_to(pos: Vector2, reason := DRAGGABLE_STATE.AUTO_MOVING) -> void:
	if state != DRAGGABLE_STATE.RETURNING:
		next_position = pos
	_change_state_to(reason)

#endregion

#region Internal Functions

func _change_state_to(new_state: DRAGGABLE_STATE) -> void:
	if state == new_state:
		return
	state = new_state
	
	match state:
		DRAGGABLE_STATE.DRAGGING, DRAGGABLE_STATE.AUTO_MOVING:
			a.z_index = drag_z_index
		_:
			a.z_index = initial_z_index
	state_changed.emit(a, state)

func _is_over_dropzone(areas: Array[Area2D]) -> DropZone:
	if not areas:
		return null
	for area in areas:
		for child in area.get_children():
			if child is DropZone:
				return child
	return null
	
#endregion

func _get_configuration_warnings() -> PackedStringArray:
	var warnings = PackedStringArray()
	
	if not ProjectSettings.has_setting("input/" + drag_input_name):
		warnings.append("Action " + str(drag_input_name) + " could not be found in the InputMap")
	if area_reference != null and not (area_reference is Area2D):
		warnings.append("Selected node for 'area_reference' is not an Area2D")
	if area_reference != null and area_reference is Area2D and not area_reference.is_ancestor_of(self):
		warnings.append("Selected Area2D is not an ancestor of this Draggable; prefer parent/grandparent to avoid cross-branch issues")
	if area_reference == null and not (get_parent() is Area2D) and not (owner is Area2D):
		warnings.append("No Area2D found via export, parent, or owner; Draggable requires an Area2D")
	return warnings
