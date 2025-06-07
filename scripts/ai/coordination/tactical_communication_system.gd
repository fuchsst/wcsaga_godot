class_name TacticalCommunicationSystem
extends Node

## Tactical communication system for wing coordination with realistic chatter and status updates.
## Manages communication between wing members including orders, status reports, and tactical chatter.

signal message_sent(sender: Node3D, recipients: Array[Node3D], message: TacticalMessage)
signal message_received(sender: Node3D, recipient: Node3D, message: TacticalMessage)
signal communication_established(wing_id: String, participants: Array[Node3D])
signal communication_lost(wing_id: String, reason: String)
signal emergency_broadcast(sender: Node3D, message: TacticalMessage)

## Communication message types
enum MessageType {
	TACTICAL_ORDER,       ## Direct tactical commands
	STATUS_REPORT,        ## Ship/wing status updates  
	TARGET_CALLOUT,       ## Target identification and marking
	THREAT_WARNING,       ## Threat warnings and alerts
	COORDINATION_REQUEST, ## Requests for coordination/assistance
	ACKNOWLEDGMENT,       ## Confirmations and acknowledgments
	CASUAL_CHATTER,       ## Realistic pilot chatter
	EMERGENCY_CALL,       ## Emergency distress calls
	MISSION_UPDATE,       ## Mission-related updates
	FORMATION_COMMAND     ## Formation flying commands
}

## Communication priority levels
enum Priority {
	EMERGENCY,    ## Critical emergency communications
	HIGH,         ## Important tactical information
	MEDIUM,       ## Standard operational communications
	LOW,          ## Non-critical status updates
	BACKGROUND    ## Casual chatter and ambient communication
}

## Communication channels
enum CommChannel {
	WING_COMMAND,    ## Wing leader and command communications
	WING_TACTICAL,   ## Wing tactical coordination
	SHIP_TO_SHIP,    ## Direct ship-to-ship communication
	EMERGENCY,       ## Emergency broadcast channel
	FORMATION,       ## Formation flying coordination
	GENERAL         ## General wing communications
}

## Tactical message structure
class TacticalMessage:
	var message_type: MessageType
	var priority: Priority
	var channel: CommChannel
	var sender: Node3D
	var recipients: Array[Node3D] = []
	var content: String = ""
	var audio_clip: String = ""
	var timestamp: float = 0.0
	var acknowledged: bool = false
	var context_data: Dictionary = {}
	
	func _init(type: MessageType, msg_priority: Priority, msg_channel: CommChannel) -> void:
		message_type = type
		priority = msg_priority
		channel = msg_channel
		timestamp = Time.get_time_dict_from_system()["unix"]

# Communication configuration
@export var communication_range: float = 3000.0
@export var jamming_resistance: float = 0.8
@export var message_queue_limit: int = 50
@export var chatter_frequency: float = 0.3  # How often casual chatter occurs

# Chatter personality settings
@export var personality_variation: float = 0.8
@export var stress_affects_communication: bool = true
@export var experience_affects_chatter: bool = true

# Message management
var message_queue: Array[TacticalMessage] = []
var message_history: Array[TacticalMessage] = []
var pending_acknowledgments: Array[TacticalMessage] = []

# Communication state
var active_channels: Dictionary = {}
var wing_communication_networks: Dictionary = {}
var communication_jamming: float = 0.0

# Chatter and personality
var pilot_personalities: Dictionary = {}
var chatter_templates: Dictionary = {}
var last_chatter_time: float = 0.0

# Dependencies
var wing_coordination_manager: WingCoordinationManager

func _ready() -> void:
	_initialize_communication_system()
	_setup_chatter_templates()
	_initialize_personality_system()

func _initialize_communication_system() -> void:
	# Get wing coordination manager
	wing_coordination_manager = get_node("/root/AIManager/WingCoordinationManager") as WingCoordinationManager
	
	# Initialize communication data
	message_queue.clear()
	message_history.clear()
	pending_acknowledgments.clear()
	active_channels.clear()
	wing_communication_networks.clear()

