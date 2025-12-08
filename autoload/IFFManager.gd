# IFFManager - Identification Friend or Foe System Manager
# Autoload singleton for managing team relationships, colors, and attack masks
# Based on legacy iff_defs.cpp functionality

extends Node

## Emitted when IFF data is loaded or reloaded
signal iff_data_loaded

# ==============================================================================
# REGISTRY (typed arrays as per implementation plan)
# ==============================================================================

## All registered IFF definitions
@export var iff_registry: Array[IFFResource] = []

## The traitor IFF (special handling)
@export var traitor_iff: IFFResource = null

## Radar color configuration
@export var radar_colors: RadarColorConfig = null

## Global IFF settings from manifest
var selection_color: Color = Color.WHITE
var message_color: Color = Color(0.5, 0.5, 0.5)
var tagged_color: Color = Color.YELLOW
var dimmed_brightness: int = 4
var use_alternate_blip_coloring: bool = false

# ==============================================================================
# INTERNAL STATE
# ==============================================================================

## Whether "all teams at war" mission modifier is active
var all_teams_at_war: bool = false

## Cache of computed attack bitmasks (team_name -> bitmask)
var _attack_masks: Dictionary = {}

## Map of IFF name to index for bitmask operations
var _iff_name_to_index: Dictionary = {}

# ==============================================================================
# INITIALIZATION
# ==============================================================================


func _ready() -> void:
	print("IFFManager: Initializing...")


## Load IFF definitions from a manifest resource
func load_from_manifest(manifest: IFFManifest) -> void:
	if not manifest:
		push_error("IFFManager: Cannot load null manifest")
		return

	# Clear existing data
	iff_registry.clear()
	_attack_masks.clear()
	_iff_name_to_index.clear()
	traitor_iff = null

	# Copy settings from manifest
	selection_color = manifest.selection_color
	message_color = manifest.message_color
	tagged_color = manifest.tagged_color
	dimmed_brightness = manifest.dimmed_iff_brightness
	use_alternate_blip_coloring = manifest.use_alternate_blip_coloring

	# Build radar color config if not already set
	if not radar_colors:
		radar_colors = RadarColorConfig.new()
		radar_colors.missile_bright = manifest.missile_blip_color
		radar_colors.navbuoy_bright = manifest.navbuoy_blip_color
		radar_colors.warping_bright = manifest.warping_blip_color
		radar_colors.node_bright = manifest.node_blip_color
		radar_colors.tagged_bright = manifest.tagged_blip_color

	# Register all IFFs and build name-to-index mapping
	for i in range(manifest.iffs.size()):
		var iff: IFFResource = manifest.iffs[i]
		if iff:
			iff_registry.append(iff)
			_iff_name_to_index[iff.iff_name] = i

			# Check for traitor
			if iff.iff_name == manifest.traitor_iff_name:
				traitor_iff = iff

	# Compute attack bitmasks for all IFFs
	_compute_attack_masks()

	print("IFFManager: Loaded %d IFFs from manifest" % iff_registry.size())
	iff_data_loaded.emit()


## Load IFF definitions from a resource path
func load_from_path(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("IFFManager: Manifest not found at: %s" % path)
		return

	var manifest: IFFManifest = ResourceLoader.load(path) as IFFManifest
	load_from_manifest(manifest)


# ==============================================================================
# LOOKUP API
# ==============================================================================


## Get IFF resource by name
func get_iff(iff_name: String) -> IFFResource:
	for iff in iff_registry:
		if iff.iff_name == iff_name:
			return iff
	return null


## Get IFF by index
func get_iff_by_index(index: int) -> IFFResource:
	if index >= 0 and index < iff_registry.size():
		return iff_registry[index]
	return null


## Get index of an IFF by name
func get_iff_index(iff_name: String) -> int:
	return _iff_name_to_index.get(iff_name, -1)


# ==============================================================================
# ATTACK RELATIONSHIP API
# ==============================================================================


## Check if attacker attacks target
func attacks(attacker: IFFResource, target: IFFResource) -> bool:
	if not attacker or not target:
		return false

	# Check if target is in attacker's attacks list
	return target.iff_name in attacker.attacks


## Check if attacker_name attacks target_name (convenience)
func attacks_by_name(attacker_name: String, target_name: String) -> bool:
	var attacker := get_iff(attacker_name)
	var target := get_iff(target_name)
	return attacks(attacker, target)


## Get bitmask of all teams that attacker attacks
func get_attackee_mask(attacker: IFFResource) -> int:
	if not attacker:
		return 0

	if all_teams_at_war:
		return _get_all_teams_at_war_mask(attacker)

	return _attack_masks.get(attacker.iff_name, 0)


## Check if target matches the attackee bitmask
func matches_mask(target: IFFResource, mask: int) -> bool:
	if not target:
		return false
	var index := get_iff_index(target.iff_name)
	if index < 0:
		return false
	return (mask & (1 << index)) != 0


# ==============================================================================
# COLOR API
# ==============================================================================


## Get the color for a team as seen by another team
func get_color(team: IFFResource, seen_from: IFFResource = null, bright: bool = false) -> Color:
	if not team:
		return Color.WHITE

	var base_color: Color = team.color

	# Check if seen_from perceives this team differently
	if seen_from:
		for perception in seen_from.perceptions:
			if perception.target_iff_name == team.iff_name:
				base_color = perception.perceived_color
				break

	# Apply brightness
	if not bright:
		base_color = base_color.darkened(0.3)

	return base_color


## Get radar blip color by type
func get_radar_color(blip_type: int, bright: bool = false) -> Color:
	if radar_colors:
		return radar_colors.get_blip_color(blip_type, bright)
	return Color.WHITE


## Check if an IFF is the traitor
func is_traitor(iff: IFFResource) -> bool:
	if not iff or not traitor_iff:
		return false
	return iff.iff_name == traitor_iff.iff_name


# ==============================================================================
# MISSION MODIFIERS
# ==============================================================================


## Enable/disable "All Teams At War" mission modifier
func set_all_teams_at_war(enabled: bool) -> void:
	all_teams_at_war = enabled


# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================


## Compute attack bitmasks for all IFFs
func _compute_attack_masks() -> void:
	_attack_masks.clear()

	for iff in iff_registry:
		var mask: int = 0
		for target_name in iff.attacks:
			var target_index := get_iff_index(target_name)
			if target_index >= 0:
				mask |= (1 << target_index)
		_attack_masks[iff.iff_name] = mask


## Get attack mask when "All Teams At War" is active
func _get_all_teams_at_war_mask(attacker: IFFResource) -> int:
	# Exempt IFFs only attack their normal targets
	if IFFResource.IFFFlags.EXEMPT_FROM_ALL_TEAMS_AT_WAR in attacker.flags:
		return _attack_masks.get(attacker.iff_name, 0)

	# Non-exempt IFFs attack all other non-exempt IFFs
	var mask: int = 0
	var attacker_index := get_iff_index(attacker.iff_name)

	for i in range(iff_registry.size()):
		var other := iff_registry[i]

		# Skip self (unless normally attacks self)
		if i == attacker_index and not attacks(attacker, attacker):
			continue

		# Skip exempt IFFs
		if IFFResource.IFFFlags.EXEMPT_FROM_ALL_TEAMS_AT_WAR in other.flags:
			continue

		mask |= (1 << i)

	return mask
