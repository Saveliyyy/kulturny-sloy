extends Control
class_name ItemView

signal tool_dropped(data: Dictionary)
signal measurement_ready(tool: String)

const LENS_SHADER := preload("res://scripts/inspection_lens.gdshader")
const GLASS_SIZE := 148.0
const MAGNIFICATION := 2.5
const WEIGH_SECONDS := 1.2
const TEMPERATURE_SECONDS := 1.1
const SAMOVAR_ART := Rect2(-113, -102, 226, 194)
const ITEM_BOUNDS := Rect2(-104, -84, 208, 168)
const ROOM_ART_SIZE := Vector2(1536, 1024)
const TOOLBOX_PATCH := Rect2(1354, 598, 182, 207)
const DESK_CLOCK := Vector2(1399, 813)
const LID_TEXTURE := [Vector2(1438, 753), Vector2(1530, 753), Vector2(1530, 780), Vector2(1438, 780)]
const VISITOR_ARRIVAL := 0.64
const WINDOW_PANES := [
	Rect2(0.526, 0.006, 0.313, 0.448),
	Rect2(0.873, 0.135, 0.122, 0.292),
]
const LAMP_OUTLINES := [
	[Vector2(0, 669), Vector2(14, 657), Vector2(49, 655), Vector2(63, 682), Vector2(116, 700), Vector2(132, 714), Vector2(132, 736), Vector2(109, 751), Vector2(0, 750)],
	[Vector2(11, 515), Vector2(49, 514), Vector2(56, 531), Vector2(45, 545), Vector2(51, 666), Vector2(17, 666), Vector2(19, 544), Vector2(10, 536)],
	[Vector2(94, 320), Vector2(113, 319), Vector2(133, 333), Vector2(135, 351), Vector2(116, 347), Vector2(107, 336), Vector2(89, 338), Vector2(70, 350), Vector2(63, 373), Vector2(63, 397), Vector2(47, 424), Vector2(29, 452), Vector2(28, 479), Vector2(43, 514), Vector2(27, 520), Vector2(13, 495), Vector2(12, 467), Vector2(23, 435), Vector2(46, 405), Vector2(47, 365), Vector2(59, 341), Vector2(76, 327)],
	[Vector2(101, 354), Vector2(124, 344), Vector2(145, 344), Vector2(157, 366), Vector2(178, 372), Vector2(204, 378), Vector2(230, 392), Vector2(250, 409), Vector2(266, 436), Vector2(273, 467), Vector2(263, 479), Vector2(229, 494), Vector2(178, 506), Vector2(128, 517), Vector2(83, 519), Vector2(62, 514), Vector2(62, 498), Vector2(69, 455), Vector2(83, 421), Vector2(100, 391), Vector2(103, 372)],
]

static var art_loaded := false
static var room_art: Texture2D
static var toolbox_art: Texture2D
static var visitor_art: Dictionary[String, Texture2D] = {}
static var stock_art: Dictionary[String, Texture2D] = {}
static var item_contours: Dictionary = {}
static var item_masks: Dictionary[String, BitMap] = {}

var show_room := true
var sprite_fill := 0.88
var examining := false
var visitor := ""
var visitor_elapsed := 0.0
var speaking := false
var hover_outline := false
var outline_color := Color("ffe0a1")
var weather_day := 1
var weather_time := 0.0
var calendar_day := GameState.FIRST_DATE
var clock_minutes := float(GameState.MORNING)
var night_level := 0.0
var toolbox_openness := 0.0
var lamp_light: GradientTexture2D
var item_id := ""
var active_tool := ""
var lens_active: bool:
	get: return active_tool == "lens"
var lens_position := Vector2.INF
var lens_surface: ColorRect
var lens_material: ShaderMaterial
var meters: BenchMeters
var probe_position := Vector2.INF
var probe_held := false
var measurement_progress := 0.0
var measurement_finished := false
var rotation_angle := 0.0
var dial_plate: Image
var dial_texture: ImageTexture
var dial_time := 0.0
var dial_angle := INF


