# Drag and Drop

A simple and extensible drag and drop plugin for Godot.

## Features

- **Draggable** - A node that can be attached to any Area2D to make it draggable.
- **DropZone** - A node that can be attached to any Area2D to make it a drop target.
- **DropUtils** - Utility functions to assist with behavior and action implementations.
- **DropBehavior** - Extensible resource to define _what_ happens when a Draggable is dropped onto a DropZone.
- **DropAction** - Extensible resource to define _how_ the DropBehavior is executed.

### Draggable Parameters

`area_reference` (Area2D, default: null)

Optional explicit reference to the target Area2D. Overwrites parent and owner references. The Area2D has to be an ancestor of this node.

---

`drag_input_name` (StringName, default: "draggable_click")

The name of the drag action that's set up in the project settings InputMap. For when there already exists an action mapped to mouse clicks and you want to use that instead of creating a new one, specifically for dragging.

---

`dragging_speed` (float, default: 50.0)

Controls the speed at which the draggable node moves towards the cursor or towards the drop zone when dropped or returning.

---

`drag_z_index` (int, default: 1000)

Controls the z-index of the draggable node while it is being dragged. This ensures that the draggable appears above other nodes during the drag operation.

---

`type` (DraggableType)

Contains information used by dropzones for checking if a Draggable is accepted.

`DraggableType` is by default a Resource with a single `id` string property. This is generally enough for a DropZone to check against and accept or reject the Draggable. This can be extended with more properties if complex draggable checks are needed.


### DropZone Parameters

`area_reference` (Area2D, default: null)

Optional explicit reference to the target Area2D. Overwrites parent and owner references. The Area2D has to be an ancestor of this node.

---

`attach_spot` (Node2D, default: DropZone owner)

The node under which the Draggables will be attached as children when dropped onto this DropZone. By default, this is the DropZone's owner node.

---

`drop_behavior` (DropBehavior)

The DropBehavior resource that defines what happens when a Draggable is dropped onto this DropZone. A DropBehavior's role is to determine if the Draggable is accepted and what `DropActions` will be executed.

The plugin comes with three built-in DropBehaviors:
- `drop_behavior_reject`: If a DropZone snapping point is occupied, the Draggable will be rejected by that spot and will look for the closest free spot instead. If all spots are occupied, the Draggable will return to its original position.
- `drop_behavior_replace`: If a DropZone snapping point is occupied, the existing occupant will be freed and the new Draggable will take its place.
- `drop_behavior_rearrange`: If a DropZone snapping point is occupied, the existing occupant will be moved to the closest free spot, making room for the new Draggable.

Custom behaviors can be created by extending the DropBehavior resource.

---

`snap_style` (SNAP_STYLE, default: SNAP_STYLE.SNAP_MARKERS)

Defines how the Draggable will be positioned when dropped onto this DropZone.
- `SNAP_STYLE.NONE`: The Draggable will remain at its current position.
- `SNAP_STYLE.CENTER`: The Draggable will be centered on the DropZone owner's position
- `SNAP_STYLE.SNAP_MARKERS`: The Draggable will snap to predefined Marker2D nodes that are children of the DropZone.

---

`accepted_draggable_types` (Array[DraggableType], default: DraggableType with `id=""`)

An array of Draggable types that the DropZone will accept. The built-in DropBehaviors will check against this array, and if any DraggableType has an `id` that matches one in this array, the Draggable will be accepted. More complex type checking can be implemented in custom DropBehaviors.

---

### DropUtils

Provides utility functions for common operations needed in DropBehaviors and DropActions.

---

`is_area_type_accepted(zone: DropZone, area: Area2D) -> bool`

A simple check against the ids of the DraggableType of the Draggable attached to the given Area2D and the accepted_draggable_types of the given DropZone. Returns true if any of the ids match.

---

`clear_occupant_reference(zone: DropZone, occupant: Area2D) -> void`

Detaches occupant from snapping point and emits the `occupant_changed` signal on the DropZone.

---

`evaluate_drop_target(zone: DropZone, area: Area2D, require_free: bool) -> DropTargetResult`

Returns a DropTargetResult object which tells whether the Draggable can be dropped and where. If `require_free` is true, only free SnappingSpots will be considered.

