class_name GameStateIntro
extends LimboState

## Intro State - Splash screens and intro video


func _enter() -> void:
	print("Entering Intro State")
	# Skip intro for now, go directly to campaign select
	var gsm := get_parent()
	if gsm and gsm.has_method("dispatch"):
		gsm.dispatch(&"to_campaign_select")


func _exit() -> void:
	print("Exiting Intro State")
