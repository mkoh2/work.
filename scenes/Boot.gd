extends Control
## Title/boot screen (GAME_DESIGN.md §9). Runs the §4/§4.1 relaunch
## reconciliation once, then routes to the Desk scene or straight to the
## end screen if the reconciliation itself ended the run (job abandonment,
## or the run was already terminated from a prior session).

@onready var _status_label: Label = $StatusLabel


func _ready() -> void:
	_status_label.text = "..."
	# One frame so the label above actually paints before any heavier work.
	await get_tree().process_frame

	var result := Clock.reconcile_on_launch()
	SaveState.data["pending_missed_count"] = result.get("missed_task_penalties", []).size()
	SaveState.save()

	var state: String = SaveState.data.get("run_state", "active")
	if state == "active":
		get_tree().change_scene_to_file("res://scenes/Desk.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/EndScreen.tscn")
