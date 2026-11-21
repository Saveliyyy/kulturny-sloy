extends RefCounted
class_name GameSave

const VERSION := 1
const COUNTS := ["day", "money", "customer", "offers_left", "damage", "offered_slot"]
const FLAGS := ["tanya_told", "tanya_discussed_marks", "tanya_samovar_bought", "compass_returned", "field_enhanced", "ended"]
const GRIDS := ["counter", "warehouse", "documents"]

var base_path: String
var generation := 0
var active_slot := -1
var saved_snapshot: Dictionary = {}
var unreadable := false


func _init(path := "user://progress") -> void:
	base_path = path


func load_progress() -> GameState:
	generation = 0
	active_slot = -1
	saved_snapshot.clear()
	var newest: GameState
	var found := false
	for slot in 2:
		if not FileAccess.file_exists(slot_path(slot)):
			continue
		found = true
		var file := FileAccess.open(slot_path(slot), FileAccess.READ)
		if file == null:
			continue
		var record: Variant = file.get_var(false)
		if not record is Dictionary or record.get("version") != VERSION or not record.get("generation") is int:
			continue
		if record["generation"] <= generation:
			continue
		var loaded := _restore(record.get("state"))
		if loaded == null:
			continue
		newest = loaded
		generation = record["generation"]
		active_slot = slot
		saved_snapshot = record["state"]
	unreadable = found and newest == null
	return newest


func store_progress(state: GameState) -> Error:
	var snapshot := _snapshot(state)
	if snapshot == saved_snapshot:
		return OK
	var slot := 1 if active_slot == 0 else 0
	var path := ProjectSettings.globalize_path(slot_path(slot))
	var pending := path + ".pending"
	var file := FileAccess.open(pending, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var({"version": VERSION, "generation": generation + 1, "state": snapshot}, false)
	file.flush()
	var result := file.get_error()
	file.close()
	if result == OK and FileAccess.file_exists(path):
		result = DirAccess.remove_absolute(path)
	if result == OK:
		result = DirAccess.rename_absolute(pending, path)
	if result != OK:
		return result
	generation += 1
	active_slot = slot
	saved_snapshot = snapshot
	return OK


func slot_path(slot: int) -> String:
	return "%s-%d.save" % [base_path, slot]


static func _snapshot(state: GameState) -> Dictionary:
	var snapshot := {"night_report": state.night_report.duplicate()}
	for key: String in COUNTS + FLAGS:
		snapshot[key] = state.get(key)
	for location: String in GRIDS:
		snapshot[location] = state.grid(location).items.duplicate(true)
	return snapshot


static func _restore(snapshot: Variant) -> GameState:
	if not snapshot is Dictionary:
		return null
	for key: String in COUNTS:
		if not snapshot.get(key) is int:
			return null
	for key: String in FLAGS:
		if not snapshot.get(key) is bool:
			return null
	var day: int = snapshot["day"]
	if day < 1 or day > GameState.LAST_DAY or snapshot["money"] < 0 or snapshot["damage"] < 0:
		return null
	var visitors: int = ItemCatalog.DEALS[day - 1].size()
	if snapshot["customer"] < 0 or snapshot["customer"] > visitors or snapshot["offers_left"] not in range(1, GameState.MAX_OFFERS + 1):
		return null
	if snapshot["ended"] and (day != GameState.LAST_DAY or snapshot["customer"] != visitors):
		return null
	if snapshot["field_enhanced"] and snapshot["money"] < GameState.FIELD_COST:
		return null
	var state := GameState.new()
	for key: String in COUNTS + FLAGS:
		state.set(key, snapshot[key])
	for location: String in GRIDS:
		if not _restore_grid(state, location, snapshot.get(location)):
			return null
	var slot := state.offered_slot
	if slot < -1 or slot >= state.counter.items.size():
		return null
	if slot >= 0:
		var offer := state.counter.item_at(slot)
		if not offer.get("offered", false) or offer.get("id") != state.active_deal().get("id"):
			return null
	var report: Variant = snapshot.get("night_report")
	if not report is Array:
		return null
	for text: Variant in report:
		if not text is String:
			return null
		state.night_report.append(text)
	return state


static func _restore_grid(state: GameState, location: String, slots: Variant) -> bool:
	var grid := state.grid(location)
	if not slots is Array or slots.size() != grid.items.size():
		return false
	for slot in grid.items.size():
		grid.items[slot] = {}
	for slot in slots.size():
		var item: Variant = slots[slot]
		if not item is Dictionary:
			return false
		if item.is_empty():
			continue
		if not _valid_item(item, location) or not grid.fits(item, slot):
			return false
		if item.get("offered", false) and (location != "counter" or slot != state.offered_slot):
			return false
		grid.items[slot] = item.duplicate(true)
	return true


static func _valid_item(item: Dictionary, location: String) -> bool:
	var id: Variant = item.get("id")
	if not id is String or not (ItemCatalog.ITEMS.has(id) or ItemCatalog.DESK_ITEMS.has(id)):
		return false
	if location == "documents" and not ItemCatalog.is_desk_item(id):
		return false
	if ItemCatalog.is_desk_item(id) and (location == "warehouse" or (location != "documents" and InspectionCatalog.TOOLS.has(id))):
		return false
	for key: String in ["strength", "condition"]:
		var number: Variant = item.get(key)
		if not (number is float or number is int) or not is_finite(float(number)) or number < 0.0:
			return false
	for key: String in ["broken", "leaking", "offered", "examined"]:
		if not item.get(key, false) is bool:
			return false
	if not item.has_all(["broken", "leaking"]):
		return false
	var draft: Variant = item.get("offer_draft", 0)
	if not draft is int or draft < 0 or draft > GameState.MAX_OFFER:
		return false
	var marks: Variant = item.get("marked_rules", [])
	var measurements: Variant = item.get("measurements", {})
	if not marks is Array or not measurements is Dictionary:
		return false
	for rule: Variant in marks:
		if not rule is String or not InspectionCatalog.CHECKLIST_LABELS.has(rule):
			return false
	for tool: Variant in measurements:
		if tool not in ["scale", "thermometer"] or not measurements[tool] is String:
			return false
	return true
