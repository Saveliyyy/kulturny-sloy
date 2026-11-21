extends RefCounted
class_name GameState

const BASE_FIELD := 25
const ENHANCED_FIELD := 50
const FIELD_COST := 15
const MAX_OFFERS := 2
const MAX_OFFER := 9999
const OPENING_CASH := 300
const LAST_DAY := 7
const FIRST_DATE := 25
const MORNING := 8 * 60
const EVENING := 18 * 60
const COUNTER_SIZE := Vector2i(26, 6)
const WAREHOUSE_SIZE := Vector2i(10, 7)
const DOCUMENTS_SIZE := Vector2i(6, 3)
const PLAYER_ROW := 3
const OFFER_COLUMN := 6

var day := 1
var money := OPENING_CASH
var customer := 0
var offers_left := MAX_OFFERS
var damage := 0
var tanya_told := false
var tanya_discussed_marks := false
var tanya_samovar_bought := false
var compass_returned := false
var field_enhanced := false
var ended := false
var counter := ItemGrid.new(COUNTER_SIZE.x, COUNTER_SIZE.y)
var warehouse := ItemGrid.new(WAREHOUSE_SIZE.x, WAREHOUSE_SIZE.y)
var documents := ItemGrid.new(DOCUMENTS_SIZE.x, DOCUMENTS_SIZE.y)
var offered_slot := -1
var last_purchase_slot := -1
var night_report: Array[String] = []


func _init() -> void:
	var positions := {"lens": 0, "scale": 2, "thermometer": 4, "stamp_catalog": 12}
	for id: String in positions:
		documents.items[positions[id]] = ItemCatalog.make_item(id)
	place_offer()


func active_deal() -> Dictionary:
	var visits: Array = ItemCatalog.DEALS[day - 1]
	if ended or customer >= visits.size():
		return {}
	if day == LAST_DAY and customer == visits.size() - 1 and tanya_samovar_bought and not tanya_told:
		return ItemCatalog.SEVENTH_DAY_FALLBACK
	return visits[customer]


func calendar_date() -> String:
	return "%d июля 1983" % (FIRST_DATE + day - 1)


func counter_time() -> float:
	var visits: Array = ItemCatalog.DEALS[day - 1]
	return lerpf(MORNING, EVENING, float(customer) / visits.size())


func report_tanya() -> String:
	if active_deal().get("id", "") != "samovar" or tanya_told:
		return ""
	tanya_told = true
	return "Спасибо, что сказали.\nЗа родной корпус попрошу на двадцать рублей больше."


func asking_price() -> int:
	return int(active_deal().get("asking", 0))


func tool_kind(data: Dictionary) -> String:
	var area: String = data.get("location", "")
	if area != "documents":
		return ""
	var id: String = grid(area).item_at(data.get("anchor", -1)).get("id", "")
	return id if InspectionCatalog.TOOLS.has(id) else ""


func offer_price(price: int, from_inspection := false) -> String:
	last_purchase_slot = -1
	var deal := active_deal()
	if deal.is_empty() or price <= 0 or price > cash_available():
		return "Проверьте сумму предложения и остаток кассы."
	if offered_slot < 0:
		return "Освободите место для находки на прилавке."
	if not offer_on_player_side() and not (from_inspection and counter.item_at(offered_slot).get("examined", false)):
		return "Сначала осмотрите находку."
	var item_id: String = deal["id"]
	var minimum := InspectionCatalog.minimum_offer(item_id)
	if item_id == "samovar" and tanya_told:
		minimum += 20
	if price < minimum:
		offers_left -= 1
		if offers_left == 0:
			_next_customer()
			return "%s забирает вещь и уходит." % deal["seller"]
		return "%s отказывается. Осталась одна попытка." % deal["seller"]

	var purchase := counter.items[offered_slot].duplicate()
	purchase.erase("offered")
	purchase.erase("offer_draft")
	last_purchase_slot = warehouse.put_first(purchase)
	if last_purchase_slot < 0:
		return "В кладовой нет свободных клеток такого размера."
	money -= price
	if item_id == "samovar":
		tanya_samovar_bought = true
	_next_customer()
	return "Покупка за %d ₽. В кладовой: %s." % [price, ItemCatalog.item_name(item_id)]


func pass_deal() -> String:
	var deal := active_deal()
	if deal.is_empty():
		return ""
	_next_customer()
	return "%s уходит со своей вещью." % deal["seller"]


func grid(location: String) -> ItemGrid:
	match location:
		"warehouse":
			return warehouse
		"documents":
			return documents
	return counter


func offer_on_player_side() -> bool:
	return offered_slot >= 0 and counter.position_of(offered_slot).y >= PLAYER_ROW


func can_move(from_area: String, from: int, to_area: String, to: int) -> bool:
	var item := grid(from_area).item_at(from)
	if ended or item.is_empty() or (item.get("offered", false) and from_area != to_area):
		return false
	if InspectionCatalog.TOOLS.has(item["id"]) and to_area != "documents":
		return false
	var desk_item := ItemCatalog.is_desk_item(item["id"])
	if desk_item:
		if to_area == "warehouse":
			return false
		if to_area == "counter" and counter.position_of(to).y < PLAYER_ROW:
			return false
	elif to_area == "documents":
		return false
	if item.get("offered", false):
		var area := counter.area(to, item)
		if area.position.y < PLAYER_ROW and area.end.y > PLAYER_ROW:
			return false
	return grid(to_area).fits(item, to, from if from_area == to_area else -1)


