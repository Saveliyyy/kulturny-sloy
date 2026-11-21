extends Control

const INK := Color("f0e0bd")
const MUTED := Color("c5ba9d")
const AMBER := Color("e9ba78")
const TEAL := Color("9ad1bb")
const PAPER_INK := Color("382719")
const COUNTER_DIALOGUE := Rect2(0.294, 0.386, 0.347, 0.127)
const MARKS_DIALOGUE := Rect2(0.294, 0.310, 0.347, 0.127)
const INSPECTION_PAPER := Rect2(0.553, 0.475, 0.328, 0.5)
var state := GameState.new()
var save_game: GameSave = GameSave.new()
var opening: OpeningScreen
var screen := "counter"
var shown_deal_id := ""
var selected_area := "counter"
var selected_slot := -1
var inspected_item: Dictionary = {}
var reply := ""
var price_announced := false
var choosing_marks := false
var first_on_mat := false

var cash_label: Label
var status_label: Label
var save_notice: Label
var hud_row: HBoxContainer
var counter_tab: Button
var shelf_tab: Button
var night_button: Button
var counter_screen: Control
var desk_board: InventoryBoard
var stock_board: InventoryBoard
var transfer_board: InventoryBoard
var desk_controls: HBoxContainer
var desk_store: Button
var folder_hotspot: DocumentHotspot
var documents_panel: PanelContainer
var documents_layout: BoxContainer
var documents_intro: Label
var documents_board: InventoryBoard
var toolbox_open := false
var journal_panel: PanelContainer
var journal_sections: OptionButton
var journal_scroll: ScrollContainer
var journal_entries: VBoxContainer
var journal_button: Button
var form_button: Button
var dialogue_panel: DealPaper
var dialogue_placement := Vector2.INF
var dialogue_grab := Vector2.INF
var seller_label: Label
var seller_line: DialogueLine
var dialogue_actions: HBoxContainer
var mark_choices: VBoxContainer
var tell_button: Button
var form_rules: VBoxContainer
var rule_boxes: Dictionary[String, CheckBox] = {}
var offer_form: OfferSlip
var form_handoff: DealPaper
var handoff_recipient: Label
var form_item_label: Label
var send_form: Button
var offer_price_label: Label
var price_steps: Dictionary[int, Button] = {}
var item_view: ItemView
var inspection_panel: PanelContainer
var inspection_title: Label
var inspection_hint: Label
var evidence_label: Label
var shelf_screen: VBoxContainer
var shelf_detail: Label
var forecast_label: Label
var field_check: CheckButton
var report_label: Label
var counter_sale: Button
var lab_sale: Button
var transfer_button: Button
var inspect_stock: Button
var return_button: Button
var discard_button: Button
var end_panel: PanelContainer
var end_text: Label
var end_stats: Label
var end_report: Label
var transition: SceneTransition


func _ready() -> void:
	theme = _make_theme()
	DeskCursor.install()
	var restored: GameState
	if save_game != null:
		restored = save_game.load_progress()
		if restored != null:
			state = restored
	opening = OpeningScreen.new()
	_place(opening, Rect2(0, 0, 1, 1))
	opening.play_requested.connect(_enter_game, CONNECT_ONE_SHOT)
	opening.present(restored, save_game != null and save_game.unreadable)


func _enter_game(new_game: bool) -> void:
	if new_game:
		state = GameState.new()
	_build_scene()
	_build_warehouse()
	_build_inspection()
	_build_offer_form()
	_build_dialogue()
	_build_ending()
	_build_hud()
	_build_documents()
	_build_journal()
	transition = SceneTransition.new()
	_place(transition, Rect2(0, 0, 1, 1))
	_refresh()


func _process(delta: float) -> void:
	if item_view == null:
		return
	item_view.speaking = seller_line.is_speaking()
	dialogue_panel.modulate.a = 1.0 if seller_line.visible_characters != 0 or seller_line.phrase_index > 0 else 0.0
	if not transition.running:
		var evening := 0.32 if shown_deal_id.is_empty() and not state.ended else 0.0
		item_view.night_level = move_toward(item_view.night_level, evening, delta * 0.34)


func _build_scene() -> void:
	var background := ColorRect.new()
	background.color = Color("1b211e")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(background, Rect2(0, 0, 1, 1))
	counter_screen = Control.new()
	counter_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(counter_screen, Rect2(0, 0, 1, 1))
	item_view = ItemView.new()
	item_view.tool_dropped.connect(_drop_on_enlarged_item)
	item_view.measurement_ready.connect(_record_measurement)
	item_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	counter_screen.add_child(item_view)

	desk_board = _board("counter")
	desk_board.on_counter = true
	desk_board.on_mat = true
	desk_board.sprite_fill = 1.43
	_place(desk_board, CounterMat.REGION)
	desk_controls = _row(self)
	_set_region(desk_controls, Rect2(0.057, 0.586, 0.200, 0.048))
	desk_controls.add_spacer(false)
	desk_store = _button(desk_controls, "В кладовую", _transfer_selected)
	folder_hotspot = DocumentHotspot.new()
	folder_hotspot.flat = true
	folder_hotspot.tooltip_text = "Ящик с инструментами"
	folder_hotspot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	folder_hotspot.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	folder_hotspot.pressed.connect(_toggle_folder)
	folder_hotspot.openness_changed.connect(_reveal_tools)
	_place(folder_hotspot, DocumentHotspot.REGION)


