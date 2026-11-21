extends Control
class_name InventoryBoard

signal cell_selected(location: String, cell: int)
signal item_activated(location: String, anchor: int)
signal item_moved(location: String, anchor: int)
signal tool_dropped(location: String, anchor: int, data: Dictionary)

var state: GameState
var location := "counter"
var on_counter := false
var on_mat := false
var fill_available := false
var cell_scale := 0.83
var sprite_fill := 0.88
var selected := -1
var danger: Array[int] = []
var previews: Dictionary[int, ItemView] = {}
var drop_region := Rect2i()
var drop_valid := false
var pressed_cell := -1
var hovered_anchor := -1
var dragging_anchor := -1
var drop_anchor := -1
var drop_progress := 1.0
var drop_tween: Tween
var mat_outline := PackedVector2Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_resize_board)
	mouse_exited.connect(_clear_hover)
	_resize_board()


func _resize_board() -> void:
	if on_mat:
		mat_outline = CounterMat.outline(size)
	_layout_pieces()


func display(game_state: GameState, current: int, at_risk: Array[int]) -> void:
	state = game_state
	selected = current
	danger = at_risk
	var grid := state.grid(location)
	for anchor in grid.items.size():
		var piece := grid.items[anchor]
		if piece.is_empty() or piece.get("broken", false):
			if previews.has(anchor):
				previews[anchor].queue_free()
				previews[anchor].hide()
				previews.erase(anchor)
			continue
		if not previews.has(anchor):
			var preview := ItemView.new()
			preview.show_room = false
			preview.sprite_fill = sprite_fill
			add_child(preview)
			previews[anchor] = preview
		if previews[anchor].item_id != piece["id"]:
			previews[anchor].show_item(piece["id"])
	_layout_pieces()


func cell_center(cell: int) -> Vector2:
	return _project(Vector2(state.grid(location).position_of(cell)) + Vector2(0.5, 0.5))


func piece_rect(anchor: int) -> Rect2:
	if not previews.has(anchor):
		return Rect2()
	return previews[anchor].get_global_rect()


func animate_sample(anchor: int, wait: float) -> void:
	if drop_tween:
		drop_tween.kill()
	drop_anchor = anchor
	_drop_frame(0.0)
	drop_tween = create_tween()
	drop_tween.tween_interval(wait)
	drop_tween.tween_method(_drop_frame, 0.0, 1.0, 0.36).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	drop_tween.tween_callback(_finish_drop)


func sample_is_landing() -> bool:
	return drop_anchor >= 0 and drop_progress < 1.0


func grid_is_visible() -> bool:
	return location == "documents" or _is_item_drag(get_viewport().gui_get_drag_data())


func _is_item_drag(data: Variant) -> bool:
	return data is Dictionary and data.has_all(["location", "anchor", "offset"])


func _drop_frame(progress: float) -> void:
	drop_progress = progress
	_layout_pieces()


func _finish_drop() -> void:
	drop_anchor = -1
	_layout_pieces()


func _layout_pieces() -> void:
	if state == null:
		return
	var grid := state.grid(location)
	for anchor in previews:
		var region := grid.area(anchor, grid.items[anchor])
		var bounds := _screen_area(region).grow(-1.0 if on_counter else -2.0)
		if on_mat:
			bounds.size.y = maxf(bounds.size.y, bounds.size.x * 0.72 * region.size.y / region.size.x)
			var center := _project(Vector2(region.position) + Vector2(region.size) * 0.5)
			bounds.position = center - bounds.size * 0.5
		if anchor == dragging_anchor:
			previews[anchor].modulate.a = 0.0
		elif anchor == drop_anchor and grid.items[anchor].get("offered", false):
			bounds.position.y -= (1.0 - drop_progress) * 96.0
			previews[anchor].modulate.a = clampf(drop_progress * 6.0, 0.0, 1.0)
		else:
			previews[anchor].modulate.a = 1.0
		previews[anchor].position = bounds.position
		previews[anchor].size = bounds.size
		var at_risk := danger.has(anchor)
		var ink := Color("e99463") if at_risk else Color("ffe0a1")
		previews[anchor].set_hover_outline(at_risk or anchor == hovered_anchor or anchor == selected, ink)
	queue_redraw()


func _draw() -> void:
	if state == null:
		return
	var grid := state.grid(location)
	var entire := Rect2i(0, 0, grid.columns, grid.rows)
	var show_cells := grid_is_visible()
	if show_cells:
		_draw_grid(grid, entire)
	elif not on_mat:
		_fill(entire, Color("1c2923ec"))
	for anchor in grid.items.size():
		var piece := grid.items[anchor]
		if piece.is_empty() or (anchor == drop_anchor and piece.get("offered", false) and drop_progress < 0.35):
			continue
		var region := grid.area(anchor, piece)
		if show_cells and anchor != dragging_anchor:
			_draw_occupied(region, anchor, piece)
		if piece.get("broken", false):
			var rect := _screen_area(region)
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(3, 20), "×",
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 6, 19, Color("e99463"))
	if show_cells and drop_region.has_area():
		var color := Color("b1ddb1") if drop_valid else Color("ed8c66")
		_stroke(drop_region, color, 2)