func move_item(from_area: String, from: int, to_area: String, to: int) -> bool:
	if not can_move(from_area, from, to_area, to):
		return false
	var source := grid(from_area)
	var item := source.items[from]
	source.items[from] = {}
	grid(to_area).items[to] = item
	if item.get("offered", false):
		offered_slot = to
	place_offer()
	return true


func transfer_first(area: String, slot: int) -> bool:
	if ItemCatalog.is_desk_item(grid(area).item_at(slot).get("id", "")):
		return false
	var target := "counter" if area == "warehouse" else "warehouse"
	for cell in grid(target).items.size():
		if move_item(area, slot, target, cell):
			return true
	return false


func quote(slot: int, channel: String, location := "counter") -> int:
	var item := grid(location).item_at(slot)
	if item.is_empty() or item.get("offered", false) or ItemCatalog.is_desk_item(item["id"]):
		return 0
	var entry := ItemCatalog.definition(item["id"])
	var history := float(entry["history"]) * float(entry.get("completeness", 1.0))
	history = maxf(1.0, history + InspectionCatalog.adjustment(item["id"])) * float(item["condition"])
	var layer := float(entry["layer"]) * float(item["strength"]) / 100.0
	layer *= float(item["condition"])
	match channel:
		"counter":
			return roundi(history)
		"lab":
			if layer > 0.0:
				return roundi(history * 0.6 + layer * 1.2)
	return 0


func sell(slot: int, channel: String, location := "counter") -> String:
	var price := quote(slot, channel, location)
	if ended or price <= 0:
		return "По этому каналу вещь сейчас не принимают."
	var items := grid(location).items
	var item_name := ItemCatalog.item_name(items[slot]["id"])
	items[slot] = {}
	place_offer()
	money += price
	if channel == "lab":
		return "%s передан в НИЛ-9 за %d ₽." % [item_name, price]
	return "%s сдан как обычная вещь за %d ₽." % [item_name, price]


func return_compass(slot: int, location := "counter") -> String:
	var item := grid(location).item_at(slot)
	if ended or item.get("id") != "compass" or item.get("offered", false):
		return ""
	grid(location).items[slot] = {}
	place_offer()
	compass_returned = true
	if tanya_told:
		return "Таня узнаёт компас отца и раскрывает его карту. Она предлагает вместе сходить к старым вешкам."
	return "Таня берёт компас обеими руками. Всё это время он лежал у вешек."


func clear_broken_item(slot: int, location := "counter") -> void:
	if not ended and grid(location).item_at(slot).get("broken", false):
		grid(location).items[slot] = {}
		place_offer()


func warehouse_field() -> int:
	return ENHANCED_FIELD if field_enhanced else BASE_FIELD


func forecast(location: String) -> Dictionary:
	var field := warehouse_field() if location == "warehouse" else BASE_FIELD
	return NightResolver.resolve(grid(location), field)


func next_night() -> bool:
	if ended or not active_deal().is_empty():
		return false
	night_report.clear()
	for location in ["counter", "warehouse"]:
		var outcome := forecast(location)
		grid(location).items = outcome["items"]
		damage += outcome["damage"]
		var name := "Кладовая" if location == "warehouse" else "Прилавок"
		for message: String in outcome["messages"]:
			night_report.append("%s · %s" % [name, message])
	if field_enhanced:
		money -= FIELD_COST
		night_report.push_front("Фон поддержан за %d ₽." % FIELD_COST)
	if night_report.is_empty():
		night_report.append("За ночь с находками ничего не случилось.")
	field_enhanced = false
	if day == LAST_DAY:
		ended = true
		return true
	day += 1
	customer = 0
	offers_left = MAX_OFFERS
	place_offer()
	return true


func set_enhanced_field(enabled: bool) -> bool:
	if ended or (enabled and money < FIELD_COST):
		return false
	field_enhanced = enabled
	return true


func cash_available() -> int:
	return money - (FIELD_COST if field_enhanced else 0)


func ending_text() -> String:
	if compass_returned and tanya_told:
		return "Таня ждёт у пункта с картой отца. Компас уже в её кармане. На рассвете вы договорились выйти к старым вешкам вместе."
	if compass_returned:
		return "Таня ушла с компасом. Перед закрытием она оставила на прилавке записку с координатами. Стрелка всё это время указывала на Мачту."
	if tanya_samovar_bought and not tanya_told:
		return "Таня узнала у мастера, что крышка поздняя. Она больше не заходит. За окном Мачта зажигает красный огонь. Утром придётся искать проводника самому."
	return "В амбарной книге семь дней записей. Вы помните компас с раскопа и красный огонь Мачты. Утром остаётся проверить, куда указывает стрелка."


func place_offer() -> void:
	var deal := active_deal()
	if offered_slot >= 0 or deal.is_empty():
		return
	var item := ItemCatalog.make_item(deal["id"])
	item["offered"] = true
	for offset in counter.columns * PLAYER_ROW:
		var square := counter.position_of(offset)
		square.x = (square.x + OFFER_COLUMN) % counter.columns
		var slot := counter.slot_at(square)
		if counter.area(slot, item).end.y <= PLAYER_ROW and counter.fits(item, slot):
			counter.items[slot] = item
			offered_slot = slot
			return


func _next_customer() -> void:
	if offered_slot >= 0:
		counter.items[offered_slot] = {}
		offered_slot = -1
	customer += 1
	offers_left = MAX_OFFERS
	place_offer()
