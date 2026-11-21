extends PanelContainer
class_name OfferSlip

const PAPER_INK := Color("402c1d")

var item_id := ""
var artifact_name := ""
var amount := 0
var marked_rules: Array = []


func proposal() -> Dictionary:
	return {"proposal_item": item_id, "amount": amount, "marked_rules": marked_rules.duplicate()}


func _get_drag_data(_position: Vector2) -> Variant:
	if not is_visible_in_tree() or item_id.is_empty() or amount <= 0:
		return null
	var cursor_anchor := Control.new()
	cursor_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper := PanelContainer.new()
	paper.position = Vector2(12, 12)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_theme_stylebox_override("panel", get_theme_stylebox("panel"))
	var entries := VBoxContainer.new()
	entries.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(entries)
	_add_line(entries, "Бланк оценки", 17)
	_add_line(entries, artifact_name, 15)
	for id: String in marked_rules:
		_add_line(entries, "✓  " + InspectionCatalog.CHECKLIST_LABELS[id], 14)
	_add_line(entries, "%d ₽" % amount, 20)
	cursor_anchor.add_child(paper)
	set_drag_preview(cursor_anchor)
	return proposal()


func _add_line(entries: VBoxContainer, value: String, font_size: int) -> void:
	var line := Label.new()
	line.text = value
	line.add_theme_color_override("font_color", PAPER_INK)
	line.add_theme_font_size_override("font_size", font_size)
	entries.add_child(line)