func _build_hud() -> void:
	var row := _row(self, 10)
	hud_row = row
	_set_region(row, Rect2(0.02, 0.022, 0.96, 0.067))
	counter_tab = _button(row, "К прилавку", _navigate.bind("counter"))
	shelf_tab = _icon_button(row, "Кладовая", "shelf", _navigate.bind("warehouse"), 30)
	row.add_spacer(false)
	var card := _panel(row)
	card.get_parent().size_flags_horizontal = Control.SIZE_SHRINK_END
	cash_label = _label("", 19, AMBER)
	card.add_child(cash_label)
	night_button = _button(row, "Завершить день", _finish_day)
	status_label = _label("", 15, TEAL, true)
	_place(status_label, Rect2(0.023, 0.096, 0.198, 0.095))
	save_notice = _label("Сохранение недоступно", 15, AMBER)
	save_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(save_notice, Rect2(0.675, 0.096, 0.302, 0.05))
	save_notice.hide()


func _build_dialogue() -> void:
	dialogue_panel = DealPaper.new()
	_place(dialogue_panel, COUNTER_DIALOGUE)
	dialogue_panel.modulate.a = 0.0
	var note := VBoxContainer.new()
	note.mouse_filter = Control.MOUSE_FILTER_PASS
	note.add_theme_constant_override("separation", 5)
	dialogue_panel.add_child(note)
	var style := _box(Color("ddc58f"), Color("876035"), 8)
	style.shadow_color = Color("20160ea8")
	style.shadow_size = 5
	style.shadow_offset = Vector2(4, 5)
	dialogue_panel.add_theme_stylebox_override("panel", style)
	var handle := _row(note)
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	handle.gui_input.connect(_drag_dialogue.bind(handle))
	handle.resized.connect(handle.queue_redraw)
	handle.draw.connect(func():
		var grip := Vector2(handle.size.x - 21, handle.size.y * 0.5 - 3).round()
		for dot in 6:
			var point := grip + Vector2(dot % 3 * 5, floori(dot / 3.0) * 5)
			handle.draw_rect(Rect2(point, Vector2(2, 2)), Color("937448"))
	)
	var tag := _panel(handle)
	tag.get_parent().size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tag.get_parent().mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.get_parent().add_theme_stylebox_override("panel", _box(Color("75462f"), Color("a47145"), 4))
	seller_label = _label("", 17, Color("ffebbe"))
	tag.add_child(seller_label)
	seller_line = DialogueLine.new()
	seller_line.add_theme_color_override("font_color", PAPER_INK)
	seller_line.add_theme_font_size_override("font_size", 19)
	seller_line.add_theme_constant_override("line_spacing", 5)
	seller_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	seller_line.custom_minimum_size.y = 43
	seller_line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	note.add_child(seller_line)
	seller_line.mouse_filter = Control.MOUSE_FILTER_PASS
	dialogue_actions = _row(note)
	tell_button = _button(dialogue_actions, "Обсудить клейма", _show_mark_choices.bind(true))
	dialogue_actions.add_spacer(false)
	_button(dialogue_actions, "Отпустить", _pass)
	mark_choices = VBoxContainer.new()
	note.add_child(mark_choices)
	_button(mark_choices, "Корпус и крышка одного времени", _discuss_marks.bind(0))
	_button(mark_choices, "Крышка более поздняя", _discuss_marks.bind(1))
	_button(mark_choices, "Назад", _show_mark_choices.bind(false))
	mark_choices.hide()
	resized.connect(_restore_dialogue_placement)
	dialogue_panel.resized.connect(_restore_dialogue_placement)
	dialogue_panel.visibility_changed.connect(func(): dialogue_grab = Vector2.INF)


func _drag_dialogue(event: InputEvent, handle: Control) -> void:
	if not event is InputEventMouse or is_zero_approx(dialogue_panel.modulate.a):
		return
	var point: Vector2 = handle.get_global_transform() * event.position
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dialogue_grab = point - dialogue_panel.position if event.pressed else Vector2.INF
		handle.accept_event()
	elif event is InputEventMouseMotion and dialogue_grab.is_finite():
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			dialogue_grab = Vector2.INF
			return
		var travel := (size - dialogue_panel.size).max(Vector2.ZERO)
		var destination := (point - dialogue_grab).clamp(Vector2.ZERO, travel)
		dialogue_placement = destination / size.max(Vector2.ONE)
		dialogue_panel.position = destination.round()
		handle.accept_event()


func _restore_dialogue_placement() -> void:
	if dialogue_placement.is_finite():
		var travel := (size - dialogue_panel.size).max(Vector2.ZERO)
		dialogue_panel.position = (size * dialogue_placement).clamp(Vector2.ZERO, travel).round()


func _build_inspection() -> void:
	var detail := _panel(self)
	inspection_panel = detail.get_parent() as PanelContainer
	_set_region(inspection_panel, Rect2(INSPECTION_PAPER.position.x, 0.23, INSPECTION_PAPER.size.x, 0.229))
	inspection_title = _label("Осмотр находки", 21, INK)
	inspection_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.add_child(inspection_title)
	var actions := _row(detail)
	journal_button = _button(actions, "Журнал", _toggle_journal)
	journal_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	journal_button.toggle_mode = true
	form_button = _button(actions, "Бланк", _toggle_offer_form)
	form_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_button.toggle_mode = true
	inspection_hint = _label("", 15, MUTED, true)
	detail.add_child(inspection_hint)
	evidence_label = _label("", 16, INK, true)
	detail.add_child(evidence_label)


