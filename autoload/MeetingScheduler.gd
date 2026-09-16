extends Node
## Calendar-scheduled meetings (GAME_DESIGN.md §6.2 -- new task type).
## Unlike TaskScheduler's randomized interrupts, a meeting is a fixed
## real-time calendar event: a start time and a duration, one per weekday,
## not drawn from a rolling interval. Confirmed design: the player can join
## on time, join late, or skip entirely -- nothing forces attendance, but
## joining does lock out the Desk/tasks for the remainder of the meeting.

signal meeting_resolved(status: String, trust_delta: float) # "on_time" | "late" | "missed"

const MEETING_WEEKDAYS := [
	Time.WEEKDAY_MONDAY, Time.WEEKDAY_TUESDAY, Time.WEEKDAY_WEDNESDAY,
	Time.WEEKDAY_THURSDAY, Time.WEEKDAY_FRIDAY,
] # none on weekends by default -- same open weekend question as §6.3

const WORK_HOUR_START := 9
const WORK_HOUR_END := 17
const MIN_DURATION := 15.0 * 60.0
const MAX_DURATION := 30.0 * 60.0
const LATE_GRACE := 3.0 * 60.0 # joining within this long after start still counts on time

const LATE_PENALTY := -3.0
const MISSED_PENALTY := -8.0 # within the §5 -8..-20 bad-task range

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if SaveState.data.get("next_meeting_unix", 0.0) == 0.0:
		_schedule_next(Time.get_unix_time_from_system())


func get_next_meeting_unix() -> float:
	return SaveState.data.get("next_meeting_unix", 0.0)


func get_next_meeting_duration() -> float:
	return SaveState.data.get("next_meeting_duration", MIN_DURATION)


func is_meeting_live(now: float = -1.0) -> bool:
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	var start: float = get_next_meeting_unix()
	return now >= start and now < start + get_next_meeting_duration()


func has_meeting_window_passed(now: float = -1.0) -> bool:
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	var start: float = get_next_meeting_unix()
	return start > 0.0 and now >= start + get_next_meeting_duration()


## Called by Clock.reconcile_on_launch() and by Desk's live loop. If the
## current meeting's window fully passed without the player ever joining,
## it's missed -- same "catch up on what happened while you weren't
## looking" pattern as §4's missed tasks. Returns the penalty applied, or
## 0.0 if there was nothing to reconcile.
func reconcile() -> float:
	if has_meeting_window_passed():
		return resolve_attendance("missed")
	return 0.0


## Called when the player clicks to join, so the Meeting scene can reflect
## whether this is an on-time or late join. The actual Trust delta is
## applied at resolve_attendance() when the meeting ends, not at join time.
func join_status(now: float = -1.0) -> String:
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	return "on_time" if (now - get_next_meeting_unix()) <= LATE_GRACE else "late"


## Called when a meeting concludes: the player sat through it (status
## already known from join_status()), or the window passed unattended
## (status = "missed", via reconcile()). Schedules the next meeting and
## returns the Trust delta to apply.
func resolve_attendance(status: String) -> float:
	var delta: float = 0.0
	match status:
		"on_time":
			delta = 0.0 # attendance is expected, not rewarded -- see §6.2
		"late":
			delta = LATE_PENALTY
		"missed":
			delta = MISSED_PENALTY
	meeting_resolved.emit(status, delta)
	_schedule_next(get_next_meeting_unix() + get_next_meeting_duration())
	return delta


## Steps forward in whole days via unix-epoch arithmetic only -- never by
## mutating a calendar dict's "day" field directly. Confirmed against the
## real engine: Time.get_unix_time_from_datetime_dict() does NOT normalize
## an out-of-range day across a month boundary, it errors and returns 0 --
## an earlier draft of this function would have silently scheduled
## meetings in 1970 the first time it crossed a month end. Always starts
## the search tomorrow (never "later today"), which keeps this simple at
## the cost of the very first meeting of a fresh run not landing on day 1.
func _schedule_next(after_unix: float) -> void:
	var after_local := Clock.local_datetime_from_unix(after_unix)
	var midnight_dt := after_local.duplicate()
	midnight_dt["hour"] = 0
	midnight_dt["minute"] = 0
	midnight_dt["second"] = 0
	var midnight_unix: float = Clock.unix_from_local_datetime(midnight_dt)

	for offset_days in range(1, 15): # MEETING_WEEKDAYS always hits within 7
		var candidate_midnight: float = midnight_unix + offset_days * Clock.SECONDS_PER_DAY
		var candidate_local := Clock.local_datetime_from_unix(candidate_midnight)
		if int(candidate_local["weekday"]) in MEETING_WEEKDAYS:
			var hour: int = _rng.randi_range(WORK_HOUR_START, WORK_HOUR_END - 1)
			var minute: int = _rng.randi_range(0, 59)
			# Adding hours/minutes as seconds directly to a local-midnight
			# unix timestamp, rather than round-tripping through the
			# datetime dict again -- safe pure epoch arithmetic, though a
			# DST transition landing on this exact candidate day could
			# shift the intended local hour by up to one hour. Same
			# documented approximation as Clock's offset correction.
			var start_unix: float = candidate_midnight + hour * 3600.0 + minute * 60.0
			SaveState.data["next_meeting_unix"] = start_unix
			SaveState.data["next_meeting_duration"] = _rng.randf_range(MIN_DURATION, MAX_DURATION)
			SaveState.save()
			return

	push_warning("MeetingScheduler: found no meeting weekday within 14 days -- check MEETING_WEEKDAYS")