func _setup_chatter_templates() -> void:
	# Setup chatter templates for different situations
	chatter_templates = {
		"engage_target": [
			"Engaging target, moving to attack position",
			"Target acquired, beginning attack run",
			"I have a lock, going in hot",
			"Tally target, commencing attack",
			"Target in sight, weapons hot"
		],
		"target_destroyed": [
			"Target destroyed, good kill",
			"Splash one enemy fighter",
			"Target eliminated, moving to next",
			"Got him! Target down",
			"Enemy fighter destroyed"
		],
		"taking_damage": [
			"Taking hits! Shield strength critical",
			"I'm hit! Damage to [SYSTEM]",
			"Heavy fire! Need assistance",
			"Taking damage, attempting evasive maneuvers",
			"Shields down! Hull taking damage"
		],
		"low_ammunition": [
			"Running low on ammunition",
			"Weapon stores depleted, need to conserve ammo",
			"Almost out of missiles",
			"Primary weapons at minimum",
			"Need to RTB for rearmament soon"
		],
		"formation_flying": [
			"Formation tight, all ships accounted for",
			"Maintaining formation position",
			"Leader, [CALLSIGN] in position",
			"Formation looks good from here",
			"Holding formation, awaiting orders"
		],
		"enemy_spotted": [
			"Contact! Enemy fighter at [BEARING]",
			"Bandit spotted, [DISTANCE] clicks out",
			"Enemy contact, bearing [BEARING]",
			"I have visual on enemy fighter",
			"Hostile contact, requesting instructions"
		],
		"assistance_request": [
			"Need assistance! Under heavy fire",
			"Request immediate support",
			"I'm in trouble, need backup",
			"Taking heavy hits, need cover fire",
			"Mayday! Requesting emergency assistance"
		],
		"acknowledgment": [
			"Roger that, [LEADER]",
			"Copy, moving to comply",
			"Understood, [CALLSIGN] out",
			"Affirmative, beginning maneuver",
			"Wilco, [LEADER]"
		],
		"status_report": [
			"[CALLSIGN] status green, all systems nominal",
			"Ship status good, ready for orders",
			"All systems operational, standing by",
			"Status report: green across the board",
			"[CALLSIGN] ready and able"
		],
		"mission_complete": [
			"Mission objective complete",
			"Target destroyed, mission successful",
			"Objective accomplished, requesting new orders",
			"Primary mission complete, awaiting instructions",
			"Mission success, returning to base"
		]
	}

func _initialize_personality_system() -> void:
	# Initialize pilot personality traits for communication
	pilot_personalities.clear()

func _process(delta: float) -> void:
	_process_message_queue(delta)
	_update_communication_state(delta)
	_generate_ambient_chatter(delta)
	_check_pending_acknowledgments(delta)

## Sends a tactical message to specified recipients
func send_message(sender: Node3D, recipients: Array[Node3D], message_type: MessageType, content: String, priority: Priority = Priority.MEDIUM, channel: CommChannel = CommChannel.WING_TACTICAL, context: Dictionary = {}) -> TacticalMessage:
	var message: TacticalMessage = TacticalMessage.new(message_type, priority, channel)
	message.sender = sender
	message.recipients = recipients
	message.content = content
	message.context_data = context
	
	# Apply personality and stress effects to message
	if sender in pilot_personalities:
		message.content = _apply_personality_to_message(message, pilot_personalities[sender])
	
	# Add to message queue
	_queue_message(message)
	
	message_sent.emit(sender, recipients, message)
	return message

## Broadcasts a message to all wing members
func broadcast_to_wing(wing_id: String, sender: Node3D, message_type: MessageType, content: String, priority: Priority = Priority.MEDIUM, channel: CommChannel = CommChannel.WING_TACTICAL) -> bool:
	if not wing_coordination_manager:
		return false
	
	var wing_status: Dictionary = wing_coordination_manager.get_wing_status(wing_id)
	var wing_members: Array = wing_status.get("members", [])
	
	if wing_members.is_empty():
		return false
	
	# Convert to Node3D array and remove sender
	var recipients: Array[Node3D] = []
	for member in wing_members:
		var member_node: Node3D = member as Node3D
		if member_node != sender:
			recipients.append(member_node)
	
	send_message(sender, recipients, message_type, content, priority, channel)
	return true