func _ready() -> void:
	if not art_loaded:
		room_art = PixelArt.load_asset("counter-background", Vector2i(640, 428))
		toolbox_art = PixelArt.load_asset("counter-background-toolbox", Vector2i(640, 428))
		for name: String in VisitorSprites.PORTRAITS:
			visitor_art[name] = VisitorSprites.texture(name)
		for id: String in ObjectSprites.SOURCES:
			stock_art[id] = ObjectSprites.texture(id)
		for id: String in ItemCatalog.ITEMS:
			stock_art[id] = stock_art[ItemCatalog.art_id(id)]
		art_loaded = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP if show_room else Control.MOUSE_FILTER_IGNORE
	set_process(show_room)
	resized.connect(queue_redraw)
	if show_room:
		var glow := Gradient.new()
		glow.offsets = PackedFloat32Array([0.0, 0.48, 1.0])
		glow.colors = PackedColorArray([Color("ffbc645f"), Color("e2963830"), Color("e2963800")])
		lamp_light = GradientTexture2D.new()
		lamp_light.gradient = glow
		lamp_light.fill = GradientTexture2D.FILL_RADIAL
		lamp_light.fill_from = Vector2(0.35, 0.47)
		lamp_light.fill_to = Vector2(0.70, 0.47)
		meters = BenchMeters.new()
		meters.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meters.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		add_child(meters)
		lens_material = ShaderMaterial.new()
		lens_material.shader = LENS_SHADER
		lens_surface = ColorRect.new()
		lens_surface.size = Vector2.ONE * GLASS_SIZE
		lens_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lens_surface.material = lens_material
		lens_surface.hide()
		add_child(lens_surface)
		mouse_exited.connect(_clear_tool_hover)


func show_item(next_id: String) -> void:
	item_id = next_id
	equip_tool("")
	rotation_angle = 0.0
	if show_room:
		dial_plate = null
		dial_texture = null
		dial_time = 0.0
		dial_angle = INF
		var art_id := ItemCatalog.art_id(item_id)
		if art_id in ["clock", "compass"]:
			dial_plate = ObjectSprites.sprite_image(art_id)
			dial_texture = ImageTexture.create_from_image(dial_plate)
			_update_dial()
	queue_redraw()


func equip_tool(tool: String) -> void:
	active_tool = tool
	measurement_progress = 0.0
	measurement_finished = false
	_clear_tool_hover()
	if lens_active:
		lens_position = get_local_mouse_position()
	elif active_tool == "thermometer":
		probe_position = get_local_mouse_position()
	mouse_default_cursor_shape = CURSOR_CROSS if active_tool in ["lens", "thermometer"] else CURSOR_ARROW
	if meters != null:
		meters.tool = tool
		meters.queue_redraw()


func set_examining(enabled: bool) -> void:
	if examining == enabled:
		return
	examining = enabled
	equip_tool("")
	rotation_angle = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	weather_time += delta
	visitor_elapsed += delta
	if is_visible_in_tree():
		if examining and dial_texture != null:
			dial_time += delta
			_update_dial()
		if examining and not active_tool.is_empty():
			_update_tool(delta)
		queue_redraw()


func set_visitor(next_visitor: String) -> void:
	visitor = next_visitor
	visitor_elapsed = 0.0


func set_hover_outline(enabled: bool, ink := Color("ffe0a1")) -> void:
	if hover_outline != enabled or outline_color != ink:
		hover_outline = enabled
		outline_color = ink
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if item_id.is_empty() or not examining:
		return
	if event is InputEventMouseMotion:
		if lens_active:
			lens_position = event.position
		elif active_tool == "thermometer":
			probe_position = event.position
	if active_tool == "thermometer" and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		probe_position = event.position
		probe_held = event.pressed
		accept_event()
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		rotation_angle += -0.18 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.18
		queue_redraw()
		accept_event()


func _can_drop_data(at: Vector2, data: Variant) -> bool:
	return examining and data is Dictionary and data.get("location") == "documents" \
		and InspectionCatalog.TOOLS.has(data.get("item_id", "")) and _hits_item(at)


func _drop_data(at: Vector2, data: Variant) -> void:
	if _can_drop_data(at, data):
		tool_dropped.emit(data)