---

`closest_spot(zone: DropZone,area: Area2D, require_free: bool) -> SnappingSpot`

Returns the closest SnappingSpot in the DropZone to the given Area2D. Uses the `distance_to` method of Node2D for distance calculation. If `require_free` is true, only free SnappingSpots will be considered.

### Creating custom drop behaviors

Custom behaviors can be defined by creating new DropBehavior and DropAction resources.

**DropBehavior**

A custom DropBehavior needs implement the `evaluate(zone: DropZone, dropped_area: Area2D) -> DropPlan` function of the base DropBehavior class. Its role is to determine if the Draggable is accepted and what `DropActions` will be executed. The DropBehavior should **not** perform the actual drop or any mutation. It should just return a DropPlan object containing:
- `can_drop`: Whether the Draggable can be dropped
- `drop_target`: The SnappingSpot where the Draggable will be dropped
- `actions`: An array of additional DropActions to be executed during the drop.

See examples of drop behavior implementations in [drop_behaviors](./addons/drag_and_drop/resources/drop_behaviors/).

**DropAction**

A custom DropAction needs to implement the `execute(_zone: DropZone) -> void` function of the base DropAction class. Its role is to perform secondary mutations during the drop process, such as updating references, moving, removing other Draggables, etc.

Normally, you'd only need to care about the snapping_points, but the DropZone is added as a parameter for more complex use cases.

See examples of drop action implementations in [drop_actions](./addons/drag_and_drop/resources/actions/).

### Signals

**Draggable Signals**

- `drag_started(area: Area2D)`  
  Emitted when the drag input is pressed while the Draggable is IDLE, switching the state to DRAGGING. Payload is the owner Area2D.

- `drag_ended(area: Area2D, drop_spot: SnappingSpot)`  
  Emitted immediately after releasing the drag input if the Draggable is DRAGGING. This happens before evaluating the drop or moving the Draggable. Payload is the owner Area2D and the SnappingSpot where it will be dropped or null if the area won't drop on drag end.

- `state_changed(area: Area2D, state: DRAGGABLE_STATE)`  
  Emitted on every state transition (IDLE, DRAGGING, DROPPING, RETURNING, AUTO_MOVING). Use to detect completion when it returns to IDLE after animations.

**DropZone Signals**

- `drop_evaluated(zone: DropZone, area: Area2D, plan: DropPlan)`  
  Emitted after the drop behavior returned a DropPlan, before any actual changes. Signals the computed plan for the drop attempt.

- `drop_rejected(zone: DropZone, area: Area2D, plan: DropPlan)`  
  Emitted when `plan.can_drop == false`. No mutations are applied.

- `drop_accepted(zone: DropZone, area: Area2D, plan: DropPlan)`  
  Emitted when `plan.can_drop == true`, right before applying the plan.

- `drop_applied(zone: DropZone, area: Area2D, plan: DropPlan)`  
  Emitted after `_apply_plan()` finishes. At this point reparenting and occupant updates are done.

- `occupant_changed(zone: DropZone, spot: SnappingSpot, old_occupant: Area2D, new_occupant: Area2D)`  
  Emitted whenever a spot’s occupant reference changes:
  - Detach/clear (e.g., `DropUtils.clear_occupant_reference`, drag start)
  - Attach on drop (`_apply_plan`)
  - Ephemeral spot create in `NO_SNAP` (`_make_ephemeral_spot`)

Typical flow: `drop_evaluated -> drop_accepted/drop_rejected -> drop_applied`

## Contributing

If you find any bugs or improvement ideas, feel free to [fork](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/fork-a-repo#about-forks) this repository and suggest a change.

If you'd like to see an improvement, but don't know how to contribute, you can [create an Issue](https://github.com/cashew-olddew/drag-and-drop/issues/new).

## License

This project and shader falls under the [CC0](LICENSE) license, meaning that you can do anything you want with the code here, even use it commercially. You do not have any obligation to credit me, but doing so would be highly appreciated.

## Support

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/H2H2XSCXW)

Donations are appreciated and help me continue creating free content. Please donate only what you can afford. 🥜
