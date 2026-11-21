extends RefCounted
class_name PixelArt

static var textures: Dictionary[String, Texture2D] = {}


static func load_asset(file: String, limit: Vector2i, trim_alpha := 0.0) -> Texture2D:
	if textures.has(file):
		return textures[file]
	var path := "res://art/%s.png" % file
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	var source := load(path) as Texture2D
	var picture := source.get_image()
	if picture.is_compressed():
		picture.decompress()
	if trim_alpha > 0.0:
		_fit(picture, limit * 2)
		picture.convert(Image.FORMAT_RGBA8)
		for y in picture.get_height():
			for x in picture.get_width():
				if picture.get_pixel(x, y).a < trim_alpha:
					picture.set_pixel(x, y, Color.TRANSPARENT)
		var content := picture.get_used_rect()
		if content.has_area():
			picture = picture.get_region(content)
	_fit(picture, limit)
	var cooked := ImageTexture.create_from_image(picture)
	textures[file] = cooked
	return cooked


static func _fit(picture: Image, limit: Vector2i) -> void:
	var current := picture.get_size()
	var ratio := minf(float(limit.x) / current.x, float(limit.y) / current.y)
	var target := Vector2i(Vector2(current) * ratio).max(Vector2i.ONE)
	if target != current:
		picture.resize(target.x, target.y, Image.INTERPOLATE_NEAREST)