func _draw() -> void:
	if show_room:
		_draw_counter()
		if examining:
			_draw_examination_table()
			_draw_desk_clock()
		else:
			_draw_visitor()
			_draw_foreground_lamp()
			return
	if item_id.is_empty():
		return
	var art := _item_texture()
	if art == null:
		return
	var bounds := _art_bounds(art)
	var zoom := _sprite_zoom(bounds)
	draw_set_transform(_item_center(), rotation_angle, Vector2.ONE * zoom)
	draw_texture_rect(art, bounds, false)
	if hover_outline:
		_draw_item_outline(art, bounds)
	draw_set_transform(Vector2.ZERO)
	if examining and lens_surface.visible:
		var from := lens_position + Vector2(45, 45)
		var to := lens_position + Vector2(88, 88)
		draw_line(from, to, Color("342821"), 19)
		draw_line(from, to, Color("9f7651"), 13)
		draw_line(from + Vector2(2, -2), to + Vector2(2, -2), Color("d0a875"), 3)


func _art_bounds(art: Texture2D) -> Rect2:
	var limit := SAMOVAR_ART.size if ItemCatalog.art_id(item_id) == "samovar" else ITEM_BOUNDS.size
	var pixels := art.get_size()
	var dimensions := pixels * minf(limit.x / pixels.x, limit.y / pixels.y)
	return Rect2(-dimensions * 0.5, dimensions)


func _item_center() -> Vector2:
	if not show_room:
		return size * 0.5
	var lift := minf(measurement_progress * 2.5, 1.0) * 9.0 if active_tool == "scale" else 0.0
	return Vector2(size.x * 0.261, size.y * 0.458 - lift)


func _item_zoom() -> float:
	return clampf(size.y / 392.0, 1.28, 1.96)


func _sprite_zoom(bounds: Rect2) -> float:
	if show_room:
		return _item_zoom()
	return minf(size.x / bounds.size.x, size.y / bounds.size.y) * sprite_fill


func _uv_at(point: Vector2, art: Texture2D) -> Vector2:
	var bounds := _art_bounds(art)
	var zoom := _sprite_zoom(bounds)
	var local := (point - _item_center()).rotated(-rotation_angle) / maxf(zoom, 0.001)
	return (local - bounds.position) / bounds.size


func _hits_item(point: Vector2) -> bool:
	var art := stock_art.get(item_id) as Texture2D
	if art == null:
		return false
	var uv := _uv_at(point, art)
	return Rect2(Vector2.ZERO, Vector2.ONE).has_point(uv) and _item_mask(art).get_bitv(Vector2i(uv * art.get_size()))


func _item_texture() -> Texture2D:
	return dial_texture if dial_texture != null else stock_art.get(item_id)


func _update_dial() -> void:
	var art_id := ItemCatalog.art_id(item_id)
	var angle := ObjectSprites.COMPASS_BEARING - rotation_angle
	if art_id == "clock":
		var direction := -1.0 if item_id == "clock" else 1.0
		angle = ObjectSprites.CLOCK_START + direction * floorf(dial_time * 2.0) * TAU / 60.0
	if angle == dial_angle:
		return
	dial_angle = angle
	var frame := dial_plate.duplicate() as Image
	ObjectSprites.draw_needle(frame, art_id, dial_angle)
	dial_texture.update(frame)


func _update_tool(delta: float) -> void:
	var worktop := _worktop_rect()
	meters.worktop = worktop
	if lens_active:
		_update_lens()
		meters.queue_redraw()
		return
	var touching := probe_held and probe_position.is_finite() and worktop.has_point(probe_position) and _hits_item(probe_position)
	var elapsed := delta / (WEIGH_SECONDS if active_tool == "scale" else TEMPERATURE_SECONDS)
	var publish := false
	if not measurement_finished:
		measurement_progress = minf(measurement_progress + elapsed, 1.0) if active_tool == "scale" or touching else 0.0
		measurement_finished = measurement_progress >= 1.0
		publish = measurement_finished
	var bounds := _art_bounds(_item_texture())
	meters.artifact = Rect2(_item_center() + bounds.position * _item_zoom(), bounds.size * _item_zoom())
	meters.instrument = stock_art.get(active_tool)
	meters.probe = probe_position
	meters.touching = touching
	meters.progress = measurement_progress
	meters.reading_value = InspectionCatalog.reading_value(item_id, active_tool)
	meters.reading = InspectionCatalog.reading(item_id, active_tool) if measurement_finished else ""
	meters.queue_redraw()
	if publish:
		measurement_ready.emit(active_tool)