func _build_offer_form() -> void:
	offer_form = OfferSlip.new()
	_place(offer_form, INSPECTION_PAPER)
	offer_form.add_theme_stylebox_override("panel", _box(Color("e0c998"), Color("927443"), 12))
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 4)
	offer_form.add_child(page)
	var heading := _row(page)
	heading.mouse_filter = Control.MOUSE_FILTER_STOP
	heading.mouse_default_cursor_shape = Control.CURSOR_MOVE
	heading.tooltip_text = "Перетащите за этот край на табличку посетителя."
	heading.set_drag_forwarding(offer_form._get_drag_data, Callable(), Callable())
	var title := VBoxContainer.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_constant_override("separation", 0)
	heading.add_child(title)
	title.add_child(_label("Бланк оценки", 21, PAPER_INK))
	form_item_label = _label("", 15, Color("705135"))
	title.add_child(form_item_label)
	heading.add_spacer(false)
	_button(heading, "Закрыть", _toggle_offer_form).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	page.add_child(HSeparator.new())
	form_rules = VBoxContainer.new()
	form_rules.add_theme_constant_override("separation", 1)
	page.add_child(form_rules)
	page.add_child(HSeparator.new())
	var price := _row(page)
	var price_caption := _label("Моя цена", 15, PAPER_INK)
	price_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	price.add_child(price_caption)
	offer_price_label = _label("0 ₽", 22, PAPER_INK)
	offer_price_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offer_price_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	price.add_child(offer_price_label)
	var calculate := _button(price, "Рассчитать", _calculate_offer)
	calculate.tooltip_text = "Базовая цена с поправками за отмеченные признаки."
	var steps := _row(page, 4)
	for change: int in [-100, -10, -5, -1, 1, 5, 10, 100]:
		var caption := ("−" if change < 0 else "+") + str(absi(change))
		var button := _button(steps, caption, _adjust_offer_amount.bind(change))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		price_steps[change] = button
	send_form = _button(page, "Передать бланк", _offer)
	send_form.set_drag_forwarding(offer_form._get_drag_data, Callable(), Callable())
	send_form.tooltip_text = "Нажмите или перетащите бланк на табличку посетителя под ковриком."
	offer_form.hide()
	form_handoff = DealPaper.new()
	_place(form_handoff, Rect2(0.065, 0.757, 0.422, 0.087))
	form_handoff.add_theme_stylebox_override("panel", _box(Color("403e30"), Color("a28355"), 7))
	form_handoff.proposal_received.connect(_submit_offer)
	var recipient := VBoxContainer.new()
	recipient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	form_handoff.add_child(recipient)
	handoff_recipient = _label("", 16, INK)
	recipient.add_child(handoff_recipient)
	recipient.add_child(_label("Положите сюда бланк", 14, MUTED))
	form_handoff.hide()


func _build_documents() -> void:
	documents_panel = PanelContainer.new()
	add_child(documents_panel)
	var tray := _box(Color("4a4535"), Color("ab905c"), 8)
	tray.set_border_width_all(4)
	tray.shadow_color = Color("151711b0")
	tray.shadow_size = 4
	tray.shadow_offset = Vector2(3, 4)
	documents_panel.add_theme_stylebox_override("panel", tray)
	documents_layout = BoxContainer.new()
	documents_layout.add_theme_constant_override("separation", 8)
	documents_panel.add_child(documents_layout)
	var header := VBoxContainer.new()
	header.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	documents_layout.add_child(header)
	var heading := _row(header)
	heading.add_child(_label("Ящик с инструментами", 17, INK))
	heading.add_spacer(false)
	_button(heading, "Закрыть", _toggle_folder)
	documents_intro = _label("Перетащите инструмент на находку. Откройте журнал щелчком по книге.", 14, MUTED, true)
	header.add_child(documents_intro)
	documents_board = _board("documents")
	documents_board.sprite_fill = 1.06
	documents_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	documents_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	documents_layout.add_child(documents_board)
	_layout_documents()
	documents_panel.modulate.a = 0.0
	documents_panel.hide()


func _build_journal() -> void:
	var page := _panel(self)
	journal_panel = page.get_parent() as PanelContainer
	var binding := _box(Color("c8a477"), Color("674634"), 12)
	binding.border_width_left = 8
	journal_panel.add_theme_stylebox_override("panel", binding)
	var heading := _row(page)
	heading.add_child(_label("Журнал осмотра", 20, PAPER_INK))
	heading.add_spacer(false)
	_button(heading, "Закрыть", _toggle_journal)
	journal_sections = OptionButton.new()
	journal_sections.custom_minimum_size.y = 30
	for key: String in InspectionCatalog.SECTIONS:
		journal_sections.add_item(InspectionCatalog.SECTIONS[key]["title"])
	journal_sections.select(0)
	journal_sections.item_selected.connect(_read_journal_section)
	page.add_child(journal_sections)
	journal_scroll = ScrollContainer.new()
	journal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	journal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(journal_scroll)
	journal_entries = VBoxContainer.new()
	journal_entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	journal_entries.add_theme_constant_override("separation", 6)
	journal_scroll.add_child(journal_entries)
	journal_panel.hide()


