extends Node
## Decides when the next task interrupt fires (GAME_DESIGN.md §6.1, §6.3).
##
## Task volume follows the real calendar day this is played on, not a flat
## rate: light on Monday, ramping to a Thursday peak, Friday genuinely
## unpredictable except in light months. See _volume_range_for() below for
## the actual table -- these are tuned defaults, not final numbers.

signal task_ready(task_id: String)

const MISSED_TASK_PENALTY := -10.0 # placeholder flat value within the §5 -8..-20 range

const AVAILABLE_TASK_IDS := ["forecasting"] # grows as more task types (§6.2) are built

# Summer (Jun-Aug) and December are called out as light Fridays -- Northern
# Hemisphere summer assumed; flag if that's not the intent.
const LIGHT_MONTHS := [6, 7, 8, 12]

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if SaveState.data.get("next_task_unix", 0.0) == 0.0:
		_schedule_next(Time.get_unix_time_from_system())


## Time.get_datetime_dict_from_unix_time() only returns UTC -- confirmed
## against the real engine, there is no local-time overload for an
## arbitrary past timestamp (unlike get_datetime_dict_from_system(), which
## is always local "now"). "Monday" should mean the player's local Monday,
## so this computes the local UTC offset once by comparing system-local
## "now" to system "now" re-read as UTC, then applies that fixed offset to
## whatever timestamp is asked about. This is an approximation: a multi-day
## absence spanning a DST transition can be off by an hour for the older
## end of the gap. Acceptable for a task-volume flavor system; not worth a
## full timezone library over.
func _local_datetime(unix_time: float) -> Dictionary:
	var now: float = Time.get_unix_time_from_system()
	var local_now := Time.get_datetime_dict_from_system()
	var utc_now := Time.get_datetime_dict_from_unix_time(int(now))
	var offset: float = (Time.get_unix_time_from_datetime_dict(local_now)
			- Time.get_unix_time_from_datetime_dict(utc_now))
	return Time.get_datetime_dict_from_unix_time(int(unix_time + offset))


## Tasks-per-real-day range for the given weekday/month. §6.3, confirmed
## shape: light Monday, ramps to a Thursday peak, Friday depends on month.
## Saturday/Sunday default to the light Monday range as a placeholder --
## open question, not yet confirmed (see chat): true rest days with zero
## tasks, or still-active-but-light like this?
func _volume_range_for(weekday: int, month: int) -> Vector2i:
	match weekday:
		Time.WEEKDAY_MONDAY:
			return Vector2i(2, 4)
		Time.WEEKDAY_TUESDAY:
			return Vector2i(4, 6)
		Time.WEEKDAY_WEDNESDAY:
			return Vector2i(6, 8)
		Time.WEEKDAY_THURSDAY:
			return Vector2i(8, 10) # peak
		Time.WEEKDAY_FRIDAY:
			if month in LIGHT_MONTHS:
				return Vector2i(2, 4) # summer/December Friday: light
			else:
				return Vector2i(2, 10) # genuinely hit-or-miss the rest of the year
		_: # Saturday, Sunday -- placeholder, see docstring above
			return Vector2i(2, 4)


## Converts a day's task-count range into an average interval between
## tasks, then jitters +/-40% around it so tasks don't arrive on a metronome.
func _interval_range_for(from_unix: float) -> Vector2:
	var dt := _local_datetime(from_unix)
	var volume: Vector2i = _volume_range_for(dt["weekday"], dt["month"])
	var avg_volume: float = (volume.x + volume.y) / 2.0
	var avg_interval: float = Clock.SECONDS_PER_DAY / avg_volume
	return Vector2(avg_interval * 0.6, avg_interval * 1.4)


func _schedule_next(from_unix: float) -> float:
	var interval_range: Vector2 = _interval_range_for(from_unix)
	var next: float = from_unix + _rng.randf_range(interval_range.x, interval_range.y)
	SaveState.data["next_task_unix"] = next
	SaveState.save()
	return next


## Advances the schedule across [from_unix, to_unix) without presenting anything
## to the player -- used by Clock.reconcile_on_launch() to account for wall-clock
## time that passed while the app was closed. Each task that would have fired is
## treated as missed and returns its own Trust penalty. See §4.
func consume_missed_tasks(from_unix: float, to_unix: float) -> Array:
	var penalties: Array = []
	var next: float = SaveState.data.get("next_task_unix", from_unix)
	while next < to_unix:
		penalties.append(MISSED_TASK_PENALTY)
		next = _schedule_next(next)
	return penalties


## Called from the Desk scene's live loop to check whether a task should
## interrupt the player right now.
func poll_due() -> bool:
	var now := Time.get_unix_time_from_system()
	var next: float = SaveState.data.get("next_task_unix", now)
	return now >= next


func pick_task_id() -> String:
	return AVAILABLE_TASK_IDS[_rng.randi_range(0, AVAILABLE_TASK_IDS.size() - 1)]


## Called once a live task has been resolved (or timed out) so the next
## interrupt gets scheduled from now, not from when it was originally due.
func reschedule_from_now() -> void:
	_schedule_next(Time.get_unix_time_from_system())