func _update_lens() -> void:
	var art := _item_texture()
	if art == null or not lens_position.is_finite() or not _worktop_rect().has_point(lens_position):
		lens_surface.hide()
		return
	var bounds := _art_bounds(art)
	lens_surface.position = (lens_position - lens_surface.size * 0.5).round()
	lens_material.set_shader_parameter("artifact", art)
	lens_material.set_shader_parameter("focus", _uv_at(lens_position, art))
	lens_material.set_shader_parameter("sample_span", lens_surface.size / (bounds.size * _item_zoom() * MAGNIFICATION))
	lens_material.set_shader_parameter("artifact_angle", rotation_angle)
	lens_surface.show()


func _clear_tool_hover() -> void:
	lens_position = Vector2.INF
	probe_position = Vector2.INF
	probe_held = false
	if lens_surface != null:
		lens_surface.hide()
	queue_redraw()


func _draw_visitor() -> void:
	if visitor.is_empty():
		return
	var picture := visitor_art.get(visitor) as Texture2D
	if picture == null:
		return
	var progress := clampf(visitor_elapsed / VISITOR_ARRIVAL, 0.0, 1.0)
	var stride := 1.0 - ease(progress, 0.46)
	var bob := sin(visitor_elapsed * 22.0) * stride * 10.0
	if speaking and progress >= 1.0:
		bob -= roundf(2.5 * (0.5 + 0.5 * sin(visitor_elapsed * 18.0)))
	var height := size.y * 0.52
	var width := height * picture.get_width() / picture.get_height()
	var standing_x := size.x * 0.19 - width * 0.32
	var destination := Rect2(lerpf(-width - 8.0, standing_x, 1.0 - stride),
		roundf(size.y * 0.13 + bob), width, height)
	draw_texture_rect(picture, destination, false)


func _item_mask(art: Texture2D) -> BitMap:
	if not item_masks.has(item_id):
		var mask := BitMap.new()
		mask.create_from_image_alpha(art.get_image(), 0.42)
		item_masks[item_id] = mask
	return item_masks[item_id]


func _draw_item_outline(art: Texture2D, bounds: Rect2) -> void:
	if not item_contours.has(item_id):
		item_contours[item_id] = _item_mask(art).opaque_to_polygons(Rect2i(Vector2i.ZERO, Vector2i(art.get_size())), 0.9)
	for contour: PackedVector2Array in item_contours[item_id]:
		var points := PackedVector2Array()
		for point in contour:
			points.append(bounds.position + point / art.get_size() * bounds.size)
		points.append(points[0])
		draw_polyline(points, outline_color, 4.0)


func _draw_foreground_lamp() -> void:
	if room_art == null:
		return
	for outline: Array in LAMP_OUTLINES:
		var points := PackedVector2Array()
		var uv := PackedVector2Array()
		for pixel: Vector2 in outline:
			uv.append(pixel / ROOM_ART_SIZE)
			points.append(pixel / ROOM_ART_SIZE * size)
		draw_colored_polygon(points, Color.WHITE.lerp(Color("dfab74"), night_level * 0.38), uv, room_art)


func _draw_counter() -> void:
	if room_art != null:
		draw_texture_rect(room_art, Rect2(Vector2.ZERO, size), false)
		_draw_scene_toolbox()
		if not examining:
			_draw_desk_clock()
		_draw_window_weather()
		_draw_room_light()
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("2d2b25"))
	var window := Rect2(size.x * 0.12, 12, size.x * 0.76, size.y * 0.52)
	draw_rect(window, Color("1e3532"))
	draw_rect(Rect2(window.position, Vector2(window.size.x, window.size.y * 0.55)), Color("30443d"))
	var horizon := window.end.y - 8
	for i in range(13):
		var x := window.position.x + (i + 0.5) * window.size.x / 13.0
		var height := 21.0 + (i * 19 % 53)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 17, horizon), Vector2(x, horizon - height), Vector2(x + 17, horizon)
		]), Color("26332a") if i % 2 == 0 else Color("2a3b30"))
	var mast := window.position.x + window.size.x * 0.79
	var top := window.position.y + window.size.y * 0.17
	draw_line(Vector2(mast, top), Vector2(mast - 13, horizon), Color("182822"), 3.0)
	draw_line(Vector2(mast, top), Vector2(mast + 13, horizon), Color("182822"), 3.0)
	draw_line(Vector2(mast - 6, top + 30), Vector2(mast + 6, top + 30), Color("182822"), 2.0)
	draw_circle(Vector2(mast, top), 3.5, Color("e9905d"))
	draw_rect(window, Color("4b3d2e"), false, 5.0)
	var desk := Rect2(0, size.y * 0.48, size.x, size.y * 0.52)
	draw_rect(desk, Color("624931"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(size.x * 0.24, desk.position.y + 11), Vector2(size.x * 0.76, desk.position.y + 11),
		Vector2(size.x * 0.97, size.y), Vector2(size.x * 0.03, size.y)
	]), Color("4d4b36"))
	_draw_room_light()


