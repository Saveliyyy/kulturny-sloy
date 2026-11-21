extends RefCounted
class_name CounterMat

const ART_SIZE := Vector2(1536, 1024)
const ART_BOUNDS := Rect2(212, 672, 1188, 205)
const REGION := Rect2(ART_BOUNDS.position / ART_SIZE, ART_BOUNDS.size / ART_SIZE)
const BACK_LEFT := 374.0
const FRONT_LEFT := 212.0
const BACK_WIDTH := 862.0
const FRONT_WIDTH := 1188.0
const MAT_EDGE := [
	Vector2(394, 674), Vector2(1217, 674), Vector2(1229, 676), Vector2(1239, 682),
	Vector2(1256, 701), Vector2(1365, 832), Vector2(1389, 859), Vector2(1392, 865),
	Vector2(1391, 870), Vector2(1386, 874), Vector2(1378, 875), Vector2(233, 875),
	Vector2(223, 874), Vector2(218, 870), Vector2(219, 864), Vector2(226, 854),
	Vector2(364, 686), Vector2(374, 678), Vector2(382, 675),
]


static func outline(size: Vector2) -> PackedVector2Array:
	var contour := PackedVector2Array()
	for point: Vector2 in MAT_EDGE:
		contour.append((point - ART_BOUNDS.position) / ART_BOUNDS.size * size)
	return contour


static func project(cell_fraction: Vector2, size: Vector2) -> Vector2:
	# Rows share a vanishing point, so the far edge has smaller cells.
	var depth := cell_fraction.y * BACK_WIDTH / lerpf(FRONT_WIDTH, BACK_WIDTH, cell_fraction.y)
	var left := lerpf(BACK_LEFT, FRONT_LEFT, depth)
	var x := left + cell_fraction.x * lerpf(BACK_WIDTH, FRONT_WIDTH, depth)
	return Vector2((x - ART_BOUNDS.position.x) / ART_BOUNDS.size.x, depth) * size


static func unproject(point: Vector2, size: Vector2) -> Vector2:
	var outer := point / size
	var width := lerpf(BACK_WIDTH, FRONT_WIDTH, outer.y)
	var left := lerpf(BACK_LEFT, FRONT_LEFT, outer.y)
	var x := ART_BOUNDS.position.x + outer.x * ART_BOUNDS.size.x
	return Vector2((x - left) / width, outer.y * FRONT_WIDTH / width)
