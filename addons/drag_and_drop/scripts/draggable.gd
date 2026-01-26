@tool
extends Node

class_name Draggable

enum DRAGGABLE_STATE {IDLE, DRAGGING, DROPPING, RETURNING, AUTO_MOVING}
@export_range(1.0, 100.0, 1.0) var dragging_speed: float = 50.0
## Information used by dropzones for checking if Draggable is accepted
@export var type: DraggableType = DraggableType.new()
## Name of the input that handles drag start and end
@export var drag_input_name: StringName = &"draggable_click":
	set(value):
		drag_input_name = value
		update_configuration_warnings()
## Z_Index dragged area will take. It is recommended to not
## set it to maximum as z_index is additive for children if 
## z_as_relative is set and they also have to be outside of the defined range
@export_range(-4096, 4096) var drag_z_index: int = 1000
		
var state = DRAGGABLE_STATE.IDLE

var initial_z_index = 0
var previous_position := Vector2.ZERO
var next_position := Vector2.ZERO

var o: Area2D = null

signal drag_started(area: Area2D)
signal drag_ended(area: Area2D)
signal state_changed(area: Area2D, state: DRAGGABLE_STATE)

#region Lifecycle

func _ready():
	o = owner as Area2D
	assert(o != null, "Draggable node '%s' must be owned by an Area2D node" % name)
	o.set_meta("draggable", self)
	initial_z_index = o.z_index
	previous_position = o.global_position
	next_position = o.global_position
	o.input_event.connect(_on_input_event)

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
	_move_toward(o.get_global_mouse_position(), delta)

func _handle_dropping(delta: float) -> void:
	_move_toward(next_position, delta)
	
	if o.global_position.distance_to(next_position) <= 2.0:
		previous_position = next_position
		o.global_position = next_position
		_change_state_to(DRAGGABLE_STATE.IDLE)

func _handle_returning(delta: float) -> void:
	_move_toward(previous_position, delta)
	
	if o.global_position.distance_to(previous_position) <= 2.0:
		o.global_position = previous_position
		_change_state_to(DRAGGABLE_STATE.IDLE)

func _handle_auto_moving(delta: float) -> void:
	_move_toward(next_position, delta)
	
	if o.global_position.distance_to(next_position) <= 2.0:
		previous_position = next_position
		o.global_position = next_position
		_change_state_to(DRAGGABLE_STATE.IDLE)
		
func _move_toward(target: Vector2, delta: float) -> void:
	o.global_position = lerp(o.global_position, target, delta * dragging_speed)

#endregion

#region Input Handling

func _on_input_event(_viewport, event, _shape_idx):
	if event.is_action_pressed(drag_input_name) and state == DRAGGABLE_STATE.IDLE:
		previous_position = o.global_position
		_change_state_to(DRAGGABLE_STATE.DRAGGING)
		drag_started.emit(o)

func _input(event):
	if event.is_action_released(drag_input_name) and state == DRAGGABLE_STATE.DRAGGING:
		drag_ended.emit(o)
		var overlapping_areas = o.get_overlapping_areas()
		var droparea: DropZone = _is_over_dropzone(overlapping_areas)
		
		if not droparea:
			move_to(previous_position, DRAGGABLE_STATE.RETURNING)
			return
			
		var drop_spot = droparea.try_dropping(o)
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
			o.z_index = drag_z_index
		_:
			o.z_index = initial_z_index
	state_changed.emit(o, state)

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
	#if o is not Area2D:
			#warnings.append("Draggable node '%s' must be owned by an Area2D node" % name)
	return warnings
