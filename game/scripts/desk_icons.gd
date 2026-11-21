extends RefCounted
class_name DeskIcons

const COLORS := {
	"o": Color("30261c"), "l": Color("e8d19a"), "w": Color("e8e4c4"),
	"m": Color("a37b45"), "s": Color("745235"), "b": Color("7facac"),
	"d": Color("455e59"), "r": Color("b6644c"),
}

const GLYPHS := {
	"shelf": [
		".oooooooooooooo.", ".omlllllllllmo.", ".omsssssosssmo.", ".omoboososromo.",
		".omobddosoromo.", ".omobddososomo.", ".ommmmmmmmmmo.", ".omlllllllllmo.",
		".omsooomssosmo.", ".omsowomssosmo.", ".omooooooooomo.", ".oooooooooooooo.",
	],
	"lens": [
		"....oooooo......", "...ollllllo.....", "..olwbbbblo.....", "..olbbbbddlo....",
		"..olbbbdddlo....", "..olbbddddlo....", "...ollllloo.....", "....ooooooso....",
		".........osso...", "..........osso..", "...........osso.", "............ooo.",
	],
	"scale": [
		".......oo.......", "......olmo......", "......olmo......", "....oolmooo.....",
		"...olwwwwmso....", "...olwrorwmo....", "...olwwwlwmo....", "....ommmmoo.....",
		"......olmo......", "......olmo......", "......olmo......", ".......oo.......",
	],
	"thermometer": [
		"......oooo......", ".....olwmoo.....", ".....olwmoo.....", ".....olrmoo.....",
		".....olrmoo.....", ".....olrmoo.....", ".....olrmoo.....", ".....olrmoo.....",
		"....olrrmmoo....", "....olrrsmoo....", ".....oooooo.....", "................",
	],
}

static var textures := {}


static func icon(kind: String) -> Texture2D:
	if textures.has(kind):
		return textures[kind]
	var rows: Array = GLYPHS[kind]
	var image := Image.create_empty(64, 48, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if COLORS.has(row[x]):
				image.fill_rect(Rect2i(x * 4, y * 4, 4, 4), COLORS[row[x]])
	var texture := ImageTexture.create_from_image(image)
	textures[kind] = texture
	return texture