func _draw_desk_clock() -> void:
	var scale := size / ROOM_ART_SIZE
	draw_set_transform(DESK_CLOCK * scale, 0.0, scale)
	draw_rect(Rect2(-3, 69, 133, 9), Color("1a1916aa"))
	draw_rect(Rect2(4, 61, 113, 12), Color("251c13"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 10), Vector2(10, 0), Vector2(119, 0),
		Vector2(130, 10), Vector2(130, 64), Vector2(121, 70), Vector2(8, 70), Vector2(0, 62)]), Color("291e16"))
	draw_rect(Rect2(4, 11, 122, 52), Color("695139"))
	draw_line(Vector2(9, 8), Vector2(119, 8), Color("ad8051"), 3)
	var dial := Vector2(32, 36)
	draw_circle(dial, 26.0, Color("34271d"))
	draw_circle(dial, 23.0, Color("bd9660"))
	draw_circle(dial, 20.0, Color("e3c28a"))
	for tick in 12:
		var mark := Vector2.UP.rotated(tick * TAU / 12.0)
		draw_line((dial + mark * 15).round(), (dial + mark * 18).round(), Color("675037"), 1.5)
	var hour_hand := Vector2.UP.rotated(fposmod(clock_minutes, 720.0) * TAU / 720.0)
	var minute_hand := Vector2.UP.rotated(fposmod(clock_minutes, 60.0) * TAU / 60.0)
	draw_line(dial, (dial + hour_hand * 10).round(), Color("3c2b1b"), 3)
	draw_line(dial, (dial + minute_hand * 14).round(), Color("674024"), 2)
	draw_circle(dial, 2.3, Color("4c2c1a"))
	var paper := Rect2(62, 14, 57, 46)
	draw_rect(paper.grow(2), Color("33251c"))
	draw_rect(paper, Color("ead4a5"))
	draw_rect(Rect2(62, 14, 57, 13), Color("963f32"))
	draw_string(ThemeDB.fallback_font, Vector2(62, 25), "ИЮЛ 1983", HORIZONTAL_ALIGNMENT_CENTER, 57, 11, Color("fae1b6"))
	draw_string(ThemeDB.fallback_font, Vector2(62, 51), str(calendar_day), HORIZONTAL_ALIGNMENT_CENTER, 57, 24, Color("3c2b1b"))
	draw_set_transform(Vector2.ZERO)


func _draw_scene_toolbox() -> void:
	if toolbox_art == null:
		return
	# Keep the room's existing pixel alignment everywhere outside the retouched corner.
	var pixels := toolbox_art.get_size()
	var patch_position := TOOLBOX_PATCH.position / ROOM_ART_SIZE
	var patch_size := TOOLBOX_PATCH.size / ROOM_ART_SIZE
	draw_texture_rect_region(toolbox_art, Rect2(patch_position * size, patch_size * size),
		Rect2(patch_position * pixels, patch_size * pixels))
	var lid := DocumentHotspot.lid_at(toolbox_openness)
	var depth := lid[3] - lid[0]
	var hinge := lid[1] - lid[0]
	var face := hinge.cross(depth)
	draw_set_transform(Vector2.ZERO, 0.0, size / ROOM_ART_SIZE)
	if absf(face) > 8.0:
		var uv := PackedVector2Array()
		for point: Vector2 in LID_TEXTURE:
			uv.append(point / ROOM_ART_SIZE)
		draw_colored_polygon(lid, Color.WHITE, uv, toolbox_art)
		var outer := face > 0.0
		draw_colored_polygon(lid, Color("9b86524d") if outer else Color("252a2260"))
		var front := PackedVector2Array([lid[3], lid[2], lid[2] + Vector2(0, 6), lid[3] + Vector2(0, 6)])
		draw_colored_polygon(front, Color("494733") if outer else Color("403b2b"))
		draw_polyline(PackedVector2Array([lid[0], lid[3], lid[2]]), Color("171711"), 5)
		draw_polyline(PackedVector2Array([lid[0] + Vector2(2, 1), lid[3] + Vector2(2, -2), lid[2] + Vector2(0, -2)]), Color("a18a59"), 2)
		if outer:
			var grip := (lid[0] + hinge * 0.41 + depth * 0.57).snapped(Vector2(2, 2))
			draw_line(grip, grip + Vector2(39, -1), Color("232115"), 10)
			draw_line(grip + Vector2(2, -4), grip + Vector2(36, -5), Color("a18d5f"), 4)
			draw_line(grip + Vector2(5, -1), grip + Vector2(34, -2), Color("746040"), 2)
	draw_line(lid[0], lid[1], Color("343022"), 3)
	draw_rect(Rect2(lid[0] + hinge * 0.28 - Vector2(4, 1), Vector2(12, 3)), Color("92764a"))
	draw_set_transform(Vector2.ZERO)


