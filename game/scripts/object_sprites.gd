extends RefCounted
class_name ObjectSprites

const CLOCK_START := 2.35
const COMPASS_BEARING := 0.85
const SOURCE_SIZE := 1254.0
const WORKING_SIZE := 384
const SOURCES := {
	"samovar": [15, [Vector2(208, 516), Vector2(1054, 518)]],
	"frost_glass": [13, []],
	"soot_glass": [12, []],
	"clock": [13, [Vector2(627, 106)]],
	"compass": [14, [Vector2(957, 915)]],
	"lens": [12, []],
	"scale": [14, [Vector2(628, 140)]],
	"thermometer": [14, []],
	"stamp_catalog": [12, []],
}
const COMPASS_CENTER := Vector2(567, 730)
const CLOCK_CENTER := Vector2(627, 484)
# Replace only the two painted halves of the compass needle. The pivot stays in the artwork.
const PAINTED_NEEDLE := [
	[Vector2(565, 706), Vector2(608, 677), Vector2(702, 620), Vector2(694, 649),
		Vector2(639, 721), Vector2(593, 759), Vector2(569, 751)],
	[Vector2(565, 708), Vector2(593, 748), Vector2(538, 797), Vector2(402, 875),
		Vector2(423, 846), Vector2(514, 746)],
]

static var base_images: Dictionary[String, Image] = {}
static var textures: Dictionary[String, Texture2D] = {}
static var origins: Dictionary[String, Vector2] = {}


static func texture(id: String) -> Texture2D:
	if not textures.has(id):
		var picture := sprite_image(id)
		if id in ["clock", "compass"]:
			draw_needle(picture, id, CLOCK_START if id == "clock" else COMPASS_BEARING)
		textures[id] = ImageTexture.create_from_image(picture)
	return textures[id]


static func sprite_image(id: String) -> Image:
	if not base_images.has(id):
		var source := load("res://art/objects/%s.png" % id) as Texture2D
		var picture := source.get_image()
		picture.resize(WORKING_SIZE, WORKING_SIZE, Image.INTERPOLATE_NEAREST)
		picture.convert(Image.FORMAT_RGBA8)
		var spec: Array = SOURCES[id]
		picture = _apply_background_mask(picture, spec[0], spec[1])
		if id == "compass":
			_restore_compass_face(picture)
		var bounds := picture.get_used_rect()
		origins[id] = Vector2(bounds.position)
		base_images[id] = picture.get_region(bounds)
	return base_images[id].duplicate() as Image


static func _source_point(point: Vector2) -> Vector2:
	return point * (WORKING_SIZE / SOURCE_SIZE)


static func _apply_background_mask(picture: Image, tolerance: int, holes: Array) -> Image:
	var side := WORKING_SIZE
	var pixels := picture.get_data()
	var candidates := PackedByteArray()
	candidates.resize(side * side)
	# The supplied backdrops can grade slightly from one edge to the other.
	for y in side:
		var left := y * side * 4
		var right := left + (side - 1) * 4
		for x in side:
			var index := left + x * 4
			var t := float(x) / (side - 1)
			var dr := absf(pixels[index] - lerpf(pixels[left], pixels[right], t))
			var dg := absf(pixels[index + 1] - lerpf(pixels[left + 1], pixels[right + 1], t))
			var db := absf(pixels[index + 2] - lerpf(pixels[left + 2], pixels[right + 2], t))
			if maxf(dr, maxf(dg, db)) <= tolerance:
				candidates[y * side + x] = 1
	var edges: Array[int] = []
	# Keep enclosed details unless they belong to a known opening such as a handle.
	for index in side:
		edges.append(index)
		edges.append((side - 1) * side + index)
		edges.append(index * side)
		edges.append(index * side + side - 1)
	for hole: Vector2 in holes:
		var point := Vector2i(_source_point(hole))
		edges.append(point.y * side + point.x)
	while not edges.is_empty():
		var cell: int = edges.pop_back()
		if candidates[cell] == 0:
			continue
		candidates[cell] = 0
		pixels[cell * 4 + 3] = 0
		if cell % side > 0:
			edges.append(cell - 1)
		if cell % side < side - 1:
			edges.append(cell + 1)
		if cell >= side:
			edges.append(cell - side)
		if cell < side * (side - 1):
			edges.append(cell + side)
	return Image.create_from_data(side, side, false, Image.FORMAT_RGBA8, pixels)


static func _restore_compass_face(picture: Image) -> void:
	var source := picture.duplicate() as Image
	var center := _source_point(COMPASS_CENTER)
	var hub_radius := 8.2
	var across := Vector2(0.65, 0.76)
	for raw in PAINTED_NEEDLE:
		var mask := PackedVector2Array()
		for corner: Vector2 in raw:
			mask.append(_source_point(corner))
		for y in range(181, 272):
			for x in range(116, 219):
				var point := Vector2(x, y)
				if point.distance_to(center) < hub_radius or not Geometry2D.is_point_in_polygon(point, mask):
					continue
				var near := _face_sample(point, across, mask, center, hub_radius)
				var far := _face_sample(point, -across, mask, center, hub_radius)
				var blend := near.distance_to(point) / near.distance_to(far)
				picture.set_pixelv(Vector2i(point), source.get_pixelv(Vector2i(near)).lerp(source.get_pixelv(Vector2i(far)), blend))


static func _face_sample(point: Vector2, direction: Vector2, mask: PackedVector2Array, center: Vector2, hub_radius: float) -> Vector2:
	for step in range(1, 20):
		var sample := (point + direction * step).round()
		if sample.distance_to(center) >= hub_radius and not Geometry2D.is_point_in_polygon(sample, mask):
			return sample
	return (point + direction * 20).round()


static func draw_needle(image: Image, id: String, angle: float) -> void:
	var direction := Vector2.UP.rotated(angle)
	var is_clock := id == "clock"
	var source_center := CLOCK_CENTER if is_clock else COMPASS_CENTER
	var center := _source_point(source_center) - origins[id]
	if is_clock:
		for step in range(3, 74):
			var point := Vector2i((center + direction * step).round())
			image.set_pixelv(point, Color("963f31"))
		return

	var reach := 55.0
	for y in range(-56, 57):
		for x in range(-56, 57):
			var offset := Vector2(x, y)
			if offset.length_squared() < 8.5 * 8.5:
				continue
			var along := offset.dot(direction)
			var facet := offset.cross(direction)
			if absf(facet) > (reach - absf(along)) * 0.23:
				continue
			var ink := Color("af6446") if facet < 0.0 else Color("823f33")
			if along < 0.0:
				ink = Color("d9bf8b") if facet < 0.0 else Color("837653")
			image.set_pixelv(Vector2i(center.round()) + Vector2i(x, y), ink)
