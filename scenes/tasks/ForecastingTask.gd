extends Control
## Forecasting negotiation (GAME_DESIGN.md §6.2, item 1). The manager has a
## number in mind; you guess, hot/cold feedback narrows it down. Wrong
## guesses cost Trust immediately, not just at the end -- reckless guessing
## is punished on its own, separate from whether you eventually converge.

signal resolved(trust_delta: float) # final outcome delta, applied by Desk.gd

const MIN_VALUE := 1
const MAX_VALUE := 100
const MAX_GUESSES := 5
const WRONG_GUESS_PENALTY := -3.0 # applied immediately, per wrong guess
const SUCCESS_BONUS := 4.0 # final delta on success, within the §5 +2..+5 range
const FAILURE_PENALTY := -12.0 # final delta if guesses run out, within §5 -8..-20

@onready var _prompt_label: Label = $Panel/Contents/PromptLabel
@onready var _feedback_label: Label = $Panel/Contents/FeedbackLabel
@onready var _guess_input: LineEdit = $Panel/Contents/GuessInput
@onready var _submit_button: Button = $Panel/Contents/SubmitButton
@onready var _guesses_label: Label = $Panel/Contents/GuessesLabel

var _target: int
var _guesses_left: int
var _done: bool = false


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_target = rng.randi_range(MIN_VALUE, MAX_VALUE)
	_guesses_left = MAX_GUESSES

	_prompt_label.text = "Manager wants a number\nbetween %d and %d." % [MIN_VALUE, MAX_VALUE]
	_update_guesses_label()

	_submit_button.pressed.connect(_on_submit_pressed)
	_guess_input.text_submitted.connect(func(_t): _on_submit_pressed())
	_guess_input.text_changed.connect(func(_t): AudioManager.play_keystroke())
	_guess_input.grab_focus()


func _update_guesses_label() -> void:
	_guesses_label.text = "%d guess%s left" % [_guesses_left, "" if _guesses_left == 1 else "es"]


func _on_submit_pressed() -> void:
	if _done or not _guess_input.text.is_valid_int():
		_feedback_label.text = "That's not a number."
		return

	var guess := _guess_input.text.to_int()
	AudioManager.play_click()

	if guess == _target:
		_done = true
		_feedback_label.text = "\"That's the number I had in mind.\""
		_submit_button.disabled = true
		resolved.emit(SUCCESS_BONUS)
		return

	_guesses_left -= 1
	TrustManager.apply_delta(WRONG_GUESS_PENALTY)
	_feedback_label.text = "Try lower." if guess > _target else "Try higher."
	_update_guesses_label()
	_guess_input.clear()

	if _guesses_left <= 0:
		_done = true
		_feedback_label.text = "\"Forget it, I'll figure it out myself.\""
		_submit_button.disabled = true
		resolved.emit(FAILURE_PENALTY)