func _draw_room_light() -> void:
	if night_level <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.045, 0.085, night_level * 0.73))
	for pane in WINDOW_PANES:
		draw_rect(Rect2(pane.position * size, pane.size * size), Color(0.02, 0.04, 0.09, night_level * 0.42))
	draw_texture_rect(lamp_light, Rect2(size * Vector2(-0.14, 0.28), size * Vector2(0.70, 0.72)), false,
		Color(1.0, 1.0, 1.0, night_level))


func _draw_window_weather() -> void:
	var dimness := 0.055 + 0.035 * sin(weather_time * 0.34)
	for pane: Rect2 in WINDOW_PANES:
		var glass := Rect2(pane.position * size, pane.size * size)
		if weather_day == 2:
			draw_rect(glass, Color(0.55, 0.66, 0.63, dimness))
			for band in 4:
				var y := glass.position.y + fposmod(band * 23.0 + weather_time * 4.0, glass.size.y - 10.0)
				draw_rect(Rect2(glass.position.x, y, glass.size.x, 7), Color("afc3b60d"))
			continue
		var strength := 0.22 if weather_day == 1 else 0.42
		draw_rect(glass, Color(0.06, 0.12, 0.15, dimness * 2.0 * strength))
		var count := int(glass.size.x / 10.0 * (1.0 if weather_day == 1 else 1.8))
		for drop in count:
			var start := Vector2(
				glass.position.x + fposmod(drop * 57.13 - weather_time * 25.0, glass.size.x - 13.0) + 9.0,
				glass.position.y + fposmod(drop * 39.91 + weather_time * (151.0 + 7.0 * (drop % 5)), glass.size.y - 15.0)
			)
			draw_line(start.round(), (start + Vector2(-8, 14)).round(), Color(0.63, 0.80, 0.81, strength), 2)


func _worktop_rect() -> Rect2:
	return Rect2(size.x * 0.065, size.y * 0.19, size.x * 0.473, size.y * 0.54)


func _draw_examination_table() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("161c16b5"))
	var worktop := _worktop_rect()
	draw_rect(worktop.grow(15), Color("171d19b0"))
	draw_rect(worktop.grow(11), Color("31271c"))
	draw_rect(worktop.grow(7), Color("a98450"), false, 3)
	draw_rect(worktop, Color("383f34"))
	if room_art != null:
		var pixels := room_art.get_size()
		var cloth := Rect2(pixels * Vector2(0.41, 0.73), pixels * Vector2(0.18, 0.095))
		draw_texture_rect_region(room_art, worktop, cloth, Color("b4bdb0"))
	draw_rect(worktop.grow(-8), Color("67654b"), false, 2)
	var ruler := Rect2(worktop.position.x + 17, worktop.end.y - 29, worktop.size.x - 34, 16)
	draw_rect(ruler, Color("242f27a8"))
	draw_line(ruler.position, Vector2(ruler.end.x, ruler.position.y), Color("7f7860"))
	for tick in int(ruler.size.x / 11.0):
		var x := ruler.position.x + 7 + tick * 11
		var length := 12 if tick % 4 == 0 else 6
		draw_line(Vector2(x, ruler.position.y), Vector2(x, ruler.position.y + length), Color("b1a281"))
	for corner in [worktop.position, worktop.end, Vector2(worktop.end.x, worktop.position.y), Vector2(worktop.position.x, worktop.end.y)]:
		draw_circle(corner, 4, Color("746144"))
		draw_line(corner + Vector2(-2, 1), corner + Vector2(2, -1), Color("c3a879"))