func _read_journal_section(index: int) -> void:
	var section: Dictionary = InspectionCatalog.SECTIONS.values()[index]
	for child: Node in journal_entries.get_children():
		journal_entries.remove_child(child)
		child.queue_free()
	journal_entries.add_child(_label("Базовая цена · %d ₽" % section["base"], 15, PAPER_INK))
	for tool: String in InspectionCatalog.TOOLS:
		journal_entries.add_child(HSeparator.new())
		journal_entries.add_child(_label(InspectionCatalog.TOOLS[tool], 16, Color("5c361f")))
		for id: String in section.get(tool, []):
			var entry := _row(journal_entries)
			var picture := JournalIllustration.new()
			picture.rule = id
			entry.add_child(picture)
			var description := _label("%s\n%s" % [InspectionCatalog.RULES[id][0], InspectionCatalog.adjustment_caption(id)], 14, PAPER_INK, true)
			description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			description.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			entry.add_child(description)
		if section.has(tool + "_note"):
			journal_entries.add_child(_label(section[tool + "_note"], 14, PAPER_INK, true))
	journal_scroll.set_deferred("scroll_vertical", 0)


func _build_warehouse() -> void:
	shelf_screen = VBoxContainer.new()
	shelf_screen.add_theme_constant_override("separation", 10)
	_place(shelf_screen, Rect2(0.02, 0.111, 0.96, 0.830))
	var layout := _row(shelf_screen, 12)
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var stock := _panel(layout, 500, 1.5)
	stock.add_child(_label("Кладовая", 23, INK))
	stock.add_child(_label("Перетаскивайте вещи между кладовой и прилавком.", 15, MUTED))
	stock_board = _board("warehouse")
	stock_board.sprite_fill = 1.06
	stock_board.cell_scale = 1.0
	stock_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stock.add_child(stock_board)

	var side := _panel(layout, 380)
	shelf_detail = _label("", 15, INK, true)
	side.add_child(shelf_detail)
	var operations := _row(side, 6)
	transfer_button = _button(operations, "Перенести", _transfer_selected)
	inspect_stock = _button(operations, "Осмотреть", _inspect_selected)
	discard_button = _button(operations, "Убрать осколки", _discard_broken)
	var selling := _row(side, 6)
	counter_sale = _button(selling, "Сдать", _sell.bind("counter"))
	lab_sale = _button(selling, "НИЛ-9", _sell.bind("lab"))
	return_button = _button(selling, "Вернуть Тане", _return_compass)
	field_check = CheckButton.new()
	field_check.text = "Фон 50% · 15 ₽ за ночь"
	field_check.tooltip_text = "Усиленный фон действует только в кладовой."
	field_check.toggled.connect(_toggle_field)
	side.add_child(field_check)
	side.add_child(_label("Прогноз на 02:00", 17, AMBER))
	forecast_label = _scroll_text(side, 64, INK)
	side.add_child(_label("Прошедшая ночь", 15, MUTED))
	report_label = _scroll_text(side, 38, MUTED)
	var table := _panel(shelf_screen)
	table.add_child(_label("Прилавок", 19, INK))
	transfer_board = _board("counter")
	transfer_board.on_counter = true
	transfer_board.fill_available = true
	transfer_board.sprite_fill = 1.12
	transfer_board.custom_minimum_size.y = 140
	table.add_child(transfer_board)


func _build_ending() -> void:
	var body := _panel(self)
	end_panel = body.get_parent() as PanelContainer
	_set_region(end_panel, Rect2(0.20, 0.16, 0.60, 0.68))
	end_panel.add_theme_stylebox_override("panel", _box(Color("292f28"), Color("786348"), 18))
	body.add_theme_constant_override("separation", 12)
	body.add_child(_label("Перед рассветом", 30, INK))
	end_text = _label("", 20, INK, true)
	body.add_child(end_text)
	end_stats = _label("", 18, AMBER)
	body.add_child(end_stats)
	body.add_child(HSeparator.new())
	body.add_child(_label("Последняя ночь", 16, INK))
	end_report = _scroll_text(body, 64, MUTED)
	_button(body, "Начать заново", _restart).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


func _refresh() -> void:
	_save_progress()
	var deal := state.active_deal()
	var deal_id: String = deal.get("id", "")
	if shown_deal_id != deal_id:
		shown_deal_id = deal_id
		reply = ""
		price_announced = false
		choosing_marks = false
		first_on_mat = false
		item_view.set_visitor(deal.get("seller", ""))
	var in_room := not state.ended and screen != "warehouse"
	var at_desk := in_room and screen == "counter"
	counter_screen.visible = in_room
	dialogue_panel.visible = at_desk and not deal.is_empty()
	desk_board.visible = at_desk
	desk_controls.visible = at_desk
	folder_hotspot.visible = in_room
	inspection_panel.visible = in_room and not at_desk
	shelf_screen.visible = not state.ended and not in_room
	end_panel.visible = state.ended
	hud_row.visible = not state.ended
	status_label.visible = not state.ended
	counter_tab.visible = not state.ended and not at_desk
	shelf_tab.visible = not state.ended
	shelf_tab.disabled = screen == "warehouse"
	night_button.visible = not state.ended
	night_button.disabled = not deal.is_empty()
	cash_label.text = "%d ₽" % state.cash_available()
	if state.field_enhanced:
		cash_label.text += " · %d ₽ на фон" % GameState.FIELD_COST
	item_view.set_examining(screen == "inspect")
	item_view.weather_day = state.day
	item_view.calendar_day = GameState.FIRST_DATE + state.day - 1
	item_view.clock_minutes = state.counter_time()

	if state.ended:
		end_text.text = state.ending_text()
		end_stats.text = "Касса %d ₽ · Урон %d" % [state.money, state.damage]
		end_report.text = "\n".join(state.night_report)
		return
	var counter_outcome := state.forecast("counter")
	var warehouse_outcome := state.forecast("warehouse")
	var counter_selection := selected_slot if selected_area == "counter" else -1
	desk_board.display(state, counter_selection, counter_outcome["danger_slots"])
	transfer_board.display(state, counter_selection, counter_outcome["danger_slots"])
	stock_board.display(state, selected_slot if selected_area == "warehouse" else -1, warehouse_outcome["danger_slots"])
	documents_board.display(state, -1, [])
	if not first_on_mat and state.offered_slot >= 0:
		first_on_mat = true
		desk_board.animate_sample(state.offered_slot, maxf(0.06, ItemView.VISITOR_ARRIVAL - item_view.visitor_elapsed))
	desk_store.visible = counter_selection >= 0 and not _selected_item().is_empty()
	_refresh_dialogue(deal)
	if screen == "inspect":
		_refresh_inspection()
	if screen == "warehouse":
		_refresh_warehouse(counter_outcome, warehouse_outcome)