## Sends emergency broadcast to all nearby ships
func send_emergency_broadcast(sender: Node3D, message_type: MessageType, content: String, context: Dictionary = {}) -> TacticalMessage:
	# Get all ships within communication range for emergency broadcast
	var nearby_ships: Array[Node3D] = _get_ships_in_communication_range(sender)
	
	var emergency_message: TacticalMessage = send_message(
		sender, 
		nearby_ships, 
		message_type, 
		content, 
		Priority.EMERGENCY, 
		CommChannel.EMERGENCY, 
		context
	)
	
	emergency_broadcast.emit(sender, emergency_message)
	return emergency_message

## Sends acknowledgment for a received message
func send_acknowledgment(original_message: TacticalMessage, acknowledging_ship: Node3D, response: String = "") -> TacticalMessage:
	var ack_content: String = response
	if ack_content.is_empty():
		ack_content = _generate_acknowledgment_content(original_message, acknowledging_ship)
	
	var ack_message: TacticalMessage = send_message(
		acknowledging_ship,
		[original_message.sender],
		MessageType.ACKNOWLEDGMENT,
		ack_content,
		Priority.LOW,
		original_message.channel
	)
	
	# Mark original message as acknowledged
	original_message.acknowledged = true
	pending_acknowledgments.erase(original_message)
	
	return ack_message

## Generates situational chatter based on current events
func generate_situational_chatter(ship: Node3D, situation: String, context: Dictionary = {}) -> void:
	if not chatter_templates.has(situation):
		return
	
	var templates: Array = chatter_templates[situation]
	if templates.is_empty():
		return
	
	var template: String = templates[randi() % templates.size()]
	var chatter_content: String = _process_chatter_template(template, ship, context)
	
	# Send chatter to wing
	var wing_id: String = _get_ship_wing_id(ship)
	if not wing_id.is_empty():
		broadcast_to_wing(wing_id, ship, MessageType.CASUAL_CHATTER, chatter_content, Priority.BACKGROUND)

## Generates status report for a ship
func generate_status_report(ship: Node3D, automatic: bool = true) -> void:
	var status_data: Dictionary = _collect_ship_status_data(ship)
	var status_content: String = _format_status_report(ship, status_data)
	
	var priority: Priority = Priority.LOW if automatic else Priority.MEDIUM
	var wing_id: String = _get_ship_wing_id(ship)
	
	if not wing_id.is_empty():
		broadcast_to_wing(wing_id, ship, MessageType.STATUS_REPORT, status_content, priority)

## Issues tactical order to specific ships
func issue_tactical_order(commander: Node3D, recipients: Array[Node3D], order: String, context: Dictionary = {}) -> TacticalMessage:
	var order_content: String = _format_tactical_order(order, context)
	
	var order_message: TacticalMessage = send_message(
		commander,
		recipients,
		MessageType.TACTICAL_ORDER,
		order_content,
		Priority.HIGH,
		CommChannel.WING_COMMAND,
		context
	)
	
	# Expect acknowledgment for tactical orders
	pending_acknowledgments.append(order_message)
	
	return order_message

## Reports target callout to wing
func report_target_callout(spotter: Node3D, target: Node3D, callout_info: Dictionary = {}) -> void:
	var callout_content: String = _format_target_callout(target, callout_info)
	
	var wing_id: String = _get_ship_wing_id(spotter)
	if not wing_id.is_empty():
		broadcast_to_wing(wing_id, spotter, MessageType.TARGET_CALLOUT, callout_content, Priority.HIGH)

## Reports threat warning to wing
func report_threat_warning(warner: Node3D, threat: Node3D, threat_info: Dictionary = {}) -> void:
	var warning_content: String = _format_threat_warning(threat, threat_info)
	
	var wing_id: String = _get_ship_wing_id(warner)
	if not wing_id.is_empty():
		broadcast_to_wing(wing_id, warner, MessageType.THREAT_WARNING, warning_content, Priority.HIGH)

