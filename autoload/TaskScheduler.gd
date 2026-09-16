extends Node
## Decides when the next task interrupt fires (GAME_DESIGN.md §6.1, §6.3).
##
## v1 uses a single flat interval range and a flat missed-task penalty as a
## scaffold placeholder. The real day-by-day difficulty table (§6.3) and the
## §5 -8..-20 penalty range scaled by how long a task sat missed are content
## work for later, not scaffolding.

signal task_ready(task_id: String)

const MIN_INTERVAL := 180.0 # seconds (3 min) -- placeholder, see §6.3
const MAX_INTERVAL := 480.0 # seconds (8 min) -- placeholder, see §6.3
const MISSED_TASK_PENALTY := -10.0 # placeholder flat value within the §5 -8..-20 range

const AVAILABLE_TASK_IDS := ["forecasting"] # grows as more task types (§6.2) are built

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if SaveState.data.get("next_task_unix", 0.0) == 0.0:
		_schedule_next(Time.get_unix_time_from_system())


func _schedule_next(from_unix: float) -> float:
	var next: float = from_unix + _rng.randf_range(MIN_INTERVAL, MAX_INTERVAL)
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
