extends PanelContainer
class_name DealPaper

signal proposal_received(form: Dictionary)

var proposal_item := ""


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return (
		not proposal_item.is_empty() and data is Dictionary
		and data.get("proposal_item", "") == proposal_item and data.get("amount", 0) > 0
		and data.get("marked_rules") is Array
	)


func _drop_data(position: Vector2, data: Variant) -> void:
	if _can_drop_data(position, data):
		proposal_received.emit(data)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_DRAG_BEGIN, NOTIFICATION_DRAG_END]:
		queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	if _can_drop_data(Vector2.ZERO, get_viewport().gui_get_drag_data()):
		draw_rect(Rect2(Vector2.ONE * 2, size - Vector2.ONE * 4), Color("73986f"), false, 3)
	var corner := Vector2(size.x - 2, 2)
	draw_colored_polygon(PackedVector2Array([
		corner + Vector2(-21, 0), corner, corner + Vector2(0, 21)
	]), Color("b3915c"))
	draw_line(corner + Vector2(-21, 0), corner + Vector2(0, 21), Color("9a7847"))
	var clip := Vector2(size.x - 42, 2)
	draw_line(clip, clip + Vector2(0, 12), Color("745943"), 3)
	draw_line(clip + Vector2(0, 12), clip + Vector2(-6, 12), Color("745943"), 3)
	draw_line(clip + Vector2(-6, 12), clip + Vector2(-6, -2), Color("a27e52"), 3)
