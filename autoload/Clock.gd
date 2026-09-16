extends Node
## Real-world wall-clock time. One real minute is one game minute, and the
## clock does not stop when the app is closed (GAME_DESIGN.md §4) -- that's
## the whole premise. This autoload owns the top-left clock display value,
## the current-day counter, and the reconciliation that runs on relaunch.

signal day_advanced(day: int)
signal job_abandoned

const SECONDS_PER_DAY := 86400.0
const TOTAL_DAYS := 10
const ABANDONMENT_MISSED_DAYS := 2 # tunable default, see §4.1
const HEARTBEAT_INTERVAL := 30.0 # seconds between last_open_unix stamps while running

var _heartbeat_accum := 0.0


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	_heartbeat_accum += delta
	if _heartbeat_accum >= HEARTBEAT_INTERVAL:
		_heartbeat_accum = 0.0
		_stamp_last_open()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_stamp_last_open()


func _stamp_last_open() -> void:
	SaveState.data["last_open_unix"] = Time.get_unix_time_from_system()
	SaveState.save()


## HH:MM for the top-left display. Real local time, not a stylized clock.
func get_time_string() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%02d:%02d" % [dt.hour, dt.minute]


func get_current_day() -> int:
	var start: float = SaveState.data.get("run_start_unix", 0.0)
	if start <= 0.0:
		return 1
	var now := Time.get_unix_time_from_system()
	return int(floor((now - start) / SECONDS_PER_DAY)) + 1


## Called once by Boot.gd, after the scene tree is up but before the Desk
## scene is shown. Reconciles whatever wall-clock time passed since the app
## was last open: stacks missed tasks (§4), checks job abandonment (§4.1),
## and checks the day-10 win condition. Returns a summary for Boot to act on
## (e.g. show the missed-task backlog) -- see §1.1: this is reported as
## consequence, never as a system warning about what the rule is.
func reconcile_on_launch() -> Dictionary:
	var now := Time.get_unix_time_from_system()
	var result := {
		"missed_task_penalties": [],
		"abandoned": false,
		"won": false,
		"started_new_run": false,
	}

	if SaveState.data.get("run_start_unix", 0.0) == 0.0:
		SaveState.data["run_start_unix"] = now
		SaveState.data["last_open_unix"] = now
		SaveState.save()
		result["started_new_run"] = true
		return result

	var last: float = SaveState.data.get("last_open_unix", now)
	var gap: float = maxf(now - last, 0.0)

	if gap > 0.0:
		var missed: Array = TaskScheduler.consume_missed_tasks(last, now)
		for penalty in missed:
			TrustManager.apply_delta(penalty)
		result["missed_task_penalties"] = missed

		# A day here is a rolling 24h window since the last time the app was
		# open, not a calendar date -- avoids timezone edge cases and matches
		# "the clock is the antagonist" more literally than a midnight
		# boundary would.
		var missed_days := int(floor(gap / SECONDS_PER_DAY))
		if missed_days >= 1:
			var consecutive: int = SaveState.data.get("consecutive_missed_days", 0) + missed_days
			SaveState.data["consecutive_missed_days"] = consecutive
			if consecutive >= ABANDONMENT_MISSED_DAYS and not SaveState.is_terminated():
				SaveState.data["run_state"] = "abandoned"
				result["abandoned"] = true
				job_abandoned.emit()
		else:
			SaveState.data["consecutive_missed_days"] = 0

	SaveState.data["last_open_unix"] = now
	SaveState.save()

	var day := get_current_day()
	if day > TOTAL_DAYS and SaveState.data.get("run_state", "active") == "active":
		SaveState.data["run_state"] = "won"
		SaveState.save()
		result["won"] = true

	day_advanced.emit(mini(day, TOTAL_DAYS))
	return result
