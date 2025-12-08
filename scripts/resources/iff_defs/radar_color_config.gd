# RadarColorConfig Resource
# Defines colors for different radar blip types
# Loaded by IFFManager for radar display

class_name RadarColorConfig
extends Resource

## Radar blip colors by type (bright and dim variants)
@export_group("Missile Blips")
@export var missile_bright: Color = Color(1.0, 0.0, 0.0, 1.0)
@export var missile_dim: Color = Color(0.5, 0.0, 0.0, 1.0)

@export_group("Navbuoy Blips")
@export var navbuoy_bright: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var navbuoy_dim: Color = Color(0.5, 0.5, 0.5, 1.0)

@export_group("Warping Blips")
@export var warping_bright: Color = Color(0.0, 1.0, 1.0, 1.0)
@export var warping_dim: Color = Color(0.0, 0.5, 0.5, 1.0)

@export_group("Jump Node Blips")
@export var node_bright: Color = Color(0.7, 0.7, 0.7, 1.0)
@export var node_dim: Color = Color(0.35, 0.35, 0.35, 1.0)

@export_group("Tagged Blips")
@export var tagged_bright: Color = Color(1.0, 1.0, 0.0, 1.0)
@export var tagged_dim: Color = Color(0.5, 0.5, 0.0, 1.0)


## Get blip color by type index
## 0=Missile, 1=Navbuoy, 2=Warping, 3=Node, 4=Tagged
func get_blip_color(blip_type: int, bright: bool) -> Color:
	match blip_type:
		0:
			return missile_bright if bright else missile_dim
		1:
			return navbuoy_bright if bright else navbuoy_dim
		2:
			return warping_bright if bright else warping_dim
		3:
			return node_bright if bright else node_dim
		4:
			return tagged_bright if bright else tagged_dim
		_:
			return Color.WHITE
