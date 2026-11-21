extends Label
class_name DialogueLine

const CHARACTER_TIME := 1.0 / 30.0

var message := ""
var phrases := PackedStringArray()
var phrase_index := 0
var time_left := 0.0


func _ready() -> void:
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_STOP


func say(line: String, delay := 0.0, restart := false) -> void:
	if message == line and not restart:
		return
	message = line
	phrases = line.split("\n", false)
	phrase_index = 0
	text = phrases[0] if not phrases.is_empty() else ""
	visible_characters = 0
	time_left = delay
	set_process(not text.is_empty())


func reveal() -> void:
	visible_characters = -1
	time_left = maxf(1.55, text.length() * 0.055)
	set_process(phrase_index + 1 < phrases.size())


func is_speaking() -> bool:
	return visible_characters > 0 and visible_characters < text.length() and is_visible_in_tree()


func _next_phrase() -> void:
	phrase_index += 1
	text = phrases[phrase_index]
	visible_characters = 0
	time_left = 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	time_left -= delta
	if visible_characters == -1:
		if time_left <= 0.0:
			_next_phrase()
		return
	while time_left <= 0.0 and visible_characters < text.length():
		var character := text[visible_characters]
		visible_characters += 1
		time_left += CHARACTER_TIME
		if character in [".", "!", "?", "…"]:
			time_left += 0.13
		elif character in [",", ":", "—"]:
			time_left += 0.055
	if visible_characters >= text.length():
		reveal()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if visible_characters > 0:
			reveal()
			accept_event()
		elif visible_characters == -1 and phrase_index + 1 < phrases.size():
			_next_phrase()
			accept_event()
