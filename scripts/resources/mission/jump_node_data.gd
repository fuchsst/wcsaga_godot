# scripts/resources/mission/jump_node_data.gd
# Defines the data structure for a jump node defined in a mission file.
extends Resource
class_name JumpNodeData

@export var node_name: String = "" # Optional name ($Jump Node Name:)
@export var position: Vector3 = Vector3.ZERO # $Jump Node: (x, y, z)
@export var model_filename: String = "" # Optional +Model File:
@export var color: Color = Color(1, 1, 1, 1) # Optional +Alphacolor: (R G B A)
@export var hidden: bool = false # Optional +Hidden:
