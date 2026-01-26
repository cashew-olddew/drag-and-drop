@tool
extends EditorPlugin

func _enter_tree():
	add_custom_type("Draggable", "Node", preload("res://addons/drag_and_drop/scripts/draggable.gd"), preload("res://addons/drag_and_drop/icons/ToolMove.svg"))
	add_custom_type("DropZone", "Node2D", preload("res://addons/drag_and_drop/scripts/drop_zone.gd"), preload("res://addons/drag_and_drop/icons/DropZone.svg"))


func _exit_tree():
	# Clean-up of the plugin goes here.
	remove_custom_type("Draggable")
	remove_custom_type("DropZone")
	pass
