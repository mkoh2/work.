extends Node
## Presence/idle system (GAME_DESIGN.md §7): a single input-recency signal
## feeds the online/idle status dot, the idle Trust decay, and (via
## get_state()) the spreadsheet busywork's occasional grading in §6.2.
##
## Present Mode (§7.1) is a discoverable-only override -- nothing in this
## script explains it to the player. It must only be reachable by clicking
## around the status panel UI itself, never surfaced as a hint or tutorial.

signal presence_changed(state: String) # "online" | "idle"

const IDLE_THRESHOLD := 25.0 * 60.0 # 25 real minutes, confirmed in §7
const IDLE_DECAY_PER_TICK := -0.05 # placeholder; tune once the full Trust curve (§5) is balanced
const DECAY_TICK_INTERVAL := 1.0 # seconds; throttles Trust writes while idle

var _last_input_unix: float = 0.0
var _present_mode: bool = false
var _current_state: String = "online"
var _task_active: bool = false # ambient idle-drain suspends while a task overlay is up, §7
var _decay_accum: float = 0.0


func _ready() -> void:
	_last_input_unix = Time.get_unix_time_from_system()
	_present_mode = SaveState.data.get("present_mode", false)
	set_process(true)
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		_last_input_unix = Time.get_unix_time_from_system()


func _process(delta: float) -> void:
	var now := Time.get_unix_time_from_system()
	var idle_for := now - _last_input_unix
	var should_be_idle := (not _present_mode) and idle_for > IDLE_THRESHOLD

	var new_state := "idle" if should_be_idle else "online"
	if new_state != _current_state:
		_current_state = new_state
		presence_changed.emit(_current_state)

	if _current_state == "idle" and not _task_active and not SaveState.is_terminated():
		_decay_accum += delta
		if _decay_accum >= DECAY_TICK_INTERVAL:
			_decay_accum -= DECAY_TICK_INTERVAL
			TrustManager.apply_delta(IDLE_DECAY_PER_TICK)
	else:
		_decay_accum = 0.0


## Desk.gd calls this when a task overlay opens/closes so ambient idle-drain
## never double-penalizes the same moment as a task's own resolve/timeout
## delta (§7 boundary with §6.1).
func set_task_active(active: bool) -> void:
	_task_active = active


func get_state() -> String:
	return _current_state


func toggle_present_mode() -> bool:
	_present_mode = not _present_mode
	SaveState.data["present_mode"] = _present_mode
	SaveState.save()
	return _present_mode


func is_present_mode() -> bool:
	return _present_mode
