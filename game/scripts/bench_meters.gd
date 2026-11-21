extends Control
class_name BenchMeters

const BRASS := Color("a78a58")
const SHADE := Color("242a24")
const INK := Color("e5d4a8")
const TEAL := Color("9ccabd")

var tool := ""
var worktop := Rect2()
var artifact := Rect2()
var instrument: Texture2D
var probe := Vector2.INF
var touching := false
var progress := 0.0
var reading_value := 0
var reading := ""


func _draw() -> void:
	match tool:
		"lens":
			_draw_lens_plate()
		"scale", "thermometer":
			var card := _meter_rect()
			if tool == "scale":
				_draw_sling(card)
			elif probe.is_finite() and worktop.has_point(probe):
				_draw_probe(card)
			_draw_meter(card)


func _meter_rect() -> Rect2:
	return Rect2(worktop.end.x - 153, worktop.position.y + 36, 135, 253)


func _draw_lens_plate() -> void:
	var plate := Rect2(worktop.position + Vector2(17, 20), Vector2(113, 56))
	draw_rect(plate.grow(3), Color("1a211a"))
	draw_rect(plate, Color("323a2e"))
	draw_rect(plate, BRASS, false)
	_text(plate.position + Vector2(8, 20), "Лупа ×2,5", 16, INK)
	_text(plate.position + Vector2(8, 43), "ПКМ убрать", 13, TEAL)


func _draw_meter(card: Rect2) -> void:
	var amount := clampf(progress, 0.0, 1.0)
	var is_scale := tool == "scale"
	draw_rect(card.grow(5), Color("1b2119"))
	draw_rect(card.grow(2), BRASS)
	draw_rect(card, Color("333b30"))
	draw_rect(Rect2(card.position, Vector2(card.size.x, 31)), Color("3e4939"))
	_text(card.position + Vector2(8, 21), InspectionCatalog.TOOLS[tool], 16, INK)

	if instrument != null:
		var height := 129.0
		var width := height * instrument.get_width() / instrument.get_height()
		draw_texture_rect(instrument, Rect2(card.position + Vector2(73, 38), Vector2(width, height)), false)

	var top := card.position.y + 47
	var baseline := top + 119
	var axis_x := card.position.x + 63
	var limit := 10000 if reading_value > 500 else 500
	if is_scale:
		_draw_mass_scale(axis_x, top, baseline, amount, limit)
	else:
		_draw_temperature_scale(axis_x, top, baseline, amount)

	var panel := Rect2(card.position + Vector2(7, 180), Vector2(card.size.x - 14, 33))
	draw_rect(panel, SHADE)
	draw_rect(panel, BRASS, false)
	var pending := "—" if is_scale or amount == 0.0 else "Замер…"
	_text(panel.position + Vector2(8, 23), pending if reading.is_empty() else reading, 19, TEAL)
	_text(card.position + Vector2(8, 235), "ПКМ убрать", 13, INK)


func _draw_mass_scale(axis_x: float, top: float, baseline: float, amount: float, limit: int) -> void:
	draw_line(Vector2(axis_x, top), Vector2(axis_x, baseline), Color("ac925d"), 2)
	var ticks := 10
	for i in ticks + 1:
		var y := lerpf(top, baseline, float(i) / ticks)
		var major := i % 2 == 0 or i == ticks
		draw_line(Vector2(axis_x - (11 if major else 5), y), Vector2(axis_x, y), INK)
		if i in [0, 5, ticks]:
			var division := roundi(limit * float(i) / ticks)
			var caption := str(division) if limit <= 500 else "%.0f" % (division / 1000.0)
			_text(Vector2(axis_x - 47, y + 4), caption, 12, INK)
	var extension := 1.0 - pow(1.0 - amount, 2.0) * cos(amount * TAU * 2.0)
	var y := lerpf(top, baseline, clampf((float(reading_value) / limit) * extension, 0.0, 1.0))
	draw_colored_polygon(PackedVector2Array([
		Vector2(axis_x, y), Vector2(axis_x - 16, y - 4), Vector2(axis_x - 16, y + 4)
	]), Color("e5b376"))
	_text(Vector2(axis_x - 47, baseline + 14), "кг" if limit > 500 else "г", 12, INK)


func _draw_temperature_scale(axis_x: float, top: float, baseline: float, amount: float) -> void:
	var current := lerpf(15.0, float(reading_value), amount)
	draw_line(Vector2(axis_x, top), Vector2(axis_x, baseline), Color("9a8570"), 5)
	for degrees in [-20, 0, 20, 40, 60, 80, 100]:
		var y := lerpf(baseline, top, (degrees + 20.0) / 120.0)
		draw_line(Vector2(axis_x - 11, y), Vector2(axis_x - 3, y), INK)
		_text(Vector2(axis_x - 47, y + 4), str(degrees).replace("-", "−"), 12, INK)
	var level := lerpf(baseline, top, clampf((current + 20.0) / 120.0, 0.0, 1.0))
	var ink := Color("80b7cd") if current < 0.0 else Color("e59168")
	draw_line(Vector2(axis_x, baseline), Vector2(axis_x, level), ink, 3)
	draw_circle(Vector2(axis_x, baseline), 5, ink)


func _draw_sling(card: Rect2) -> void:
	var hook := artifact.position + artifact.size * Vector2(0.82, 0.31)
	var mount := card.position + Vector2(-5, 72)
	var guide := Vector2(hook.x + 16, mount.y)
	var sling := PackedVector2Array([mount, guide, hook - Vector2(0, 6)])
	draw_polyline(sling, Color("29241e"), 5)
	draw_polyline(sling, BRASS, 2)
	draw_circle(guide, 4, Color("766546"))
	draw_circle(guide, 1.5, INK)
	draw_arc(hook, 6, -PI * 0.5, PI, 12, Color("211d16"), 4)
	draw_arc(hook, 6, -PI * 0.5, PI, 12, INK, 2)


func _draw_probe(card: Rect2) -> void:
	var handle := probe + Vector2(39, 30)
	var cord := PackedVector2Array([Vector2(card.position.x, card.end.y - 45), handle + Vector2(14, 16), handle])
	draw_polyline(cord, Color("29241e"), 6)
	draw_polyline(cord, Color("98764f"), 2)
	draw_line(handle, probe + Vector2(12, 9), Color("2c2a23"), 10)
	draw_line(handle, probe + Vector2(12, 9), Color("c5a778"), 6)
	draw_line(probe + Vector2(12, 9), probe, Color("ccd2c2"), 3)
	draw_circle(probe, 3.5, TEAL if touching else Color("b8a37d"))
	if touching:
		draw_arc(probe, 11, 0.0, TAU, 24, Color("293c33"), 3)
		draw_arc(probe, 11, -PI * 0.5, -PI * 0.5 + TAU * progress, 24, TEAL, 2)


func _text(position: Vector2, value: String, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