## Requests coordination from wing
func request_coordination(requester: Node3D, coordination_type: String, context: Dictionary = {}) -> TacticalMessage:
	var request_content: String = _format_coordination_request(coordination_type, context)
	
	var wing_id: String = _get_ship_wing_id(requester)
	var wing_members: Array[Node3D] = _get_wing_members(wing_id)
	
	return send_message(
		requester,
		wing_members,
		MessageType.COORDINATION_REQUEST,
		request_content,
		Priority.MEDIUM,
		CommChannel.WING_TACTICAL,
		context
	)

func _queue_message(message: TacticalMessage) -> void:
	# Add message to queue with priority handling
	message_queue.append(message)
	
	# Sort by priority (emergency first)
	message_queue.sort_custom(_compare_message_priority)
	
	# Limit queue size
	if message_queue.size() > message_queue_limit:
		message_queue.remove_at(message_queue.size() - 1)

func _compare_message_priority(a: TacticalMessage, b: TacticalMessage) -> bool:
	return a.priority < b.priority  # Lower enum value = higher priority

func _process_message_queue(delta: float) -> void:
	# Process messages from queue
	var messages_to_process: int = min(3, message_queue.size())  # Process up to 3 per frame
	
	for i in range(messages_to_process):
		var message: TacticalMessage = message_queue.pop_front()
		_deliver_message(message)

func _deliver_message(message: TacticalMessage) -> void:
	# Deliver message to recipients
	for recipient in message.recipients:
		if _can_receive_message(message.sender, recipient):
			_process_message_delivery(message, recipient)
			message_received.emit(message.sender, recipient, message)

func _process_message_delivery(message: TacticalMessage, recipient: Node3D) -> void:
	# Process the actual message delivery
	message_history.append(message)
	
	# Limit history size
	if message_history.size() > 100:
		message_history.remove_at(0)
	
	# Generate automatic responses for certain message types
	_generate_automatic_response(message, recipient)

func _generate_automatic_response(message: TacticalMessage, recipient: Node3D) -> void:
	# Generate automatic responses to certain messages
	match message.message_type:
		MessageType.TACTICAL_ORDER:
			# Auto-acknowledge tactical orders
			call_deferred("send_acknowledgment", message, recipient)
		MessageType.THREAT_WARNING:
			# Sometimes acknowledge threat warnings
			if randf() < 0.6:
				var response: String = _generate_threat_acknowledgment(message, recipient)
				call_deferred("send_acknowledgment", message, recipient, response)
		MessageType.COORDINATION_REQUEST:
			# Respond to coordination requests
			var response: String = _generate_coordination_response(message, recipient)
			if not response.is_empty():
				call_deferred("send_message", recipient, [message.sender], MessageType.ACKNOWLEDGMENT, response)

func _update_communication_state(delta: float) -> void:
	# Update communication system state
	_update_jamming_effects(delta)
	_check_communication_range()
	_update_channel_status()

func _generate_ambient_chatter(delta: float) -> void:
	# Generate ambient chatter periodically
	var current_time: float = Time.get_time_dict_from_system()["unix"]
	
	if current_time - last_chatter_time < (1.0 / chatter_frequency):
		return
	
	last_chatter_time = current_time
	
	# Randomly select a ship to generate chatter
	var all_ships: Array[Node3D] = _get_all_active_ships()
	if all_ships.is_empty():
		return
	
	var chatter_ship: Node3D = all_ships[randi() % all_ships.size()]
	var chatter_situation: String = _determine_chatter_situation(chatter_ship)
	
	if not chatter_situation.is_empty():
		generate_situational_chatter(chatter_ship, chatter_situation)

func _check_pending_acknowledgments(delta: float) -> void:
	# Check for overdue acknowledgments
	var current_time: float = Time.get_time_dict_from_system()["unix"]
	
	for message in pending_acknowledgments:
		if current_time - message.timestamp > 10.0:  # 10 second timeout
			# Message not acknowledged, handle appropriately
			_handle_unacknowledged_message(message)

