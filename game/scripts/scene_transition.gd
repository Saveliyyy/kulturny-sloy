extends Control
class_name SceneTransition

signal finished

var running := false
var direction := 1
var cover := 0.0:
	set(value):
		cover = value
		queue_redraw()
var caption: PanelContainer
var title: Label
var detail: Label
var caption_fade: Tween


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	z_index = 100
	resized.connect(queue_redraw)
	caption = PanelContainer.new()
	caption.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(caption)
	caption.anchor_left = 0.30
	caption.anchor_right = 0.70
	caption.anchor_top = 0.36
	caption.anchor_bottom = 0.36
	caption.offset_left = 0.0
	caption.offset_right = 0.0
	caption.offset_top = 0.0
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("171d21f5")
	frame.border_color = Color("a58960")
	frame.set_border_width_all(2)
	frame.set_content_margin_all(17)
	caption.add_theme_stylebox_override("panel", frame)
	var lines := VBoxContainer.new()
	lines.mouse_filter = MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation", 5)
	caption.add_child(lines)
	title = _line(lines, 33, Color("efd8a7"))
	detail = _line(lines, 17, Color("cfbea3"))
	caption.hide()
	hide()


func begin() -> void:
	running = true
	if get_viewport().gui_is_dragging():
		get_viewport().gui_cancel_drag()
	show()


func finish() -> void:
	clear_phase()
	running = false
	hide()
	finished.emit()


func slide(toward: int, change_room: Callable) -> void:
	direction = toward
	var close := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	close.tween_property(self, "cover", 1.0, 0.24)
	await close.finished
	change_room.call()
	direction = -toward
	var open := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	open.tween_property(self, "cover", 0.0, 0.28)
	await open.finished


func show_phase(heading: String, text: String) -> void:
	title.text = heading
	detail.text = text
	caption.offset_bottom = 0.0
	caption.modulate.a = 0.0
	caption.show()
	caption_fade = create_tween()
	caption_fade.tween_property(caption, "modulate:a", 1.0, 0.21)


func clear_phase() -> void:
	if caption_fade:
		caption_fade.kill()
	caption.hide()


func _draw() -> void:
	if cover <= 0.0:
		return
	var width := ceilf(cover * size.x)
	var x := 0.0 if direction > 0 else size.x - width
	var edge := width if direction > 0 else x
	draw_rect(Rect2(x, 0.0, width, size.y), Color("231d18"))
	for stripe in int(ceilf(width / 72.0)):
		var plank_x := x + stripe * 72.0
		var plank_width := minf(69.0, x + width - plank_x)
		draw_rect(Rect2(plank_x, 0.0, plank_width, size.y), Color("30251d") if stripe % 2 == 0 else Color("342920"))
		draw_rect(Rect2(plank_x, size.y * 0.69, plank_width, 6.0), Color("473328"))
	draw_line(Vector2(edge, 0), Vector2(edge, size.y), Color("ad8752"), 4.0)


func _line(parent: Control, font_size: int, ink: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ink)
	parent.add_child(label)
	return label
