extends GridContainer
## Spreadsheet busywork (GAME_DESIGN.md §6.2). Mostly flavor -- clicking
## fills a cell with a plausible-looking number and counts as activity for
## §7's presence signal, same as any other input.
##
## TODO(content): the "occasionally a real graded moment hides inside
## ordinary clicking" half of §6.2 needs actual per-moment grading logic
## once task content design happens -- this scaffold only wires the flavor
## half plus the shared activity signal.

const ROWS := 3
const COLS := 4


func _ready() -> void:
	columns = COLS
	for i in range(ROWS * COLS):
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(16, 12)
		cell.flat = true
		cell.text = ""
		cell.pressed.connect(_on_cell_pressed.bind(cell))
		add_child(cell)


func _on_cell_pressed(cell: Button) -> void:
	AudioManager.play_click()
	cell.text = str(randi_range(0, 99))