func _handle_unacknowledged_message(message: TacticalMessage) -> void:
	# Handle messages that weren't acknowledged
	pending_acknowledgments.erase(message)
	
	# Could trigger follow-up actions, repeat message, etc.
	push_warning("Tactical message not acknowledged: " + message.content)

# Message content generation functions
func _apply_personality_to_message(message: TacticalMessage, personality: Dictionary) -> String:
	# Apply pilot personality to message content
	var content: String = message.content
	
	# Apply stress effects
	if stress_affects_communication:
		var stress_level: float = personality.get("stress_level", 0.0)
		if stress_level > 0.7:
			content = _apply_stress_effects_to_content(content)
	
	# Apply experience effects
	if experience_affects_chatter:
		var experience: float = personality.get("experience", 0.5)
		if experience < 0.3:
			content = _apply_rookie_speech_patterns(content)
		elif experience > 0.8:
			content = _apply_veteran_speech_patterns(content)
	
	return content

func _process_chatter_template(template: String, ship: Node3D, context: Dictionary) -> String:
	# Process chatter template with ship and context data
	var processed: String = template
	
	# Replace placeholders
	processed = processed.replace("[CALLSIGN]", _get_ship_callsign(ship))
	processed = processed.replace("[LEADER]", _get_wing_leader_callsign(ship))
	
	if context.has("bearing"):
		processed = processed.replace("[BEARING]", str(context["bearing"]))
	if context.has("distance"):
		processed = processed.replace("[DISTANCE]", str(context["distance"]))
	if context.has("system"):
		processed = processed.replace("[SYSTEM]", context["system"])
	
	return processed

func _format_status_report(ship: Node3D, status_data: Dictionary) -> String:
	# Format ship status report
	var callsign: String = _get_ship_callsign(ship)
	var health: int = int(status_data.get("health", 1.0) * 100)
	var ammo: int = int(status_data.get("ammunition", 1.0) * 100)
	var systems: String = status_data.get("systems", "green")
	
	return "%s status: Hull %d%%, ammo %d%%, systems %s" % [callsign, health, ammo, systems]

func _format_tactical_order(order: String, context: Dictionary) -> String:
	# Format tactical order message
	var formatted_order: String = order
	
	# Add context information if available
	if context.has("target"):
		formatted_order += " on designated target"
	if context.has("position"):
		formatted_order += " at specified coordinates"
	
	return formatted_order

func _format_target_callout(target: Node3D, callout_info: Dictionary) -> String:
	# Format target callout message
	var target_type: String = callout_info.get("type", "enemy fighter")
	var bearing: String = callout_info.get("bearing", "unknown")
	var distance: String = callout_info.get("distance", "unknown")
	
	return "Contact! %s, bearing %s, distance %s" % [target_type, bearing, distance]

func _format_threat_warning(threat: Node3D, threat_info: Dictionary) -> String:
	# Format threat warning message
	var threat_type: String = threat_info.get("type", "hostile")
	var severity: String = threat_info.get("severity", "moderate")
	
	return "Warning! %s threat detected, %s danger level" % [threat_type, severity]

func _format_coordination_request(coordination_type: String, context: Dictionary) -> String:
	# Format coordination request
	return "Requesting %s coordination" % [coordination_type]

func _generate_acknowledgment_content(original_message: TacticalMessage, acknowledging_ship: Node3D) -> String:
	# Generate acknowledgment content
	var templates: Array = chatter_templates.get("acknowledgment", ["Roger"])
	var template: String = templates[randi() % templates.size()]
	
	return _process_chatter_template(template, acknowledging_ship, {})

func _generate_threat_acknowledgment(message: TacticalMessage, recipient: Node3D) -> String:
	# Generate acknowledgment for threat warning
	return "Copy threat warning, %s" % [_get_ship_callsign(recipient)]

func _generate_coordination_response(message: TacticalMessage, recipient: Node3D) -> String:
	# Generate response to coordination request
	return "Standing by for coordination, %s ready" % [_get_ship_callsign(recipient)]