func _save_progress() -> void:
	if save_game != null:
		save_notice.visible = save_game.store_progress(state) != OK


func _refresh_dialogue(deal: Dictionary) -> void:
	if deal.is_empty():
		seller_line.say("")
		return
	if screen != "counter":
		return
	var region := MARKS_DIALOGUE if choosing_marks else COUNTER_DIALOGUE
	if not dialogue_placement.is_finite():
		_set_region(dialogue_panel, region)
	dialogue_actions.visible = not choosing_marks
	mark_choices.visible = choosing_marks
	seller_label.text = deal["seller"]
	var bargaining := state.offer_on_player_side()
	if not bargaining:
		price_announced = false
	var introduce_price := bargaining and not price_announced
	if introduce_price:
		price_announced = true
		reply = _price_line(deal)
	var delay := maxf(0.0, ItemView.VISITOR_ARRIVAL - item_view.visitor_elapsed)
	var line := reply if not reply.is_empty() else str(deal["dialogue"])
	seller_line.say("Что вы заметили на клеймах?" if choosing_marks else line, delay, introduce_price)
	tell_button.visible = shown_deal_id == "samovar" and not state.tanya_discussed_marks


func _refresh_inspection() -> void:
	var for_sale: bool = inspected_item.get("offered", false)
	inspection_title.text = state.active_deal().get("display", "") if for_sale else ItemCatalog.item_name(item_view.item_id)
	match item_view.active_tool:
		"lens":
			inspection_hint.text = "Ведите лупу по находке. Сверяйте детали с рисунками в журнале."
		"scale":
			inspection_hint.text = "Дождитесь, пока указатель безмена остановится."
		"thermometer":
			inspection_hint.text = "Наведите щуп на находку и удерживайте ЛКМ до конца замера."
		_:
			inspection_hint.text = "Откройте ящик справа и перетащите инструмент на находку."
	var lines: Array[String] = []
	var measurements: Dictionary = inspected_item.get("measurements", {})
	for tool: String in measurements:
		lines.append("%s · %s" % [InspectionCatalog.TOOLS[tool], measurements[tool]])
	evidence_label.text = "\n".join(lines)
	evidence_label.visible = not lines.is_empty()
	form_button.disabled = not _can_quote()
	form_button.tooltip_text = "Откройте бланк оценки." if not form_button.disabled else "Бланк доступен после осмотра находки посетителя инструментом."
	if form_button.disabled:
		_show_offer_form(false)


func _fill_offer_form(item: Dictionary) -> void:
	for child: Node in form_rules.get_children():
		form_rules.remove_child(child)
		child.queue_free()
	rule_boxes.clear()
	form_item_label.text = ItemCatalog.item_name(item["id"])
	for id: String in InspectionCatalog.checklist(item["id"]):
		var check := CheckBox.new()
		check.text = InspectionCatalog.CHECKLIST_LABELS[id]
		check.add_theme_font_size_override("font_size", 14)
		var quiet := _box(Color("ecd5a6"), Color("b99a68"), 5)
		check.add_theme_stylebox_override("normal", quiet)
		check.add_theme_stylebox_override("hover", _box(Color("f3e1b8"), Color("b99a68"), 5))
		var checked_style := _box(Color("d6b477"), Color("997342"), 5)
		check.add_theme_stylebox_override("pressed", checked_style)
		check.add_theme_stylebox_override("hover_pressed", checked_style)
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			check.add_theme_color_override(color_name, PAPER_INK)
		check.button_pressed = id in item.get("marked_rules", [])
		check.toggled.connect(_mark_rule.bind(id))
		form_rules.add_child(check)
		rule_boxes[id] = check


func _mark_rule(checked: bool, id: String) -> void:
	var selected_rules: Array = inspected_item.get("marked_rules", [])
	if checked and id not in selected_rules:
		selected_rules.append(id)
	elif not checked:
		selected_rules.erase(id)
	inspected_item["marked_rules"] = selected_rules
	_set_offer_amount(0)


func _can_quote() -> bool:
	return (
		screen == "inspect" and inspected_item.get("offered", false)
		and inspected_item.get("examined", false)
		and is_same(inspected_item, state.counter.item_at(state.offered_slot))
	)


