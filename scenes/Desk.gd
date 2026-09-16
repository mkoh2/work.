extends Control
## The idle scene (GAME_DESIGN.md §9): real-time clock, Trust bar, presence
## status, spreadsheet busywork, the calendar-meeting chip, and the host
## for task/meeting overlays.

@onready var _clock_label: Label = $ClockLabel
@onready var _trust_bar: ProgressBar = $TrustBar
@onready var _presence_dot: ColorRect = $StatusPanel/PresenceDot
@onready var _task_layer: Control = $TaskLayer
@onready var _calendar_chip: Button = $CalendarChip

var _forecasting_scene := preload("res://scenes/tasks/ForecastingTask.tscn")
var _meeting_scene := preload("res://scenes/tasks/Meeting.tscn")

var _active_task: Node = null
var _active_meeting: Node = null
var _meeting_window_start: float = 0.0
var _meeting_window_end: float = 0.0
var _ending: bool = false


func _ready() -> void:
	TrustManager.trust_changed.connect(_on_trust_changed)
	TrustManager.fired.connect(_on_run_ended)
	Clock.day_advanced.connect(_on_day_advanced)
	Clock.job_abandoned.connect(_on_run_ended)
	ActivityTracker.presence_changed.connect(_on_presence_changed)
	_calendar_chip.pressed.connect(_on_calendar_chip_pressed)

	_on_trust_changed(TrustManager.get_trust(), TrustManager.get_ceiling())
	_on_presence_changed(ActivityTracker.get_state())
	_show_pending_missed_notice()

	set_process(true)


func _process(_delta: float) -> void:
	_clock_label.text = Clock.get_time_string()
	_update_calendar_chip()

	var overlay_busy: bool = _active_task != null or _active_meeting != null
	if not overlay_busy and TaskScheduler.poll_due():
		_start_task()

	if SaveState.is_terminated():
		_go_to_end_screen()


## The calendar chip is only clickable once the meeting window has actually
## opened -- per §1.1, nothing warns the player a meeting is coming, it
## just becomes joinable when it's time (a real calendar reminder existing
## in the world is fine; a system telling the player what to do about it
## is not). Visible-but-disabled beforehand so the chip isn't a mystery.
func _update_calendar_chip() -> void:
	if _active_meeting != null:
		_calendar_chip.disabled = true
		return
	var live := MeetingScheduler.is_meeting_live()
	_calendar_chip.disabled = not live
	_calendar_chip.modulate = Color(1, 1, 1, 1) if live else Color(1, 1, 1, 0.4)


func _on_calendar_chip_pressed() -> void:
	if _active_task != null or _active_meeting != null:
		return
	if not MeetingScheduler.is_meeting_live():
		return
	_start_meeting()


## Per §1.1/§4: reports what already happened (consequence), never a system
## warning about a future rule. Placeholder surface -- print() until a real
## toast/notice UI exists.
func _show_pending_missed_notice() -> void:
	var count: int = SaveState.data.get("pending_missed_count", 0)
	if count > 0:
		print("You weren't at your desk for %d task%s." % [count, "" if count == 1 else "s"])
	var missed_meetings: int = SaveState.data.get("pending_missed_meetings", 0)
	if missed_meetings > 0:
		print("You missed %d meeting%s." % [missed_meetings, "" if missed_meetings == 1 else "s"])
	SaveState.data["pending_missed_count"] = 0
	SaveState.data["pending_missed_meetings"] = 0
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


func _start_meeting() -> void:
	ActivityTracker.set_task_active(true)
	_meeting_window_start = Time.get_unix_time_from_system()
	_meeting_window_end = MeetingScheduler.get_next_meeting_unix() + MeetingScheduler.get_next_meeting_duration()
	var meeting := _meeting_scene.instantiate()
	_task_layer.add_child(meeting)
	_active_meeting = meeting
	meeting.resolved.connect(_on_meeting_resolved)


func _on_meeting_resolved(trust_delta: float) -> void:
	TrustManager.apply_delta(trust_delta)

	# Tasks that would have fired while locked in the meeting count as
	# missed too -- attending really does cost you your desk work, the
	# same reconciliation path as being away entirely (§4). Covers only
	# the actual time spent inside the overlay, not the full scheduled
	# meeting window, so joining late doesn't retroactively penalize time
	# the player was free to handle tasks normally.
	var missed: Array = TaskScheduler.consume_missed_tasks(_meeting_window_start, _meeting_window_end)
	for penalty in missed:
		TrustManager.apply_delta(penalty)

	ActivityTracker.set_task_active(false)
	if is_instance_valid(_active_meeting):
		_active_meeting.queue_free()
	_active_meeting = null


## Present Mode toggle (§7.1). Deliberately no label, tooltip, or feedback
## text anywhere near this -- it is reachable only by clicking the status
## panel itself, and the game never explains what it does.
func _on_status_panel_pressed() -> void:
	ActivityTracker.toggle_present_mode()
