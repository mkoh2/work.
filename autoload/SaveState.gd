extends Node
## Single source of truth for persisted run state. Other autoloads read/write
## through SaveState.data and call save() after mutating it, rather than each
## owning separate save files. See GAME_DESIGN.md §10 (SaveState autoload).

const SAVE_PATH := "user://save.dat"
const SCHEMA_VERSION := 1

var data: Dictionary = {}


func _ready() -> void:
	load_data()


func _default_data() -> Dictionary:
	return {
		"version": SCHEMA_VERSION,
		"trust": 50.0,
		"trust_ceiling": 100.0,
		"trust_peak": 50.0,
		"run_start_unix": 0.0,
		"last_open_unix": 0.0,
		"next_task_unix": 0.0,
		"next_meeting_unix": 0.0,
		"next_meeting_duration": 0.0,
		"consecutive_missed_days": 0,
		"run_state": "active", # active | fired | abandoned | won
		"present_mode": false,
	}


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		data = _default_data()
		return

	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		data = _default_data()
		return

	data = parsed
	# Fold in any keys introduced by a later schema version so old saves keep working.
	var defaults := _default_data()
	for key in defaults:
		if not data.has(key):
			data[key] = defaults[key]


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func is_terminated() -> bool:
	return data.get("run_state", "active") != "active"


## Per GAME_DESIGN.md §9: a loss is permanent for that save file. Starting a new
## run means deleting local save data (a player could always do this manually --
## true server-side single-life enforcement was explicitly cut from v1 scope).
func reset_new_run() -> void:
	data = _default_data()
	save()
