extends Control
## The meeting room (GAME_DESIGN.md §6.2, "8-bit glory"). Calendar-scheduled
## via MeetingScheduler, never a forced interrupt: this overlay only opens
## when the player chooses to join (on time or late) through the Desk's
## calendar chip. Once joined it locks out the Desk for the meeting's real
## remaining duration -- confirmed design: joining is optional, but
## attending is a real, unskippable block of real time once you're in.

signal resolved(trust_delta: float)

@onready var _status_label: Label = $Room/StatusLabel
@onready var _time_bar: ProgressBar = $Room/TimeBar

var _status: String
var _end_unix: float
var _done: bool = false


func _ready() -> void:
	_status = MeetingScheduler.join_status()
	_end_unix = MeetingScheduler.get_next_meeting_unix() + MeetingScheduler.get_next_meeting_duration()

	_status_label.text = "You're on time." if _status == "on_time" else "You're late."
	_time_bar.min_value = 0.0
	_time_bar.max_value = MeetingScheduler.get_next_meeting_duration()
	set_process(true)


func _process(_delta: float) -> void:
	if _done:
		return

	var now := Time.get_unix_time_from_system()
	var remaining: float = maxf(_end_unix - now, 0.0)
	_time_bar.value = _time_bar.max_value - remaining

	if remaining <= 0.0:
		_done = true
		var delta: float = MeetingScheduler.resolve_attendance(_status)
		resolved.emit(delta)