func _draw_grid(grid: ItemGrid, entire: Rect2i) -> void:
	if on_counter:
		var visitor_tint := Color("d0a96b17") if on_mat else Color("4e4637c4")
		var player_tint := Color("80c6a823") if on_mat else Color("31473ece")
		_fill(Rect2i(0, 0, grid.columns, GameState.PLAYER_ROW), visitor_tint)
		_fill(Rect2i(0, GameState.PLAYER_ROW, grid.columns, grid.rows - GameState.PLAYER_ROW), player_tint)
	else:
		_fill(entire, Color("1c2923ec"))
	for x in range(1, grid.columns):
		_grid_line(Vector2(x, 0), Vector2(x, grid.rows), Color("e2cca896"), 1)
	for y in range(1, grid.rows):
		var split := location == "counter" and y == GameState.PLAYER_ROW
		var ink := Color("f1cd91d9") if split else Color("e2cca896")
		_grid_line(Vector2(0, y), Vector2(grid.columns, y), ink, 2 if split else 1)
	_stroke(entire, Color("d5b57ca8"), 1)


func _draw_occupied(region: Rect2i, anchor: int, piece: Dictionary) -> void:
	var fill := Color("354438b8")
	var frame := Color("8b7751")
	if piece.get("offered", false):
		fill = Color("624d358c")
		frame = Color("e4b671")
	elif danger.has(anchor):
		fill = Color("5e3c2ec4")
		frame = Color("e99463")
	elif anchor == selected or anchor == hovered_anchor:
		frame = Color("a2cfb0")
	_fill(region, fill)
	_stroke(region, frame, 1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var pointed := state.grid(location).anchor_at(_cell_for_item(event.position))
		mouse_default_cursor_shape = CURSOR_POINTING_HAND if pointed >= 0 else CURSOR_ARROW
		if hovered_anchor != pointed:
			hovered_anchor = pointed
			_layout_pieces()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _cell_for_item(event.position)
		if event.pressed:
			pressed_cell = cell
			return
		var clicked := cell >= 0 and pressed_cell == cell and not get_viewport().gui_is_dragging()
		pressed_cell = -1
		if not clicked:
			return
		var grid := state.grid(location)
		var anchor := grid.anchor_at(cell)
		if anchor == drop_anchor and sample_is_landing():
			return
		var item := grid.item_at(anchor)
		if item.get("offered", false) or ItemCatalog.is_desk_item(item.get("id", "")):
			item_activated.emit(location, anchor)
		else:
			cell_selected.emit(location, cell)
		accept_event()


func _get_tooltip(at_position: Vector2) -> String:
	if state == null:
		return ""
	var grid := state.grid(location)
	var entry := grid.item_at(grid.anchor_at(_cell_for_item(at_position)))
	if entry.is_empty():
		return ""
	var footprint := ItemCatalog.footprint(entry["id"])
	var title := ItemCatalog.item_name(entry["id"])
	var ownership := "\nВещь посетителя" if entry.get("offered", false) else ""
	return "%s · %d×%d%s" % [title, footprint.x, footprint.y, ownership]


func _get_drag_data(at_position: Vector2) -> Variant:
	pressed_cell = -1
	var grid := state.grid(location)
	var cell := _cell_for_item(at_position)
	var anchor := grid.anchor_at(cell)
	var item := grid.item_at(anchor)
	if not previews.has(anchor) or (anchor == drop_anchor and sample_is_landing()):
		return null
	var cursor_anchor := Control.new()
	cursor_anchor.name = "DragPreview"
	cursor_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ghost := ItemView.new()
	ghost.show_room = false
	var display := previews[anchor]
	ghost.sprite_fill = display.sprite_fill
	ghost.size = display.size
	ghost.position = display.position - at_position
	ghost.show_item(item["id"])
	cursor_anchor.add_child(ghost)
	set_drag_preview(cursor_anchor)
	dragging_anchor = anchor
	_clear_hover()
	return {"location": location, "anchor": anchor, "offset": grid.position_of(cell) - grid.position_of(anchor), "item_id": item["id"]}


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not _is_item_drag(data):
		return false
	var cell := _cell_at(at_position)
	var grid := state.grid(location)
	var inspected := _inspection_anchor(at_position, data)
	if inspected >= 0:
		drop_region = grid.area(inspected, grid.item_at(inspected))
		drop_valid = true
		queue_redraw()
		return true
	if cell < 0:
		_clear_drop()
		return false
	var target: Vector2i = grid.position_of(cell) - data["offset"]
	var anchor := grid.slot_at(target)
	var item := state.grid(data["location"]).item_at(data["anchor"])
	if item.is_empty():
		return false
	drop_region = Rect2i(target, ItemCatalog.footprint(item["id"]))
	drop_valid = state.can_move(data["location"], data["anchor"], location, anchor)
	queue_redraw()
	return drop_valid


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var inspected := _inspection_anchor(at_position, data)
	if inspected >= 0:
		_clear_drop()
		tool_dropped.emit(location, inspected, data)
		return
	var cell := _cell_at(at_position)
	if cell < 0:
		return
	var grid := state.grid(location)
	var anchor := grid.slot_at(grid.position_of(cell) - data["offset"])
	if state.move_item(data["location"], data["anchor"], location, anchor):
		item_moved.emit(location, anchor)
	_clear_drop()


func _inspection_anchor(point: Vector2, data: Dictionary) -> int:
	if location == "documents" or state.tool_kind(data).is_empty():
		return -1
	var grid := state.grid(location)
	var anchor := grid.anchor_at(_cell_for_item(point))
	var target := grid.item_at(anchor)
	if target.is_empty() or target.get("broken", false) or ItemCatalog.is_desk_item(target["id"]):
		return -1
	if anchor == drop_anchor and sample_is_landing():
		return -1
	return anchor


func _cell_for_item(point: Vector2) -> int:
	if state == null:
		return -1
	var cell := _cell_at(point)
	var grid := state.grid(location)
	if grid.anchor_at(cell) >= 0:
		return cell
	var anchor := _sprite_anchor_at(point)
	if anchor < 0 or cell < 0:
		return anchor if anchor >= 0 else cell
	var square := grid.position_of(cell)
	var footprint := grid.area(anchor, grid.item_at(anchor))
	return grid.slot_at(square.clamp(footprint.position, footprint.end - Vector2i.ONE))


func _sprite_anchor_at(point: Vector2) -> int:
	for index in range(get_child_count() - 1, -1, -1):
		var sprite := get_child(index) as ItemView
		if sprite != null and sprite.visible and sprite.modulate.a > 0 and sprite._hits_item(point - sprite.position):
			var anchor: Variant = previews.find_key(sprite)
			if anchor != null:
				return anchor
	return -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		queue_redraw()
	elif what == NOTIFICATION_DRAG_END:
		if dragging_anchor >= 0:
			dragging_anchor = -1
			_layout_pieces()
		_clear_drop()


func _clear_drop() -> void:
	drop_region = Rect2i()
	queue_redraw()


func _clear_hover() -> void:
	hovered_anchor = -1
	_clear_drop()
	_layout_pieces()


func cell_size() -> Vector2:
	var grid := state.grid(location)
	var available := size / Vector2(grid.columns, grid.rows)
	if fill_available:
		return available.max(Vector2.ONE)
	return Vector2.ONE * maxf(1, floorf(minf(available.x, available.y) * cell_scale))


func _origin() -> Vector2:
	var grid := state.grid(location)
	return ((size - Vector2(grid.columns, grid.rows) * cell_size()) * 0.5).round()


func _screen_area(region: Rect2i) -> Rect2:
	if not on_mat:
		return Rect2(_project(Vector2(region.position)), Vector2(region.size) * cell_size())
	var corners := _quad(region)
	var bounds := Rect2(corners[0], Vector2.ZERO)
	for corner in corners:
		bounds = bounds.expand(corner)
	return bounds


func _project(point: Vector2) -> Vector2:
	if on_mat:
		var grid := state.grid(location)
		return CounterMat.project(point / Vector2(grid.columns, grid.rows), size)
	return _origin() + point * cell_size()


func _quad(region: Rect2i) -> PackedVector2Array:
	return PackedVector2Array([
		_project(Vector2(region.position)), _project(Vector2(region.end.x, region.position.y)),
		_project(Vector2(region.end)), _project(Vector2(region.position.x, region.end.y)),
	])


func _grid_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var segment := PackedVector2Array([_project(from), _project(to)])
	if on_mat:
		for clipped in Geometry2D.intersect_polyline_with_polygon(segment, mat_outline):
			draw_polyline(clipped, color, width)
	else:
		draw_line(segment[0], segment[1], color, width)


func _fill(region: Rect2i, color: Color) -> void:
	if on_mat:
		for clipped in Geometry2D.intersect_polygons(_quad(region), mat_outline):
			draw_colored_polygon(clipped, color)
	else:
		draw_rect(_screen_area(region), color)


func _stroke(region: Rect2i, color: Color, width: float) -> void:
	if on_mat:
		for clipped in Geometry2D.intersect_polygons(_quad(region), mat_outline):
			clipped.append(clipped[0])
			draw_polyline(clipped, color, width)
	else:
		draw_rect(_screen_area(region), color, false, width)


func _cell_at(position: Vector2) -> int:
	if state == null:
		return -1
	var grid := state.grid(location)
	if on_mat:
		if not Geometry2D.is_point_in_polygon(position, mat_outline):
			return -1
		var cells := CounterMat.unproject(position, size) * Vector2(grid.columns, grid.rows)
		return grid.slot_at(Vector2i(cells.floor()))
	return grid.slot_at(Vector2i(((position - _origin()) / cell_size()).floor()))


func _has_point(position: Vector2) -> bool:
	if on_mat:
		return Geometry2D.is_point_in_polygon(position, mat_outline) or _sprite_anchor_at(position) >= 0
	return Rect2(Vector2.ZERO, size).has_point(position) or _sprite_anchor_at(position) >= 0
