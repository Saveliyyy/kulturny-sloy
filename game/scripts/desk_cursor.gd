extends RefCounted
class_name DeskCursor

const POINTER := [
	"o.............", "oo............", "oho...........", "ohlo..........",
	"ohlmo.........", "ohllmo........", "ohllamo.......", "ohltlamo......",
	"ohltllamo.....", "ohlaaoooo.....", "ohaooo........", "oloomo........",
	"oo..oao.......", "....olmo......", ".....oao......", ".....ooo......",
]
const HAND := [
	"....ooo.......", "...ollo.......", "...ollo.......", "...ollo.......",
	"...olloloo....", "...ollllollo..", ".ooollllllllo.", "oloollllllllo.",
	"olllllllllllo.", ".ollllllllmmo.", "..ollllllmmmo.", "...olllllmmo..",
	"....ooooooo...", "....ommmmo....", "....oooooo....", "..............",
]
const LETTER := [
	"..............", "...oooooooo...", "...ollllllo...", ".....ollo.....",
	".....ollo.....", ".....ollo.....", ".....ollo.....", ".....ollo.....",
	".....ollo.....", ".....ollo.....", ".....ollo.....", ".....ollo.....",
	"...ollllllo...", "...oooooooo...", "..............", "..............",
]
const CROSS := [
	"...............", "......ooo......", "......olo......", "......olo......",
	"......olo......", "......ooo......", ".ooooo...ooooo.", ".olllo.l.olllo.",
	".ooooo...ooooo.", "......ooo......", "......olo......", "......olo......",
	"......olo......", "......ooo......", "...............",
]
const COLORS := {"o": Color("241b16"), "l": Color("e6bb78"), "m": Color("9d5b35"),
	"h": Color("fff1c5"), "a": Color("c38c50"), "t": Color("78aaa0")}


static func install() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var arrow := _image(POINTER)
	Input.set_custom_mouse_cursor(arrow, Input.CURSOR_ARROW, Vector2(0, 0))
	Input.set_custom_mouse_cursor(arrow, Input.CURSOR_MOVE, Vector2.ZERO)
	Input.set_custom_mouse_cursor(_image(HAND), Input.CURSOR_POINTING_HAND, Vector2(8, 2))
	Input.set_custom_mouse_cursor(_image(LETTER), Input.CURSOR_IBEAM, Vector2(13, 15))
	Input.set_custom_mouse_cursor(_image(CROSS), Input.CURSOR_CROSS, Vector2(15, 15))
	var can_drop := _image(POINTER, "+")
	Input.set_custom_mouse_cursor(can_drop, Input.CURSOR_DRAG, Vector2.ZERO)
	Input.set_custom_mouse_cursor(can_drop, Input.CURSOR_CAN_DROP, Vector2.ZERO)
	Input.set_custom_mouse_cursor(_image(POINTER, "x"), Input.CURSOR_FORBIDDEN, Vector2.ZERO)


static func _image(rows: Array, badge := "") -> Image:
	var picture := Image.create_empty(36, 32, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if COLORS.has(row[x]):
				picture.fill_rect(Rect2i(x * 2, y * 2, 2, 2), COLORS[row[x]])
	if not badge.is_empty():
		picture.fill_rect(Rect2i(22, 18, 14, 14), Color("2e231b"))
		var ink := Color("d2e7a6") if badge == "+" else Color("fda489")
		for i in 5:
			if badge == "+":
				picture.fill_rect(Rect2i(24 + i * 2, 24, 2, 2), ink)
				picture.fill_rect(Rect2i(28, 20 + i * 2, 2, 2), ink)
			else:
				picture.fill_rect(Rect2i(24 + i * 2, 20 + i * 2, 2, 2), ink)
				picture.fill_rect(Rect2i(32 - i * 2, 20 + i * 2, 2, 2), ink)
	return picture
