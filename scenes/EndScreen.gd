extends Control
## Fired, abandoned, or won (GAME_DESIGN.md §9). Permadeath (§9, confirmed):
## there is deliberately no continue/retry button here -- a loss or win is
## final for this save file. A new run means starting a fresh save.

@onready var _title_label: Label = $Panel/Contents/TitleLabel
@onready var _body_label: Label = $Panel/Contents/BodyLabel


func _ready() -> void:
	var state: String = SaveState.data.get("run_state", "active")
	match state:
		"fired":
			_title_label.text = "TERMINATED"
			_body_label.text = "Your manager has decided\nto let you go."
		"abandoned":
			_title_label.text = "NO CALL, NO SHOW"
			_body_label.text = "You stopped showing up.\nYour position has been filled."
		"won":
			_title_label.text = "DAY 10"
			_body_label.text = "An email arrives from the CEO.\n[link]  password: ------\n(stub -- real backend is\ndeferred, see §11)"
		_:
			_title_label.text = "GAME OVER"
			_body_label.text = ""
