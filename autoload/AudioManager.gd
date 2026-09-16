extends Node
## Keystroke/click SFX and ambient bed layering (GAME_DESIGN.md §8).
##
## No audio assets exist yet. This stub gives UI code (text fields, buttons,
## the Desk scene) a stable API to call into now, so wiring sound in later is
## a matter of dropping AudioStreams into the exported slots below rather
## than touching every caller.

@export var keystroke_streams: Array[AudioStream] = [] # 2-3 pitch variants, §8
@export var click_stream: AudioStream
@export var ambient_hum_stream: AudioStream # fluorescent light hum, §8
@export var ambient_ac_stream: AudioStream # AC compressor cycling, §8
@export var ambient_footstep_streams: Array[AudioStream] = []

var _sfx_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_sfx_player = AudioStreamPlayer.new()
	add_child(_sfx_player)
	_ambient_player = AudioStreamPlayer.new()
	add_child(_ambient_player)


func play_keystroke() -> void:
	if keystroke_streams.is_empty():
		return
	_play_one(keystroke_streams[_rng.randi_range(0, keystroke_streams.size() - 1)])


func play_click() -> void:
	_play_one(click_stream)


func play_footstep() -> void:
	if ambient_footstep_streams.is_empty():
		return
	_play_one(ambient_footstep_streams[_rng.randi_range(0, ambient_footstep_streams.size() - 1)])


func start_ambient_hum() -> void:
	if ambient_hum_stream == null:
		return
	_ambient_player.stream = ambient_hum_stream
	_ambient_player.play()


func stop_ambient() -> void:
	_ambient_player.stop()


func _play_one(stream: AudioStream) -> void:
	if stream == null:
		return # no asset assigned yet -- safe no-op until SFX are added
	_sfx_player.stream = stream
	_sfx_player.play()
