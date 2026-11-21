extends RefCounted
class_name VisitorSprites

const SIZE := Vector2i(320, 384)
const PORTRAITS := {
	"Таня Гусева": "tanya",
	"Мирон": "miron",
	"Деревянко": "derevyanko",
	"Костя": "kostya",
}


static func texture(visitor: String) -> Texture2D:
	return PixelArt.load_asset("visitors/%s" % PORTRAITS[visitor], SIZE)
