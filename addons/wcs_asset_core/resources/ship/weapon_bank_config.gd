class_name WeaponBankConfig
extends Resource

## Weapon bank configuration resource for ship templates
## Defines weapon mounting and configuration for specific weapon banks

@export var bank_index: int = 0
@export var bank_type: WeaponBankType.Type = WeaponBankType.Type.PRIMARY
@export var weapon_resource_path: String = ""
@export var ammunition_count: int = -1  # -1 for unlimited (energy weapons)
@export var convergence_distance: float = 500.0
@export var mount_position: Vector3 = Vector3.ZERO
@export var mount_orientation: Vector3 = Vector3.ZERO
@export var firing_group: int = 0

## Validate the weapon bank configuration
func is_valid() -> bool:
	if bank_index < 0:
		return false
	if weapon_resource_path.is_empty():
		return false
	if ammunition_count < -1:
		return false
	if convergence_distance <= 0.0:
		return false
	return true

## Apply configuration to ship class
func apply_to_ship_class(ship_class: ShipClass) -> void:
	match bank_type:
		WeaponBankType.Type.PRIMARY:
			if bank_index < ship_class.primary_weapon_slots.size():
				ship_class.primary_weapon_slots[bank_index] = weapon_resource_path
		WeaponBankType.Type.SECONDARY:
			if bank_index < ship_class.secondary_weapon_slots.size():
				ship_class.secondary_weapon_slots[bank_index] = weapon_resource_path