func _calculate_offer() -> void:
	if not offer_form.visible or not _can_quote():
		return
	var total := InspectionCatalog.estimate(inspected_item["id"], inspected_item.get("marked_rules", []))
	_set_offer_amount(total)


func _adjust_offer_amount(change: int) -> void:
	_set_offer_amount(offer_form.amount + change)


func _set_offer_amount(amount: int) -> void:
	amount = clampi(amount, 0, GameState.MAX_OFFER)
	if inspected_item.get("offered", false):
		inspected_item["offer_draft"] = amount
	offer_form.item_id = str(inspected_item.get("id", ""))
	offer_form.artifact_name = form_item_label.text
	offer_form.marked_rules = inspected_item.get("marked_rules", [])
	offer_form.amount = amount
	offer_price_label.text = "%d ₽" % amount
	for change: int in price_steps:
		price_steps[change].disabled = clampi(amount + change, 0, GameState.MAX_OFFER) == amount
	send_form.disabled = amount < 1
	_save_progress()


func _refresh_warehouse(counter_outcome: Dictionary, warehouse_outcome: Dictionary) -> void:
	var item := _selected_item()
	var owned: bool = not item.is_empty() and not item.get("offered", false)
	shelf_detail.text = "Фон кладовой %d%% · Урон %d" % [state.warehouse_field(), state.damage]
	if owned:
		var shape := ItemCatalog.footprint(item["id"])
		shelf_detail.text += "\n%s · %d×%d · свойство %.1f%%" % [
			ItemCatalog.item_name(item["id"]), shape.x, shape.y, item["strength"]
		]
	transfer_button.visible = owned
	transfer_button.text = "На прилавок" if selected_area == "warehouse" else "В кладовую"
	inspect_stock.visible = owned and not item.get("broken", false)
	discard_button.visible = owned and item.get("broken", false)
	var normal := state.quote(selected_slot, "counter", selected_area)
	var lab := state.quote(selected_slot, "lab", selected_area)
	counter_sale.visible = owned and normal > 0
	lab_sale.visible = owned and lab > 0
	counter_sale.text = "Сдать · %d ₽" % normal
	lab_sale.text = "НИЛ-9 · %d ₽" % lab
	return_button.visible = owned and item.get("id") == "compass"
	field_check.set_pressed_no_signal(state.field_enhanced)
	field_check.disabled = not state.field_enhanced and state.money < GameState.FIELD_COST
	var forecasts: Array[String] = []
	for message: String in counter_outcome["messages"]:
		forecasts.append("Прилавок · %s" % message)
	for message: String in warehouse_outcome["messages"]:
		forecasts.append("Кладовая · %s" % message)
	forecast_label.text = "\n".join(forecasts) if not forecasts.is_empty() else "При этой раскладке изменений не ожидается."
	report_label.text = "\n".join(state.night_report) if not state.night_report.is_empty() else "Первая ночь ещё впереди."


func _navigate(next_screen: String) -> void:
	if transition.running or next_screen == screen:
		return
	if screen == "warehouse" or next_screen == "warehouse":
		_travel(1 if next_screen == "warehouse" else -1, _open_screen.bind(next_screen))
	else:
		_open_screen(next_screen)


func _travel(toward: int, arrive: Callable) -> void:
	if transition.running:
		return
	transition.begin()
	await transition.slide(toward, arrive)
	transition.finish()


func _open_screen(next_screen: String) -> void:
	_set_folder(false, false)
	journal_panel.hide()
	journal_button.set_pressed_no_signal(false)
	_show_offer_form(false)
	choosing_marks = false
	if next_screen != "inspect":
		inspected_item = {}
	screen = next_screen
	_layout_documents()
	_refresh()


func _toggle_folder() -> void:
	_set_folder(not toolbox_open)


func _set_folder(open: bool, animate := true) -> void:
	toolbox_open = open
	if open:
		documents_panel.show()
	folder_hotspot.set_open(open, animate)


func _reveal_tools(progress: float) -> void:
	item_view.toolbox_openness = progress
	documents_panel.modulate.a = smoothstep(0.18, 0.90, progress)
	if not toolbox_open and is_zero_approx(progress):
		documents_panel.hide()


func _layout_documents() -> void:
	var at_bench := screen == "inspect"
	_set_region(documents_panel, Rect2(0.065, 0.861, 0.422, 0.128) if at_bench else Rect2(0.670, 0.173, 0.308, 0.377))
	documents_layout.vertical = not at_bench
	documents_intro.visible = not at_bench
	documents_board.custom_minimum_size.y = 68 if at_bench else 136
	documents_board.cell_scale = 1.0 if at_bench else 0.83


func _toggle_journal() -> void:
	_show_journal(not journal_panel.visible)


func _show_journal(open: bool) -> void:
	journal_panel.visible = open
	journal_button.set_pressed_no_signal(open)
	if not open:
		return
	_show_offer_form(false)
	var at_bench := screen == "inspect"
	_set_region(journal_panel, INSPECTION_PAPER if at_bench else Rect2(0.022, 0.195, 0.263, 0.429))
	var index := journal_sections.selected
	if at_bench:
		var shape: String = ItemCatalog.definition(inspected_item["id"])["shape"]
		index = InspectionCatalog.SECTIONS.keys().find(shape)
	journal_sections.select(index)
	_read_journal_section(index)


func _toggle_offer_form() -> void:
	_show_offer_form(not offer_form.visible and _can_quote())
	if offer_form.visible:
		_show_journal(false)


