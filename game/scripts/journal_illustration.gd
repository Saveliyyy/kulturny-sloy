extends Control
class_name JournalIllustration

const DETAILS := {
	"kluchi": ["samovar", Rect2(0.39, 0.32, 0.23, 0.15)],
	"late_lid": ["samovar", Rect2(0.34, 0.17, 0.33, 0.15)],
	"seam": ["frost_glass", Rect2(0.18, 0.76, 0.66, 0.18)],
	"soot": ["soot_glass", Rect2(0.24, 0.59, 0.53, 0.31)],
	"crack": ["soot_glass", Rect2(0.51, 0.12, 0.34, 0.43)],
	"reverse": ["clock", Rect2(0.13, 0.18, 0.73, 0.46)],
	"bearing": ["compass", Rect2(0.06, 0.46, 0.69, 0.29)],
}
const METERS := {
	"heat": ["thermometer", "> 80°"],
	"cold": ["thermometer", "≤ −10°"],
	"warm_glass": ["thermometer", "> 10°"],
	"complete_clock": ["scale", "1,2 кг"],
	"light_compass": ["scale", "< 140 г"],
}

var rule := ""


func _ready() -> void:
	custom_minimum_size = Vector2(96, 66)
	size_flags_vertical = SIZE_SHRINK_CENTER
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)


func _draw() -> void:
	var frame := Rect2(Vector2.ZERO, size)
	draw_rect(frame, Color("3a3f33"))
	if DETAILS.has(rule):
		var detail: Array = DETAILS[rule]
		var art := ObjectSprites.texture(detail[0])
		var uv: Rect2 = detail[1]
		var crop := Rect2(uv.position * art.get_size(), uv.size * art.get_size())
		draw_texture_rect_region(art, _fit(crop.size, frame.grow(-2)), crop)
		if rule == "reverse":
			_draw_direction()
	else:
		var example: Array = METERS[rule]
		var tool := ObjectSprites.texture(example[0])
		draw_texture_rect(tool, _fit(tool.get_size(), Rect2(5, 5, 27, size.y - 10)), false)
		draw_string(ThemeDB.fallback_font, Vector2(36, size.y * 0.58), example[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffe2a2"))
	draw_rect(frame.grow(-1), Color("91764c"), false)


func _fit(dimensions: Vector2, frame: Rect2) -> Rect2:
	var fitted := dimensions * minf(frame.size.x / dimensions.x, frame.size.y / dimensions.y)
	return Rect2((frame.get_center() - fitted * 0.5).round(), fitted.round())


func _draw_direction() -> void:
	var center := size * 0.5
	var ink := Color("ffe59a")
	draw_arc(center, 23, -2.4, -0.56, 14, Color("46291e"), 4)
	draw_arc(center, 23, -2.4, -0.56, 14, ink, 2)
	var tip := center + Vector2.from_angle(-2.4) * 23
	draw_colored_polygon(PackedVector2Array([tip + Vector2(-3, 4), tip + Vector2(-2, -6), tip + Vector2(6, -1)]), ink)
