extends RefCounted
class_name ItemGrid

var columns: int
var rows: int
var items: Array[Dictionary] = []


func _init(width: int, height: int) -> void:
	columns = width
	rows = height
	for slot in columns * rows:
		items.append({})


func position_of(slot: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(slot % columns, slot / columns)


func slot_at(position: Vector2i) -> int:
	if not Rect2i(0, 0, columns, rows).has_point(position):
		return -1
	return position.y * columns + position.x


func area(slot: int, item: Dictionary) -> Rect2i:
	return Rect2i(position_of(slot), ItemCatalog.footprint(item["id"]))


func item_at(slot: int) -> Dictionary:
	if slot < 0 or slot >= items.size():
		return {}
	return items[slot]


func anchor_at(cell: int) -> int:
	if cell < 0 or cell >= items.size():
		return -1
	var position := position_of(cell)
	for slot in items.size():
		if not items[slot].is_empty() and area(slot, items[slot]).has_point(position):
			return slot
	return -1


func fits(item: Dictionary, slot: int, ignore_slot := -1) -> bool:
	if item.is_empty() or slot < 0 or slot >= items.size():
		return false
	var target := area(slot, item)
	if not Rect2i(0, 0, columns, rows).encloses(target):
		return false
	for other in items.size():
		if other != ignore_slot and not items[other].is_empty() and area(other, items[other]).intersects(target):
			return false
	return true


func put_first(item: Dictionary) -> int:
	for slot in items.size():
		if fits(item, slot):
			items[slot] = item
			return slot
	return -1


func neighbors(slot: int) -> Array[int]:
	var result: Array[int] = []
	var region := area(slot, items[slot])
	for other in items.size():
		if other == slot or items[other].is_empty() or items[other].get("offered", false):
			continue
		var next := area(other, items[other])
		var vertical := region.position.y < next.end.y and next.position.y < region.end.y
		var horizontal := region.position.x < next.end.x and next.position.x < region.end.x
		if (vertical and (region.end.x == next.position.x or next.end.x == region.position.x)) or (horizontal and (region.end.y == next.position.y or next.end.y == region.position.y)):
			result.append(other)
	return result