func _show_offer_form(open: bool) -> void:
	offer_form.visible = open
	form_handoff.visible = open
	form_handoff.proposal_item = shown_deal_id if open else ""
	if open:
		handoff_recipient.text = "%s · %d ₽" % [state.active_deal()["seller"], state.asking_price()]
	form_button.set_pressed_no_signal(open)


func _drop_on_board(location: String, anchor: int, data: Dictionary) -> void:
	_use_tool(data, state.grid(location).item_at(anchor))


func _drop_on_enlarged_item(data: Dictionary) -> void:
	_use_tool(data, inspected_item)


func _use_tool(data: Dictionary, item: Dictionary) -> void:
	var kind := state.tool_kind(data)
	if kind.is_empty() or item.is_empty() or item.get("broken", false) or ItemCatalog.is_desk_item(item["id"]):
		return
	if screen != "inspect" or not is_same(inspected_item, item):
		_open_item(item)
	_set_folder(false)
	item_view.equip_tool(kind)
	item["examined"] = true
	_refresh()


func _record_measurement(kind: String) -> void:
	var measurements: Dictionary = inspected_item.get("measurements", {})
	measurements[kind] = InspectionCatalog.reading(inspected_item["id"], kind)
	inspected_item["measurements"] = measurements
	_refresh_inspection()
	_save_progress()


func _open_item(item: Dictionary) -> void:
	if screen == "warehouse":
		_travel(-1, _prepare_inspection.bind(item))
	else:
		_prepare_inspection(item)


func _prepare_inspection(item: Dictionary) -> void:
	var journal_was_open := journal_panel.visible
	inspected_item = item
	item_view.show_item(item["id"])
	_fill_offer_form(item)
	_set_offer_amount(item.get("offer_draft", 0))
	_open_screen("inspect")
	if journal_was_open:
		_show_journal(true)


func _show_mark_choices(enabled: bool) -> void:
	choosing_marks = enabled
	_refresh_dialogue(state.active_deal())


func _discuss_marks(conclusion: int) -> void:
	reply = state.report_tanya() if conclusion == 1 else "Мне дед тоже говорил, что крышка родная."
	choosing_marks = false
	state.tanya_discussed_marks = true
	_refresh()


func _price_line(deal: Dictionary) -> String:
	return deal["price_line"] % state.asking_price()


func _offer() -> void:
	_submit_offer(offer_form.proposal())


func _submit_offer(form: Dictionary) -> void:
	if not offer_form.visible or not _can_quote() or form != offer_form.proposal() or offer_form.amount <= 0:
		return
	var previous_offers := state.offers_left
	var previous_customer := state.customer
	var item_id := shown_deal_id
	var start := desk_board.piece_rect(state.offered_slot)
	status_label.text = state.offer_price(offer_form.amount, true)
	if state.customer == previous_customer and state.offers_left < previous_offers:
		reply = "За такую цену не отдам.\n" + _price_line(state.active_deal())
	elif state.customer != previous_customer:
		if state.last_purchase_slot >= 0:
			_animate_purchase(item_id, start)
		_open_screen("counter")
		return
	_refresh()


func _pass() -> void:
	status_label.text = state.pass_deal()
	_open_screen("counter")


