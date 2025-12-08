@tool
extends RefCounted
class_name SexpDefinitions

## SEXP operator definitions for compilation to BehaviorTree
## Maps SEXP operator names to their BT node types

const OPS = {
	# ===============================
	# LOGICAL / STRUCTURAL OPERATORS
	# ===============================
	"and": {"type": "logic", "bt_type": "BTSequence"},
	"or": {"type": "logic", "bt_type": "BTSelector"},
	"not": {"type": "logic", "bt_type": "BTInverter"},
	"when": {"type": "special", "handler": "_compile_when"},
	"cond": {"type": "special", "handler": "_compile_cond"},
	"every-time": {"type": "special", "handler": "_compile_when"},  # Alias
	"every-time-argument": {"type": "special", "handler": "_compile_when"},
	# ===============================
	# BOOLEAN ATOMS
	# ===============================
	"true": {"type": "condition", "always": true},
	"false": {"type": "condition", "always": false},
	# ===============================
	# SHIP/OBJECT STATE CONDITIONS
	# ===============================
	"is-destroyed": {"type": "condition"},
	"is-subsystem-destroyed": {"type": "condition"},
	"is-disabled": {"type": "condition"},
	"is-disarmed": {"type": "condition"},
	"has-arrived": {"type": "condition"},
	"has-arrived-delay": {"type": "condition"},
	"has-departed": {"type": "condition"},
	"has-departed-delay": {"type": "condition"},
	"is-docked": {"type": "condition"},
	"is-undocked": {"type": "condition"},
	"has-docked": {"type": "condition"},
	"has-undocked": {"type": "condition"},
	"is-cargo-known": {"type": "condition"},
	"is-in-mission": {"type": "condition"},
	"is-ship-visible": {"type": "condition"},
	"is-ship-stealthy": {"type": "condition"},
	"is-friendly-stealth-visible": {"type": "condition"},
	# ===============================
	# COMPARISON CONDITIONS
	# ===============================
	"=": {"type": "condition"},
	"<": {"type": "condition"},
	">": {"type": "condition"},
	"<=": {"type": "condition"},
	">=": {"type": "condition"},
	"string=": {"type": "condition"},
	# ===============================
	# NUMERIC/VALUE CONDITIONS
	# ===============================
	"hits-left": {"type": "condition"},
	"hits-left-subsystem": {"type": "condition"},
	"shields-left": {"type": "condition"},
	"distance": {"type": "condition"},
	"speed": {"type": "condition"},
	"time-elapsed": {"type": "condition"},
	"time-ship-destroyed": {"type": "condition"},
	"time-wing-destroyed": {"type": "condition"},
	"time-ship-arrived": {"type": "condition"},
	"time-wing-arrived": {"type": "condition"},
	"time-ship-departed": {"type": "condition"},
	"time-wing-departed": {"type": "condition"},
	"num-ships-in-battle": {"type": "condition"},
	"num-ships-in-wing": {"type": "condition"},
	"primary-ammo-pct": {"type": "condition"},
	"secondary-ammo-pct": {"type": "condition"},
	"weapon-energy-pct": {"type": "condition"},
	"afterburner-energy-pct": {"type": "condition"},
	"get-hull-pct": {"type": "condition"},
	"get-shield-pct": {"type": "condition"},
	# ===============================
	# GOAL/EVENT CONDITIONS
	# ===============================
	"is-event-true": {"type": "condition"},
	"is-event-true-delay": {"type": "condition"},
	"is-event-false": {"type": "condition"},
	"is-event-false-delay": {"type": "condition"},
	"is-event-incomplete": {"type": "condition"},
	"is-goal-true-delay": {"type": "condition"},
	"is-goal-false-delay": {"type": "condition"},
	"is-goal-incomplete": {"type": "condition"},
	"is-previous-event-true": {"type": "condition"},
	"is-previous-event-false": {"type": "condition"},
	"is-previous-event-incomplete": {"type": "condition"},
	"is-previous-goal-true": {"type": "condition"},
	"is-previous-goal-false": {"type": "condition"},
	"is-previous-goal-incomplete": {"type": "condition"},
	# ===============================
	# WAYPOINT CONDITIONS
	# ===============================
	"is-waypoint-visited": {"type": "condition"},
	"waypoints-done": {"type": "condition"},
	"waypoint-distance": {"type": "condition"},
	# ===============================
	# PLAYER CONDITIONS
	# ===============================
	"was-promotion-granted": {"type": "condition"},
	"was-medal-granted": {"type": "condition"},
	"player-is-cheating": {"type": "condition"},
	"skill-level-at-least": {"type": "condition"},
	# ===============================
	# MISSION ACTIONS
	# ===============================
	"do-nothing": {"type": "action"},
	"end-mission": {"type": "action"},
	"end-campaign": {"type": "action"},
	"end-of-campaign": {"type": "action"},
	"next-mission": {"type": "action"},
	"invalidate-goal": {"type": "action"},
	"validate-goal": {"type": "action"},
	"set-training-context-speed": {"type": "action"},
	"key-pressed": {"type": "action"},
	# ===============================
	# MESSAGE ACTIONS
	# ===============================
	"send-message": {"type": "action"},
	"send-message-list": {"type": "action"},
	"send-random-message": {"type": "action"},
	"training-msg": {"type": "action"},
	"self-destruct": {"type": "action"},
	# ===============================
	# SHIP MANIPULATION ACTIONS
	# ===============================
	"add-goal": {"type": "action"},
	"remove-goal": {"type": "action"},
	"add-ship-goal": {"type": "action"},
	"add-wing-goal": {"type": "action"},
	"clear-goals": {"type": "action"},
	"clear-ship-goals": {"type": "action"},
	"clear-wing-goals": {"type": "action"},
	"change-ai-class": {"type": "action"},
	"protect-ship": {"type": "action"},
	"unprotect-ship": {"type": "action"},
	"beam-protect-ship": {"type": "action"},
	"beam-unprotect-ship": {"type": "action"},
	"make-invulnerable": {"type": "action"},
	"make-vulnerable": {"type": "action"},
	"ship-invulnerable": {"type": "action"},
	"ship-vulnerable": {"type": "action"},
	"shields-on": {"type": "action"},
	"shields-off": {"type": "action"},
	"ship-guardian": {"type": "action"},
	"ship-no-guardian": {"type": "action"},
	"ship-stealthy": {"type": "action"},
	"ship-unstealthy": {"type": "action"},
	"friendly-stealth-invisible": {"type": "action"},
	"friendly-stealth-visible": {"type": "action"},
	"sabotage-subsystem": {"type": "action"},
	"repair-subsystem": {"type": "action"},
	"destroy-subsystem": {"type": "action"},
	"transfer-cargo": {"type": "action"},
	"set-cargo": {"type": "action"},
	"set-special-warp-dist": {"type": "action"},
	"set-support-ship": {"type": "action"},
	# ===============================
	# ARRIVAL/DEPARTURE ACTIONS
	# ===============================
	"warp-in": {"type": "action"},
	"warp-out": {"type": "action"},
	"ship-create": {"type": "action"},
	"ship-vanish": {"type": "action"},
	"ship-vaporize": {"type": "action"},
	"ship-soundigger": {"type": "action"},
	"change-ship-class": {"type": "action"},
	# ===============================
	# VARIABLE ACTIONS
	# ===============================
	"set-variable": {"type": "action"},
	"modify-variable": {"type": "action"},
	# ===============================
	# CAMERA/HUD ACTIONS
	# ===============================
	"hud-set-text": {"type": "action"},
	"hud-set-message": {"type": "action"},
	"hud-set-directive": {"type": "action"},
	"hud-clear-messages": {"type": "action"},
	"flash-hud-gauge": {"type": "action"},
	"set-hud-color": {"type": "action"},
	"set-hud-visibility": {"type": "action"},
	"red-alert": {"type": "action"},
	# ===============================
	# MUSIC/AUDIO ACTIONS
	# ===============================
	"change-music": {"type": "action"},
	"pause-music": {"type": "action"},
	"force-battle-music": {"type": "action"},
	# ===============================
	# SCORING ACTIONS
	# ===============================
	"grant-promotion": {"type": "action"},
	"grant-medal": {"type": "action"},
	# ===============================
	# TEAM/IFF ACTIONS
	# ===============================
	"change-iff": {"type": "action"},
	"change-team-color": {"type": "action"},
	"add-to-team": {"type": "action"},
	"remove-from-team": {"type": "action"},
}


static func get_op(name: String) -> Dictionary:
	return OPS.get(name, {"type": "unknown"})


static func is_condition(name: String) -> bool:
	var op = get_op(name)
	return op.get("type", "") == "condition"


static func is_action(name: String) -> bool:
	var op = get_op(name)
	return op.get("type", "") == "action"


static func is_logic(name: String) -> bool:
	var op = get_op(name)
	return op.get("type", "") == "logic"