# Helper functions
func _can_receive_message(sender: Node3D, recipient: Node3D) -> bool:
	# Check if recipient can receive message from sender
	if not is_instance_valid(sender) or not is_instance_valid(recipient):
		return false
	
	# Check communication range
	var distance: float = sender.global_position.distance_to(recipient.global_position)
	if distance > communication_range:
		return false
	
	# Check jamming effects
	if communication_jamming > randf():
		return false
	
	return true

func _get_ships_in_communication_range(center_ship: Node3D) -> Array[Node3D]:
	# Get all ships within communication range
	var nearby_ships: Array[Node3D] = []
	
	# This would interface with the ship tracking system
	# For now, return empty array
	
	return nearby_ships

func _get_ship_wing_id(ship: Node3D) -> String:
	# Get wing ID for ship
	if wing_coordination_manager:
		for wing_id in wing_coordination_manager.get_active_wings():
			var wing_status: Dictionary = wing_coordination_manager.get_wing_status(wing_id)
			var members: Array = wing_status.get("members", [])
			if ship in members:
				return wing_id
	return ""

func _get_wing_members(wing_id: String) -> Array[Node3D]:
	# Get wing members
	if not wing_coordination_manager or wing_id.is_empty():
		return []
	
	var wing_status: Dictionary = wing_coordination_manager.get_wing_status(wing_id)
	return wing_status.get("members", [])

func _get_ship_callsign(ship: Node3D) -> String:
	# Get ship callsign
	return ship.name  # Placeholder

func _get_wing_leader_callsign(ship: Node3D) -> String:
	# Get wing leader callsign
	var wing_id: String = _get_ship_wing_id(ship)
	if wing_id.is_empty():
		return "Leader"
	
	if wing_coordination_manager:
		var wing_status: Dictionary = wing_coordination_manager.get_wing_status(wing_id)
		var leader: Node3D = wing_status.get("leader")
		if leader:
			return _get_ship_callsign(leader)
	
	return "Leader"

func _collect_ship_status_data(ship: Node3D) -> Dictionary:
	# Collect ship status data
	return {
		"health": 1.0,
		"ammunition": 1.0,
		"systems": "green"
	}

func _get_all_active_ships() -> Array[Node3D]:
	# Get all active ships for chatter generation
	var ships: Array[Node3D] = []
	
	if wing_coordination_manager:
		for wing_id in wing_coordination_manager.get_active_wings():
			var wing_members: Array[Node3D] = _get_wing_members(wing_id)
			ships.append_array(wing_members)
	
	return ships

func _determine_chatter_situation(ship: Node3D) -> String:
	# Determine what situation the ship is in for chatter
	var situations: Array[String] = ["formation_flying", "status_report"]
	return situations[randi() % situations.size()]

func _apply_stress_effects_to_content(content: String) -> String:
	# Apply stress effects to speech
	return content  # Placeholder

func _apply_rookie_speech_patterns(content: String) -> String:
	# Apply rookie speech patterns
	return content  # Placeholder

func _apply_veteran_speech_patterns(content: String) -> String:
	# Apply veteran speech patterns
	return content  # Placeholder

func _update_jamming_effects(delta: float) -> void:
	# Update communication jamming effects
	pass

func _check_communication_range() -> void:
	# Check communication range for all active networks
	pass

func _update_channel_status() -> void:
	# Update communication channel status
	pass

## Sets pilot personality for communication
func set_pilot_personality(ship: Node3D, personality: Dictionary) -> void:
	pilot_personalities[ship] = personality

## Sets communication jamming level
func set_jamming_level(jamming: float) -> void:
	communication_jamming = clamp(jamming, 0.0, 1.0)

## Gets communication statistics
func get_communication_statistics() -> Dictionary:
	return {
		"messages_sent": message_history.size(),
		"pending_acknowledgments": pending_acknowledgments.size(),
		"active_channels": active_channels.size(),
		"jamming_level": communication_jamming,
		"communication_range": communication_range
	}