extends RefCounted
class_name InspectionCatalog

const TOOLS := {"lens": "Лупа", "scale": "Безмен", "thermometer": "Термометр"}
const RULES := {
	"kluchi": ["Клеймо 61 на корпусе относится к мастерской в Ключах", 18],
	"late_lid": ["Крышка с клеймом ПМ и светлым припоем появилась позже корпуса. Крышку и шов считайте вместе", -24],
	"heat": ["Пустой самовар горячее 80 °C", 18],
	"seam": ["Заводской шов на донышке цел", 8],
	"soot": ["На стенке чёрный налёт", -8],
	"crack": ["Тонкая светлая трещина на стенке", -9],
	"cold": ["Температура стакана −10 °C и ниже", 15],
	"warm_glass": ["Стакан заявлен как ледниковый, температура выше 10 °C", -12],
	"reverse": ["Секундная стрелка идёт против часовой", 30],
	"complete_clock": ["Ходики весят 1,2 кг вместе с гирями", 8],
	"bearing": ["Стрелка компаса указывает в одну и ту же сторону комнаты при повороте корпуса", 28],
	"light_compass": ["Компас весит меньше 140 г", -10],
}

const SECTIONS := {
	"samovar": {
		"title": "Самовары", "base": 90,
		"lens": ["kluchi", "late_lid"], "thermometer": ["heat"],
		"scale_note": "Норма для такого корпуса 5,7–6,3 кг.",
	},
	"glass": {
		"title": "Гранёные стаканы", "base": 45,
		"lens": ["seam", "soot", "crack"], "thermometer": ["cold", "warm_glass"],
		"scale_note": "Обычный гранёный стакан весит около 250 г.",
	},
	"clock": {
		"title": "Настенные ходики", "base": 180,
		"lens": ["reverse"], "scale": ["complete_clock"],
		"thermometer_note": "Комнатная температура считается нормой.",
	},
	"compass": {
		"title": "Походные компасы", "base": 120,
		"lens": ["bearing"], "scale": ["light_compass"],
		"scale_note": "Для этой модели типичны 140–160 г.",
		"thermometer_note": "Комнатная температура считается нормой.",
	},
}

const ARTIFACTS := {
	"samovar": {"scale": 6000, "thermometer": 85, "rules": ["kluchi", "late_lid", "heat"]},
	"frost_glass": {"scale": 250, "thermometer": -12, "rules": ["seam", "cold"]},
	"clock": {"scale": 1200, "thermometer": 15, "rules": ["reverse", "complete_clock"]},
	"soot_glass": {"scale": 250, "thermometer": 19, "rules": ["soot", "crack", "warm_glass"]},
	"compass": {"scale": 130, "thermometer": 15, "rules": ["bearing", "light_compass"]},
	"workshop_clock": {"scale": 950, "thermometer": 17, "rules": []},
	"road_glass": {"scale": 250, "thermometer": 18, "rules": ["seam", "warm_glass"]},
	"cool_samovar": {"scale": 5900, "thermometer": 21, "rules": ["kluchi", "late_lid"]},
}

const CHECKLIST_LABELS := {
	"kluchi": "Клеймо 61 на корпусе",
	"late_lid": "Поздняя крышка со следами припоя",
	"heat": "Пустой самовар горячее 80 °C",
	"seam": "Целый заводской шов",
	"soot": "Чёрный налёт на стенке",
	"crack": "Трещина в стекле",
	"cold": "Температура стакана −10 °C и ниже",
	"warm_glass": "Ледниковый стакан теплее 10 °C",
	"reverse": "Секундная стрелка идёт назад",
	"complete_clock": "Вес 1,2 кг, гири на месте",
	"bearing": "Стрелка держит направление при повороте",
	"light_compass": "Компас легче 140 г",
}


static func reading_value(item_id: String, tool: String) -> int:
	return ARTIFACTS[item_id][tool]


static func reading(item_id: String, tool: String) -> String:
	var value := reading_value(item_id, tool)
	if tool == "scale":
		return ("%.1f кг" % (value / 1000.0)).replace(".", ",") if value >= 1000 else "%d г" % value
	return "%s °C" % str(value).replace("-", "−")


static func adjustment(item_id: String) -> int:
	var total := 0
	for id: String in ARTIFACTS[item_id]["rules"]:
		total += int(RULES[id][1])
	return total


static func minimum_offer(item_id: String) -> int:
	return estimate(item_id, ARTIFACTS[item_id]["rules"])


static func checklist(item_id: String) -> Array[String]:
	var section: Dictionary = SECTIONS[ItemCatalog.definition(item_id)["shape"]]
	var ids: Array[String] = []
	for tool: String in TOOLS:
		ids.append_array(section.get(tool, []))
	return ids


static func estimate(item_id: String, marked: Array) -> int:
	var section: Dictionary = SECTIONS[ItemCatalog.definition(item_id)["shape"]]
	var sum := int(section["base"])
	for id: String in checklist(item_id):
		if id in marked:
			sum += int(RULES[id][1])
	return maxi(1, sum)


static func adjustment_caption(id: String) -> String:
	var difference: int = RULES[id][1]
	return "%s%d ₽" % ["−" if difference < 0 else "+", absi(difference)]
