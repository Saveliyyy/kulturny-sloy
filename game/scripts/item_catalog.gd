extends RefCounted
class_name ItemCatalog

const ITEMS := {
	"samovar": {
		"name": "Самовар из Ключей", "shape": "samovar", "history": 90,
		"layer": 150, "minimum_field": 30, "lifetime": 40, "completeness": 0.8,
	},
	"frost_glass": {
		"name": "Ледниковый стакан", "shape": "glass", "history": 5,
		"layer": 150, "minimum_field": 40, "lifetime": 30,
	},
	"clock": {
		"name": "Ходики-вспять", "shape": "clock", "history": 60,
		"layer": 400, "minimum_field": 50, "lifetime": 90,
	},
	"soot_glass": {
		"name": "Стакан в копоти", "shape": "glass", "history": 5,
		"layer": 0, "minimum_field": 0, "lifetime": 0,
	},
	"compass": {
		"name": "Компас Н. Г.", "shape": "compass", "history": 20,
		"layer": 600, "minimum_field": 30, "lifetime": 120,
	},
	"workshop_clock": {
		"name": "Ходики из мастерской", "shape": "clock", "art": "clock", "history": 70,
		"layer": 0, "minimum_field": 0, "lifetime": 0,
	},
	"road_glass": {
		"name": "Стакан с матовой стенкой", "shape": "glass", "art": "frost_glass", "history": 30,
		"layer": 0, "minimum_field": 0, "lifetime": 0,
	},
	"cool_samovar": {
		"name": "Остывший самовар из Ключей", "shape": "samovar", "art": "samovar", "history": 120,
		"layer": 0, "minimum_field": 0, "lifetime": 0, "completeness": 0.8,
	},
}

const DESK_ITEMS := {
	"lens": "Лупа", "scale": "Безмен", "thermometer": "Термометр", "stamp_catalog": "Журнал осмотра",
}

const SEVENTH_DAY_FALLBACK := {
	"id": "road_glass", "display": "Стакан с матовой стенкой", "seller": "Мирон", "asking": 48,
	"dialogue": "Подобрал у самой дороги к вешкам. Думал, иней, а стенка всё белая.\nТаня к приёмке больше не ходит. Если нужен проводник, поспрашивай у переправы.",
	"price_line": "За стакан хватит %d рублей.",
}

const DEALS := [
	[
		{
			"id": "samovar", "display": "Самовар", "seller": "Таня Гусева", "asking": 130,
			"dialogue": "Из избы у Ключей.\nКрышка родная, дед так говорил.\nМне бы на сапоги и щуп.",
			"price_line": "За самовар хочу %d рублей.",
		},
		{
			"id": "frost_glass", "display": "Гранёный стакан", "seller": "Мирон", "asking": 70,
			"dialogue": "В августе из кармана достаю, а он в инее.\nПроверь, если не веришь.",
			"price_line": "За стакан возьму %d рублей.",
		},
	],
	[
		{
			"id": "clock", "display": "Настенные ходики", "seller": "Деревянко", "asking": 220,
			"dialogue": "Утром на складе нашли.\nИдут, да только не туда.\nВ цену это входит.",
			"price_line": "За ходики рассчитываю на %d рублей.",
		},
		{
			"id": "soot_glass", "display": "Гранёный стакан", "seller": "Костя", "asking": 65,
			"dialogue": "С самой Гари, ледниковый.\nТакой вчера за семьдесят ушёл.",
			"price_line": "Тебе отдам за %d рублей.",
		},
	],
	[
		{
			"id": "compass", "display": "Походный компас", "seller": "Мирон", "asking": 160,
			"dialogue": "Взял у старых вешек Гусева.\nСевера не держит. Может, тебе на запчасти?",
			"price_line": "За компас хочу %d рублей.",
		},
	],
	[
		{
			"id": "workshop_clock", "display": "Ходики из мастерской", "seller": "Деревянко", "asking": 195,
			"dialogue": "Эти сняли в мастерской. Поменял втулку сам.\nГири по дороге растеряли, а стрелка идёт как положено.\nСверь с теми, что со склада.",
			"price_line": "За работу и ходики хочу %d рублей.",
		},
	],
	[
		{
			"id": "road_glass", "display": "Гранёный стакан", "seller": "Костя", "asking": 60,
			"dialogue": "Старик на переправе сказал, что ледниковый.\nВся стенка матовая. Я до утра ждал, а она так и осталась белой.",
			"price_line": "За этот стакан прошу %d рублей.",
		},
		{
			"id": "frost_glass", "display": "Гранёный стакан", "seller": "Мирон", "asking": 72,
			"dialogue": "Под старым настилом нашёл. Завернул в тряпку.\nТряпка за полчаса задубела. На стол сразу не клади, если рядом горячее.",
			"price_line": "За стакан возьму %d рублей.",
		},
	],
	[
		{
			"id": "cool_samovar", "display": "Самовар с переправы", "seller": "Деревянко", "asking": 105,
			"dialogue": "С пристани принёс. На боку клеймо из Ключей.\nКрышку уже на переправе подогнали. Шов светлее корпуса, сам увидишь.",
			"price_line": "Самовар отдам за %d рублей.",
		},
	],
	[
		{
			"id": "soot_glass", "display": "Стакан из проходной", "seller": "Костя", "asking": 49,
			"dialogue": "У сторожа в проходной стоял. Он уверяет, что вынес его от самых вешек.\nНа свет посмотри. Под копотью царапина или трещина, я так и не разобрал.",
			"price_line": "За стакан прошу %d рублей.",
		},
		{
			"id": "road_glass", "display": "Стакан с матовой стенкой", "seller": "Таня Гусева", "asking": 48,
			"dialogue": "Нашла у дома ещё один стакан с белыми стенками.\nНа сапоги деньги уже собрала. Теперь ищу щуп, без него к вешкам не пойду.",
			"price_line": "За стакан хватит %d рублей.",
		},
	],
]


static func definition(item_id: String) -> Dictionary:
	return ITEMS[item_id]


static func art_id(item_id: String) -> String:
	return ITEMS[item_id].get("art", item_id) if ITEMS.has(item_id) else item_id


static func item_name(item_id: String) -> String:
	return DESK_ITEMS[item_id] if is_desk_item(item_id) else ITEMS[item_id]["name"]


static func is_desk_item(item_id: String) -> bool:
	return DESK_ITEMS.has(item_id)


static func footprint(item_id: String) -> Vector2i:
	match art_id(item_id):
		"samovar":
			return Vector2i(2, 2)
		"clock", "scale", "thermometer":
			return Vector2i(1, 2)
		"stamp_catalog":
			return Vector2i(2, 1)
	return Vector2i.ONE


static func make_item(item_id: String) -> Dictionary:
	return {
		"id": item_id,
		"strength": 100.0 if not is_desk_item(item_id) and definition(item_id)["layer"] > 0 else 0.0,
		"condition": 1.0,
		"leaking": false,
		"broken": false,
	}
