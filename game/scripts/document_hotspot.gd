extends Button
class_name DocumentHotspot

signal openness_changed(progress: float)

const ART_SIZE := Vector2(1536, 1024)
const HIT_REGION := Rect2(1354, 567, 182, 225)
const REGION := Rect2(HIT_REGION.position / ART_SIZE, HIT_REGION.size / ART_SIZE)
const HINGE_LEFT := Vector2(1367, 633)
const HINGE_RIGHT := Vector2(1570, 632)
const DEPTH := Vector2(50, 52)
const CASE := [HINGE_LEFT, Vector2(1536, 632), Vector2(1536, 787), Vector2(1412, 789),
	Vector2(1398, 779), Vector2(1364, 727), Vector2(1364, 642)]
const OPEN_ANGLE := PI * 0.53
const SWING_TIME := 0.36

var openness := 0.0:
	set(value):
		openness = value
		queue_redraw()
		openness_changed.emit(value)
var hinge: Tween


func _ready() -> void:
	for notice in [mouse_entered, mouse_exited, focus_entered, focus_exited, resized]:
		notice.connect(queue_redraw)


func set_open(open: bool, animate := true) -> void:
	if hinge:
		hinge.kill()
	var destination := 1.0 if open else 0.0
	if not animate or is_equal_approx(destination, openness):
		openness = destination
		return
	hinge = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hinge.tween_property(self, "openness", destination, SWING_TIME * absf(destination - openness))


static func lid_at(progress: float) -> PackedVector2Array:
	var angle := OPEN_ANGLE * progress
	var projected_depth := (DEPTH * cos(angle) - Vector2(0, 53.0 * sin(angle))).snapped(Vector2(2, 2))
	return PackedVector2Array([HINGE_LEFT, HINGE_RIGHT, HINGE_RIGHT + projected_depth, HINGE_LEFT + projected_depth])


func _lid_points() -> PackedVector2Array:
	return lid_at(openness)


func _has_point(position: Vector2) -> bool:
	if size.x <= 0 or size.y <= 0:
		return false
	var art_position := HIT_REGION.position + position / size * HIT_REGION.size
	return Geometry2D.is_point_in_polygon(art_position, PackedVector2Array(CASE)) or (
		openness > 0.0 and Geometry2D.is_point_in_polygon(art_position, _lid_points()))


func _draw() -> void:
	if not is_hovered() and not has_focus():
		return
	var points := PackedVector2Array()
	for point: Vector2 in CASE:
		points.append(((point - HIT_REGION.position) * size / HIT_REGION.size).round())
	points.append(points[0])
	draw_polyline(points, Color("e3c18b9a"), 1)
