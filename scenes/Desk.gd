extends Control
## The idle scene (GAME_DESIGN.md §9): real-time clock, Trust bar, presence
## status, spreadsheet busywork, and the host for task interrupt overlays.

@onready var _clock_label: Label = $ClockLabel
@onready var _trust_bar: ProgressBar = $TrustBar
@onready var _presence_dot: ColorRect = $StatusPanel/PresenceDot
@onready var _task_layer: Control = $TaskLayer

var _forecasting_scene := preload("res://scenes/tasks/ForecastingTask.tscn")
var _active_task: Node = null
var _ending: bool = false


func _ready() -> void:
	TrustManager.trust_changed.connect(_on_trust_changed)
	TrustManager.fired.connect(_on_run_ended)
	Clock.day_advanced.connect(_on_day_advanced)
	Clock.job_abandoned.connect(_on_run_ended)
	ActivityTracker.presence_changed.connect(_on_presence_changed)

	_on_trust_changed(TrustManager.get_trust(), TrustManager.get_ceiling())
	_on_presence_changed(ActivityTracker.get_state())
	_show_pending_missed_notice()

	set_process(true)


func _process(_delta: float) -> void:
	_clock_label.text = Clock.get_time_string()

	if _active_task == null and TaskScheduler.poll_due():
		_start_task()

	if SaveState.is_terminated():
		_go_to_end_screen()


## Per §1.1/§4: reports what already happened (consequence), never a system
## warning about a future rule. Placeholder surface -- print() until a real
## toast/notice UI exists.
func _show_pending_missed_notice() -> void:
	var count: int = SaveState.data.get("pending_missed_count", 0)
	if count > 0:
		print("You weren't at your desk for %d task%s." % [count, "" if count == 1 else "s"])
	SaveState.data["pending_missed_count"] = 0
	SaveState.save()


func _on_trust_changed(new_trust: float, ceiling: float) -> void:
	_trust_bar.max_value = ceiling
	_trust_bar.value = new_trust


func _on_presence_changed(state: String) -> void:
	_presence_dot.color = Color(0.3, 0.8, 0.3) if state == "online" else Color(0.85, 0.75, 0.2)


func _on_day_advanced(_day: int) -> void:
	if SaveState.is_terminated():
		_go_to_end_screen()


func _on_run_ended() -> void:
	_go_to_end_screen()


## Multiple end conditions (Trust hitting 0, abandonment, day-10 win) can all
## notice the same terminated state in the same frame -- guard against
## calling change_scene_to_file more than once.
func _go_to_end_screen() -> void:
	if _ending:
		return
	_ending = true
	get_tree().change_scene_to_file("res://scenes/EndScreen.tscn")


func _start_task() -> void:
	ActivityTracker.set_task_active(true)
	var task := _forecasting_scene.instantiate()
	_task_layer.add_child(task)
	_active_task = task
	task.resolved.connect(_on_task_resolved)


func _on_task_resolved(trust_delta: float) -> void:
	TrustManager.apply_delta(trust_delta)
	ActivityTracker.set_task_active(false)
	TaskScheduler.reschedule_from_now()
	if is_instance_valid(_active_task):
		_active_task.queue_free()
	_active_task = null


## Present Mode toggle (§7.1). Deliberately no label, tooltip, or feedback
## text anywhere near this -- it is reachable only by clicking the status
## panel itself, and the game never explains what it does.
func _on_status_panel_pressed() -> void:
	ActivityTracker.toggle_present_mode()
