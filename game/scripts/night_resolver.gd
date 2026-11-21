extends RefCounted
class_name NightResolver


static func resolve(grid: ItemGrid, field: int) -> Dictionary:
	var updated := grid.items.duplicate(true)
	var messages: Array[String] = []
	var danger_slots: Array[int] = []
	var damage := 0

	for cell in grid.items.size():
		var item: Dictionary = grid.items[cell]
		if item.is_empty() or item["broken"] or item.get("offered", false):
			continue
		var item_id: String = item["id"]
		for neighbor in grid.neighbors(cell):
			if neighbor <= cell:
				continue
			var other: Dictionary = grid.items[neighbor]
			if other.is_empty() or other["broken"]:
				continue
			var other_id: String = other["id"]
			if not (
				(item_id == "samovar" and other_id == "frost_glass")
				or (item_id == "frost_glass" and other_id == "samovar")
			):
				continue
			if item["strength"] <= 0.0 or other["strength"] <= 0.0:
				continue
			var hot := cell if item_id == "samovar" else neighbor
			var cold := neighbor if hot == cell else cell
			updated[hot]["leaking"] = true
			updated[hot]["condition"] = minf(updated[hot]["condition"], 0.5)
			updated[cold]["broken"] = true
			updated[cold]["condition"] = 0.0
			updated[cold]["strength"] = 0.0
			damage += 20
			if not danger_slots.has(hot):
				danger_slots.append(hot)
			if not danger_slots.has(cold):
				danger_slots.append(cold)
			messages.append("Ячейки %d и %d. Стакан лопается, самовар даёт течь. Урон +20." % [hot + 1, cold + 1])

	var losses: Dictionary[int, float] = {}
	for cell in updated.size():
		var item: Dictionary = updated[cell]
		if item.is_empty() or item["strength"] <= 0.0 or item.get("offered", false):
			continue
		var item_id: String = item["id"]
		var entry := ItemCatalog.definition(item_id)
		if field >= entry["minimum_field"]:
			continue
		var rate := 100.0 / float(entry["lifetime"])
		for neighbor in grid.neighbors(cell):
			var other: Dictionary = updated[neighbor]
			# Use the post-reaction state for every neighbor, including neighbors that will decay.
			if other.is_empty() or other["broken"] or other["strength"] <= 0.0:
				continue
			match other["id"]:
				"samovar":
					rate *= 1.5
				"frost_glass", "clock":
					rate *= 0.5
		var lost := minf(rate, item["strength"])
		losses[cell] = lost
		messages.append("Ячейка %d. %s теряет %.1f п. п. свойства." % [
			cell + 1, ItemCatalog.item_name(item_id), lost
		])

	for cell in losses:
		updated[cell]["strength"] -= losses[cell]

	return {"items": updated, "messages": messages, "damage": damage, "danger_slots": danger_slots}