func _animate_purchase(id: String, from: Rect2) -> void:
	if not from.has_area():
		from = Rect2(size * Vector2(0.56, 0.73), Vector2(86, 78))
	var sprite := ItemView.new()
	sprite.show_room = false
	sprite.sprite_fill = desk_board.sprite_fill
	sprite.show_item(id)
	sprite.position = from.position
	sprite.size = from.size
	sprite.z_index = 12
	add_child(sprite)
	var destination := shelf_tab.get_global_rect().get_center()
	var flight := create_tween()
	flight.tween_property(sprite, "position", destination, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	flight.parallel().tween_property(sprite, "scale", Vector2(0.28, 0.28), 0.42)
	flight.parallel().tween_property(sprite, "modulate:a", 0.0, 0.26).set_delay(0.20)
	flight.tween_callback(sprite.queue_free)


func _select_cell(location: String, cell: int) -> void:
	var grid := state.grid(location)
	var anchor := grid.anchor_at(cell)
	if anchor >= 0:
		selected_area = location
		selected_slot = anchor
	elif selected_slot >= 0 and state.move_item(selected_area, selected_slot, location, cell):
		_moved(location, cell)
		return
	else:
		selected_slot = -1
	_refresh()


func _activate_item(location: String, anchor: int) -> void:
	var item := state.grid(location).item_at(anchor)
	var id: String = item["id"]
	if id == "stamp_catalog":
		if screen == "warehouse":
			_travel(-1, _open_counter_journal)
		else:
			_toggle_journal()
	elif InspectionCatalog.TOOLS.has(id):
		status_label.text = "Перетащите инструмент на находку, чтобы применить его."
	else:
		_open_item(item)


func _open_counter_journal() -> void:
	_open_screen("counter")
	_show_journal(true)


func _inspect_selected() -> void:
	var item := _selected_item()
	if not item.is_empty():
		_open_item(item)


func _moved(location: String, anchor: int) -> void:
	if ItemCatalog.is_desk_item(state.grid(location).item_at(anchor).get("id", "")):
		_refresh()
		return
	selected_area = location
	selected_slot = anchor if not state.grid(location).item_at(anchor).get("offered", false) else -1
	_refresh()


func _selected_item() -> Dictionary:
	return state.grid(selected_area).item_at(selected_slot)


func _transfer_selected() -> void:
	if state.transfer_first(selected_area, selected_slot):
		selected_slot = -1
		status_label.text = "Находка перенесена."
	else:
		status_label.text = "Для находки нет места подходящего размера."
	_refresh()


func _sell(channel: String) -> void:
	status_label.text = state.sell(selected_slot, channel, selected_area)
	selected_slot = -1
	_refresh()


func _return_compass() -> void:
	status_label.text = state.return_compass(selected_slot, selected_area)
	selected_slot = -1
	_refresh()


func _discard_broken() -> void:
	state.clear_broken_item(selected_slot, selected_area)
	selected_slot = -1
	_refresh()


func _toggle_field(enabled: bool) -> void:
	state.set_enhanced_field(enabled)
	_refresh()


func _finish_day() -> void:
	if transition.running or state.ended or not state.active_deal().is_empty():
		return
	transition.begin()
	if screen == "warehouse":
		await transition.slide(-1, _open_screen.bind("counter"))
	else:
		_open_screen("counter")
	hud_row.hide()
	status_label.hide()
	await _light_room(1.0, 26.0 * 60.0, 0.85)
	state.next_night()
	_save_progress()
	selected_slot = -1
	transition.show_phase("02:00", state.night_report[0])
	await get_tree().create_timer(1.4).timeout
	if not state.ended:
		item_view.weather_day = state.day
		item_view.calendar_day = GameState.FIRST_DATE + state.day - 1
		transition.show_phase("Рассвет", state.calendar_date())
		await _light_room(0.0, 1440.0 + GameState.MORNING, 0.92)
		status_label.text = "02:00 · %s" % state.night_report[0]
	else:
		item_view.night_level = 0.0
		status_label.text = ""
	_open_screen("counter")
	transition.finish()


func _light_room(level: float, minutes: float, seconds: float) -> void:
	var light := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	light.tween_property(item_view, "night_level", level, seconds)
	light.tween_property(item_view, "clock_minutes", minutes, seconds)
	await light.finished


func _restart() -> void:
	state = GameState.new()
	selected_slot = -1
	shown_deal_id = ""
	status_label.text = ""
	item_view.night_level = 0.0
	_open_screen("counter")


func _input(event: InputEvent) -> void:
	if transition != null and transition.running:
		get_viewport().set_input_as_handled()
		return
	if screen != "inspect" or item_view == null or item_view.active_tool.is_empty():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		item_view.equip_tool("")
		_refresh_inspection()
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_F11:
		var window := get_window()
		window.mode = Window.MODE_WINDOWED if window.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and item_view != null:
		if toolbox_open:
			_toggle_folder()
		elif journal_panel.visible:
			_show_journal(false)
		elif offer_form.visible:
			_show_offer_form(false)
		elif screen != "counter":
			_navigate("counter")
		elif get_window().mode == Window.MODE_FULLSCREEN:
			get_window().mode = Window.MODE_WINDOWED
		get_viewport().set_input_as_handled()


func _board(location: String) -> InventoryBoard:
	var view := InventoryBoard.new()
	view.location = location
	view.cell_selected.connect(_select_cell)
	view.item_activated.connect(_activate_item)
	view.item_moved.connect(_moved)
	view.tool_dropped.connect(_drop_on_board)
	return view


func _place(control: Control, region: Rect2) -> void:
	add_child(control)
	_set_region(control, region)


func _set_region(control: Control, region: Rect2) -> void:
	control.anchor_left = region.position.x
	control.anchor_top = region.position.y
	control.anchor_right = region.end.x
	control.anchor_bottom = region.end.y
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0


func _row(parent: Control, spacing := 8) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", spacing)
	parent.add_child(row)
	return row


func _panel(parent: Control, width := 0.0, ratio := 1.0) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)
	return column


func _button(parent: Control, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 32
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _icon_button(parent: Control, title: String, kind: String, action: Callable, icon_width: int) -> Button:
	var button := _button(parent, title, action)
	button.icon = DeskIcons.icon(kind)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_constant_override("icon_max_width", icon_width)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


func _scroll_text(parent: VBoxContainer, height: float, ink: Color) -> Label:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = height
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var value := _label("", 15, ink, true)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(value)
	return value


func _label(value: String, font_size: int, ink: Color, wrap := false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_color_override("font_color", ink)
	label.add_theme_font_size_override("font_size", font_size)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _make_theme() -> Theme:
	var result := Theme.new()
	result.default_font = ThemeDB.fallback_font
	result.default_font_size = 16
	result.set_stylebox("panel", "PanelContainer", _box(Color("292f28"), Color("786348"), 11))
	result.set_stylebox("normal", "Button", _box(Color("3c3c2e"), Color("8d7652")))
	result.set_stylebox("hover", "Button", _box(Color("504831"), Color("ba9460")))
	result.set_stylebox("pressed", "Button", _box(Color("47543d"), Color("adb47b")))
	result.set_stylebox("disabled", "Button", _box(Color("2e3027"), Color("555743")))
	result.set_stylebox("focus", "Button", _box(Color.TRANSPARENT, TEAL))
	result.set_color("font_color", "Button", INK)
	result.set_color("font_hover_color", "Button", INK)
	result.set_color("font_pressed_color", "Button", INK)
	result.set_color("font_disabled_color", "Button", Color("a29e84"))
	result.set_color("font_color", "CheckButton", INK)
	return result


func _box(fill: Color, border: Color, padding := 7) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_content_margin(side, padding)
	return box
