extends SceneTree

const BUYER := GameState.COUNTER_SIZE.x * GameState.PLAYER_ROW
const INITIAL_OFFER := GameState.OFFER_COLUMN
const SAMOVAR_CORNER := GameState.COUNTER_SIZE.x + 1
const STOCK_CORNER := GameState.WAREHOUSE_SIZE.x + 1

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_trades()
	_check_grids_and_night()
	_check_documents()
	_check_dialogue()
	_check_save_recovery()
	await _check_opening_with_save()
	await _play_first_cycle()
	print("First cycle checks passed." if failures == 0 else "%d first cycle checks failed." % failures)
	quit(1 if failures else 0)


func _check_trades() -> void:
	var state := GameState.new()
	_expect(not state.next_night(), "Finish each visit before the night")
	_expect(state.counter.items.size() == 156 and state.warehouse.items.size() == 70, "The two grids have their own capacity")
	_expect(not state.move_item("counter", INITIAL_OFFER, "warehouse", 0), "An unpaid sample cannot be put in storage")
	_expect(state.move_item("counter", INITIAL_OFFER, "counter", 1) and state.offered_slot == 1, "A sample snaps to another slot")
	state.offer_price(102)
	_expect(state.customer == 0 and state.money == 300, "A seller-side item cannot be purchased")
	_expect(not state.move_item("counter", 1, "counter", BUYER - 2), "A two-row sample cannot straddle the split")
	_expect(state.move_item("counter", 1, "counter", BUYER + 1), "A sample can move onto the buyer half")
	_expect(state.offer_on_player_side() and state.move_item("counter", BUYER + 1, "counter", 1)
		and not state.offer_on_player_side(), "Moving the sample back retracts the price")
	state.move_item("counter", 1, "counter", BUYER + 1)
	state.set_enhanced_field(true)
	state.offer_price(300)
	_expect(state.money == 300 and state.customer == 0, "Cash reserved for the field cannot be spent")
	state.set_enhanced_field(false)
	state.offer_price(85)
	_expect(state.offers_left == 1, "Low offer consumes one attempt")
	state.offer_price(102)
	_expect(state.money == 198 and not state.tanya_told, "A buyer can submit the manual estimate without automated discoveries")
	_expect(state.counter.anchor_at(BUYER + 1) == -1 and state.warehouse.anchor_at(STOCK_CORNER) == 0, "A purchase leaves the mat and owns its complete storage footprint")
	_expect(state.quote(0, "counter", "warehouse") == 84 and state.quote(0, "lab", "warehouse") == 230, "An appraisal is intrinsic and independent of what the player inspected")
	_expect(state.counter.items[INITIAL_OFFER].get("offered", false), "The next visitor places the offer in front of them")
	state.pass_deal()
	state.next_night()
	state.pass_deal()
	state.pass_deal()
	state.next_night()
	state.pass_deal()
	state.next_night()
	_expect(not state.ended and state.day == 4, "The compass visit leads to a fourth day")
	for day in range(4, GameState.LAST_DAY + 1):
		while not state.active_deal().is_empty():
			if day == GameState.LAST_DAY:
				_expect(state.active_deal()["seller"] != "Таня Гусева", "Tanya does not return after finding out about the lid")
			state.pass_deal()
		state.next_night()
	_expect(state.ended and state.ending_text().contains("узнала"), "A quiet purchase has a narrative consequence")
	var full := GameState.new()
	for slot in full.warehouse.items.size():
		full.warehouse.items[slot] = ItemCatalog.make_item("soot_glass")
	full.move_item("counter", INITIAL_OFFER, "counter", BUYER)
	full.offer_price(102)
	_expect(full.money == 300 and full.offered_slot == BUYER and full.last_purchase_slot == -1,
		"Insufficient storage leaves the offer and cash intact")


func _check_grids_and_night() -> void:
	var state := GameState.new()
	_expect(state.counter.anchor_at(INITIAL_OFFER + SAMOVAR_CORNER) == INITIAL_OFFER, "The lower right square belongs to the multi-cell samovar")
	_expect(not state.can_move("counter", INITIAL_OFFER, "counter", GameState.COUNTER_SIZE.x - 1), "A samovar cannot stick out of the grid")
	state.counter.items[2] = ItemCatalog.make_item("soot_glass")
	_expect(not state.can_move("counter", INITIAL_OFFER, "counter", 1), "A large footprint cannot cover another object")
	state.counter.items[2] = {}
	state.move_item("counter", INITIAL_OFFER, "counter", BUYER)
	state.offer_price(102)
	_expect(state.forecast("counter")["damage"] == 0, "A visitor's unpaid glass cannot cause night damage")
	state.move_item("counter", state.offered_slot, "counter", BUYER)
	state.offer_price(68)
	_expect(state.forecast("warehouse")["damage"] == 20, "The entire samovar footprint counts for adjacency after purchase")
	_expect(state.counter.items[INITIAL_OFFER].is_empty(), "Transferring a purchase removes the original")
	var risky := state.forecast("warehouse")
	_expect(risky["damage"] == 20 and risky["items"][2]["broken"], "A nearby glass breaks in the warehouse")
	_expect(not state.warehouse.items[2]["broken"], "Forecasting does not change storage")
	_expect(state.move_item("warehouse", 2, "warehouse", 3), "A small item moves to a free square")
	var safe := state.forecast("warehouse")
	_expect(safe["damage"] == 0, "An empty square between items prevents the reaction")
	_expect(is_equal_approx(safe["items"][0]["strength"], 97.5), "Samovar loses precisely 2.5 points")
	state.move_item("warehouse", 3, "warehouse", 2)
	_expect(state.next_night(), "Night advances when no visit remains")
	_expect(state.warehouse.items == risky["items"] and state.damage == 20, "The committed night matches the forecast")
	_expect(state.forecast("warehouse")["damage"] == 0, "Broken glass cannot cause the reaction twice")
	state.clear_broken_item(2, "warehouse")
	_expect(state.warehouse.anchor_at(2) == -1, "Clearing fragments frees their square")
	var packed := ItemGrid.new(5, 4)
	for slot in packed.items.size():
		if slot not in [0, 4, 15, 19]:
			packed.items[slot] = ItemCatalog.make_item("frost_glass")
	_expect(packed.put_first(ItemCatalog.make_item("samovar")) == -1, "Four disconnected empty squares cannot fit a samovar")


func _check_documents() -> void:
	var state := GameState.new()
	_expect(state.documents.items.size() == 18 and state.documents.anchor_at(8) == 2,
		"The document box starts with four items, including tools with larger footprints")
	_expect(not state.move_item("counter", INITIAL_OFFER, "documents", 1), "A visitor's artifact cannot enter the drawer")
	_expect(not state.move_item("documents", 2, "counter", BUYER) and not state.move_item("documents", 2, "warehouse", 0),
		"Tools stay in their box when they are not being applied")
	_expect(state.move_item("documents", 2, "documents", 3), "The scale can move to a different column in the box")
	_expect(state.documents.anchor_at(9) == 3 and state.counter.anchor_at(BUYER) == -1,
		"The scale owns its complete footprint and leaves no duplicate")
	state.warehouse.put_first(ItemCatalog.make_item("clock"))
	_expect(not state.move_item("warehouse", 0, "documents", 5), "The drawer also rejects bought artifacts")


func _check_dialogue() -> void:
	var line := DialogueLine.new()
	root.add_child(line)
	var greeting := "Добрый день.\nПринёс находку."
	line.say(greeting, 0.5)
	line._process(0.25)
	_expect(line.visible_characters == 0, "The greeting waits for the visitor")
	line._process(0.32)
	_expect(line.text == "Добрый день." and line.visible_characters in range(1, line.text.length()),
		"Only the first phrase starts printing")
	line._process(0.8)
	_expect(line.text == "Добрый день." and line.visible_characters == -1, "A complete phrase stays on screen for reading")
	line.say(greeting)
	line._process(1.8)
	line._process(0.10)
	_expect(line.text == "Принёс находку." and line.visible_characters in range(1, line.text.length()),
		"After the pause the next phrase starts printing without replaying the greeting")
	line.free()


func _check_save_recovery() -> void:
	var save := GameSave.new(_test_save_path("recovery"))
	var state := GameState.new()
	state.move_item("documents", 2, "documents", 3)
	state.set_enhanced_field(true)
	_expect(save.store_progress(state) == OK, "The first autosave commits")
	state.pass_deal()
	state.pass_deal()
	state.next_night()
	_expect(save.store_progress(state) == OK and save.generation == 2, "The night commits a new generation")
	_expect(save.store_progress(state) == OK and save.generation == 2, "An unchanged state does not rewrite the save")
	var recovered := save.load_progress()
	_expect(recovered != null and recovered.day == 2 and recovered.money == 285 and not recovered.field_enhanced
		and recovered.documents.anchor_at(9) == 3, "Resume after midnight without paying or resolving the night twice")
	var damaged := FileAccess.open(save.slot_path(save.active_slot), FileAccess.WRITE)
	damaged.store_var({"version": GameSave.VERSION, "generation": 2, "state": {}}, false)
	damaged.close()
	recovered = save.load_progress()
	_expect(recovered != null and recovered.day == 1 and recovered.money == 300 and recovered.field_enhanced,
		"An invalid latest file falls back to the last good autosave")
	_remove_test_saves(save)


func _check_opening_with_save() -> void:
	var save := GameSave.new(_test_save_path("opening"))
	var state := GameState.new()
	state.pass_deal()
	state.pass_deal()
	state.set_enhanced_field(true)
	state.next_night()
	_expect(save.store_progress(state) == OK, "Seed an existing session for the opening menu")
	var scene: Variant = load("res://main.tscn").instantiate()
	scene.save_game = GameSave.new(save.base_path)
	root.size = Vector2i(1152, 720)
	root.add_child(scene)
	await process_frame
	_skip_splash()
	_expect(scene.item_view == null and scene.opening.save_summary.text.contains("День 2"),
		"The title loads the autosave without entering the counter")
	_expect(_press(scene, "Пролог") and not scene.opening.skip.visible, "Replay the story from the menu")
	var click_point := root.get_visible_rect().get_center()
	for index in range(1, OpeningScreen.PAGES.size()):
		_right_click(click_point)
		_expect(scene.opening.page == index, "Right-click advances the replayed prologue")
	_right_click(click_point)
	_expect(scene.opening.stage == OpeningScreen.Stage.MENU and scene.save_game.generation == 1,
		"Replaying the story returns to the menu without changing the saved game")
	_expect(_press(scene, "Новая игра") and scene.opening.stage == OpeningScreen.Stage.CONFIRM,
		"Starting over prompts before replacing a saved game")
	_expect(_press(scene, "Отмена") and scene.opening.stage == OpeningScreen.Stage.MENU, "Cancel and keep the existing session")
	_expect(_press(scene, "Новая игра") and _press(scene, "Начать заново") and _press(scene, "К меню"),
		"Backing out of the new-game story keeps the old save")
	_expect(scene.save_game.generation == 1 and _press(scene, "Продолжить") and scene.state.day == 2
		and scene.cash_label.text == "285 ₽", "Continue enters the saved day without playing the story again")
	scene.queue_free()
	await process_frame
	_remove_test_saves(save)


func _skip_splash() -> void:
	var point := root.get_visible_rect().get_center()
	_mouse_button(point, true)
	_mouse_button(point, false)


func _play_first_cycle() -> void:
	var scene: Variant = load("res://main.tscn").instantiate()
	var save := GameSave.new(_test_save_path("interface"))
	scene.save_game = save
	root.size = Vector2i(1152, 720)
	root.add_child(scene)
	await process_frame
	_expect(scene.opening.stage == OpeningScreen.Stage.SPLASH and scene.opening.backdrop.texture != null,
		"A new launch opens on the illustrated splash")
	_skip_splash()
	_expect(_press(scene, "Начать игру") and scene.opening.story_place.text.contains("2391"), "Start a new game with the excavation")
	_expect(not _press(scene, "Дальше"), "The story uses right-click instead of a next button")
	var click_point := root.get_visible_rect().get_center()
	for index in range(1, OpeningScreen.PAGES.size()):
		_right_click(click_point)
		_expect(scene.opening.page == index and scene.opening.backdrop.texture != null, "Right-click advances to the next illustrated scene")
	_expect(save.generation == 0, "Reading the prologue does not start saving")
	_right_click(click_point)
	_expect(not scene.opening.visible and scene.item_view != null, "Right-click on the final scene enters the counter")
	await process_frame
	_expect(ItemView.room_art != null and ItemView.visitor_art.size() == 4, "The room and the four supplied portraits load")
	_expect(ItemView.toolbox_art != null, "The retouched tabletop with the toolbox loads")
	for id: String in ItemCatalog.ITEMS.keys() + ItemCatalog.DESK_ITEMS.keys():
		var art := ItemView.stock_art.get(id) as Texture2D
		_expect(ResourceLoader.exists("res://art/objects/%s.png" % ItemCatalog.art_id(id)) and art != null
			and maxi(art.get_width(), art.get_height()) <= ObjectSprites.WORKING_SIZE
			and art.get_image().detect_alpha() != Image.ALPHA_NONE,
			"%s uses the supplied artwork with a transparent silhouette" % id)
	for name: String in VisitorSprites.PORTRAITS:
		var portrait := ItemView.visitor_art[name]
		_expect(portrait != null and portrait.get_size() == Vector2(VisitorSprites.SIZE),
			"%s uses the new portrait resolution" % name)
	var desk: InventoryBoard = scene.desk_board
	var last_row := GameState.COUNTER_SIZE.x * (GameState.COUNTER_SIZE.y - 1)
	var far_width := desk.cell_center(1).x - desk.cell_center(0).x
	var near_width := desk.cell_center(last_row + 1).x - desk.cell_center(last_row).x
	_expect(far_width < near_width, "The mat narrows toward the far edge")
	_expect(not desk.grid_is_visible() and desk.previews[INITIAL_OFFER].visible, "An idle mat shows the item without grid lines")
	_expect(desk._cell_at(Vector2(4, 4)) == -1 and desk._cell_at(Vector2(desk.size.x - 4, 4)) == -1,
		"The bare tabletop beside the mat cannot receive items")
	for cell in scene.state.counter.items.size():
		_expect(desk._cell_at(desk.cell_center(cell)) == cell, "Every projected cell center lands in its own slot")
	var folder: DocumentHotspot = scene.folder_hotspot
	var toolbox_rect := folder.get_global_rect()
	_expect(folder._has_point(folder.size * 0.5) and not folder._has_point(Vector2(1, 1)),
		"Only the actual document box responds to the mouse")
	_expect(root.get_visible_rect() == scene.counter_screen.get_global_rect(), "The art fills the screen")
	_expect(scene.seller_line.visible_characters < scene.seller_line.text.length(), "Dialogue begins letter by letter")
	_expect(scene.seller_label.text == "Таня Гусева", "The dialogue names the current character")
	var weather_start: float = scene.item_view.weather_time
	_expect(scene.desk_board.sample_is_landing() and not scene.offer_form.is_visible_in_tree(),
		"The sample lands before appraisal is available")
	await create_timer(1.10).timeout
	_expect(scene.item_view.weather_time > weather_start and scene.seller_line.visible_characters > 0,
		"Weather and dialogue advance independently")
	_expect(scene.item_view.speaking, "The visitor moves while the reply is being typed")
	_expect(not scene.desk_board.sample_is_landing(), "The item finishes its entry animation")
	_expect(scene.seller_line.tooltip_text.is_empty(), "Hovering the dialogue text has no tooltip")
	var initial_dialogue: Vector2 = scene.dialogue_panel.position
	var grip: Vector2 = scene.seller_label.get_global_rect().get_center()
	var movement := Vector2(195, -128)
	_mouse_button(grip, true)
	var motion := InputEventMouseMotion.new()
	motion.position = grip + movement
	motion.global_position = motion.position
	motion.relative = movement
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	_mouse_button(motion.position, false)
	var moved_dialogue := (initial_dialogue + movement).round()
	_expect(scene.dialogue_panel.position.is_equal_approx(moved_dialogue), "Drag the panel by the speaker's heading")
	var line_point: Vector2 = scene.seller_line.get_global_rect().get_center()
	_mouse_button(line_point, true)
	_mouse_button(line_point, false)
	_expect(scene.seller_line.visible_characters == -1, "Clicking the line still reveals the phrase")
	_hover(scene.desk_board, INITIAL_OFFER + SAMOVAR_CORNER)
	_expect(scene.desk_board.previews[INITIAL_OFFER].hover_outline, "Hover outlines the actual sprite")
	_click(scene.desk_board, INITIAL_OFFER + SAMOVAR_CORNER)
	_expect(scene.screen == "inspect" and scene.item_view.item_id == "samovar",
		"Clicking a covered square opens the actual item")
	_expect(scene.form_button.disabled and not scene.offer_form.visible, "A plain inspection starts with the offer form closed")
	_expect(not scene.dialogue_panel.visible and not _press(scene, "Документы"), "Inspection hides the dialogue and removes its toolbox shortcut")
	_expect(folder.get_global_rect() == toolbox_rect, "The toolbox stays at the same spot in the room while inspecting")
	var closed_lid := folder._lid_points()
	_expect(_open_toolbox(scene), "Click the physical toolbox to open the tool cells")
	_expect(scene.documents_board.grid_is_visible(), "The toolbox draws every cell even with no item being dragged")
	await create_timer(DocumentHotspot.SWING_TIME * 0.50).timeout
	var swinging_lid := folder._lid_points()
	_expect(folder.openness > 0.0 and folder.openness < 1.0 and swinging_lid[0] == closed_lid[0]
		and swinging_lid[1] == closed_lid[1] and swinging_lid[3] != closed_lid[3], "The lid swings around the two fixed hinges")
	_expect(is_equal_approx(scene.item_view.toolbox_openness, folder.openness), "The painted lid uses the same animation as the toolbox hit area")
	await create_timer(DocumentHotspot.SWING_TIME * 0.65).timeout
	_expect(is_equal_approx(folder.openness, 1.0) and is_equal_approx(scene.documents_panel.modulate.a, 1.0),
		"The opened lid reveals the tool tray")
	_open_toolbox(scene)
	await create_timer(DocumentHotspot.SWING_TIME + 0.06).timeout
	_expect(not scene.documents_panel.visible and folder._lid_points() == closed_lid, "Closing the box shuts the lid and hides the tray")
	_expect(_open_toolbox(scene), "The physical box can be opened again")
	await process_frame
	await _drag(scene.documents_board, 8, scene.documents_board, 9)
	_expect(scene.state.documents.anchor_at(9) == 3, "Move the scale inside the box by its lower square")
	await _drag(scene.documents_board, 9, scene.documents_board, 8)
	_click(scene.documents_board, 12)
	_expect(scene.journal_panel.visible and scene.documents_board.is_visible_in_tree() and not scene.offer_form.visible,
		"Clicking the journal in the drawer opens a reference beside the tools")
	var ids: Array[String] = ["samovar", "frost_glass", "clock", "compass"]
	for index in ids.size():
		scene.journal_sections.select(index)
		scene.journal_sections.item_selected.emit(index)
		var illustrations: Array[String] = []
		for entry: Node in scene.journal_entries.find_children("*", "", true, false):
			if entry is JournalIllustration:
				illustrations.append(entry.rule)
		_expect(illustrations == InspectionCatalog.checklist(ids[index]), "Every feature has an illustration in its journal section")
	_expect(scene.journal_panel.find_children("*", "CheckBox", true, false).is_empty(), "The journal is a read-only reference")
	_expect(_press(scene, "К прилавку"), "Return to the mat")
	await process_frame
	_expect(_open_toolbox(scene), "Open the toolbox on the counter")
	await process_frame
	await _drag(scene.documents_board, 8, scene.desk_board, INITIAL_OFFER + SAMOVAR_CORNER)
	var item_view: ItemView = scene.item_view
	_expect(item_view.active_tool == "scale" and scene.evidence_label.text.is_empty(),
		"The scale starts weighing before it records the reading")
	_right_click(scene.inspection_panel.get_global_rect().get_center())
	await create_timer(ItemView.WEIGH_SECONDS + 0.12).timeout
	_expect(item_view.active_tool.is_empty() and scene.screen == "inspect" and scene.evidence_label.text.is_empty(),
		"Right-click on the sidebar puts away the scale and cancels a pending reading")
	_expect(_open_toolbox(scene), "Reopen the toolbox for the scale")
	await process_frame
	await _drag_at(scene.documents_board, 2, item_view, _sprite_point(item_view, Vector2(0.48, 0.51)))
	await create_timer(ItemView.WEIGH_SECONDS + 0.15).timeout
	_expect(scene.evidence_label.text.contains("6,0 кг") and scene.state.documents.anchor_at(8) == 2,
		"Dropping the scale on a finding weighs it and leaves the instrument in the drawer")
	_right_click(item_view.get_global_rect().get_center())
	_expect(item_view.active_tool.is_empty() and scene.evidence_label.text.contains("6,0 кг"),
		"Putting the scale away keeps the completed reading")
	_expect(not scene.form_button.disabled and not scene.offer_form.visible, "A tool makes the separate form available")
	_expect(_press(scene, "Журнал") and scene.journal_sections.selected == 0, "The bench opens the journal to the sample's category")
	_expect(_open_toolbox(scene), "Open the toolbox from the inspection bench")
	await process_frame
	await _drag_at(scene.documents_board, 0, item_view, _sprite_point(item_view, Vector2(0.48, 0.51)))
	_expect(item_view.lens_active and scene.state.documents.item_at(0).get("id") == "lens" and scene.journal_panel.visible,
		"Dropping the lens activates it while the journal stays open beside the sample")
	_aim(item_view, Vector2(0.24, 0.46))
	await create_timer(0.37).timeout
	var focus: Vector2 = item_view.lens_material.get_shader_parameter("focus")
	_expect(item_view.lens_surface.visible and focus.distance_to(Vector2(0.24, 0.46)) < 0.015,
		"The glass samples freely between discovery positions")
	_expect(scene.state.asking_price() == 130 and scene.offer_form.amount == 0, "Looking through the lens leaves the asking price and offer alone")
	var readings: String = scene.evidence_label.text
	_aim(item_view, Vector2(0.49, 0.382))
	await create_timer(0.37).timeout
	_expect(item_view.lens_material.get_shader_parameter("artifact") == ItemView.stock_art["samovar"],
		"The lens samples the supplied samovar texture")
	_aim(item_view, Vector2(0.49, 0.215))
	await create_timer(0.37).timeout
	_expect(scene.evidence_label.text == readings and scene.state.asking_price() == 130 and scene.offer_form.amount == 0,
		"Aiming at either physical mark never identifies the sign or appraises it for the player")
	_right_click(_sprite_point(item_view, Vector2(0.49, 0.215)))
	_expect(not item_view.lens_active and not item_view.lens_surface.visible and scene.screen == "inspect"
		and scene.state.documents.item_at(0).get("id") == "lens", "Right-click closes the lens and keeps the bench open")
	_expect(_press(scene, "К прилавку") and scene.dialogue_panel.visible, "Return to the counter to speak with Tanya")
	_expect(_press(scene, "Обсудить клейма") and scene.mark_choices.visible and not scene.dialogue_actions.visible,
		"The mark choices appear inside the dialogue")
	_expect(scene.dialogue_panel.position.is_equal_approx(moved_dialogue), "The manually placed dialogue stays put when reopening and showing choices")
	_expect(_press(scene, "Крышка более поздняя") and scene.state.tanya_told,
		"Disclosing the replacement lid changes the note")
	_expect(not scene.mark_choices.visible and not scene.tell_button.visible, "The options disappear after answering")
	await _drag(scene.desk_board, INITIAL_OFFER + SAMOVAR_CORNER, scene.desk_board, BUYER + SAMOVAR_CORNER)
	_expect(scene.seller_line.text == "За самовар хочу 130 рублей." and scene.state.offered_slot == BUYER,
		"Tanya states her price in dialogue when the item moves onto the player's half")
	_expect(scene.seller_line.is_processing() and scene.seller_line.visible_characters < scene.seller_line.text.length(),
		"The price prints as a regular dialogue line")
	await _drag(scene.desk_board, BUYER + SAMOVAR_CORNER, scene.desk_board, INITIAL_OFFER + SAMOVAR_CORNER)
	_click(scene.desk_board, INITIAL_OFFER + SAMOVAR_CORNER)
	_expect(_press(scene, "Бланк") and scene.offer_form.visible and scene.send_form.disabled and scene.offer_form.amount == 0,
		"Open the blank paper without automatically marking features or assigning a price")
	_expect(scene.form_handoff.visible and scene.handoff_recipient.text == "Таня Гусева · 130 ₽" and not scene.dialogue_panel.visible,
		"The handoff is below the worktop and names the seller while the dialogue stays hidden")
	_expect(scene.offer_form.find_children("*", "LineEdit", true, false).is_empty() and not _press(scene, "−5"),
		"The form uses buttons and cannot decrement at zero")
	_expect(_press(scene, "+5") and _press(scene, "−100") and scene.offer_form.amount == 0 and scene.send_form.disabled,
		"A step larger than the current amount stops at zero")
	scene.rule_boxes["kluchi"].button_pressed = true
	scene.rule_boxes["late_lid"].button_pressed = true
	_expect(_press(scene, "Рассчитать") and scene.offer_form.amount == 84, "Only manually checked signs change the draft")
	_expect(_press(scene, "Передать бланк") and scene.status_label.text.contains("отказывается") and scene.offer_form.visible
		and scene.state.money == 300, "A declined form stays open for revision without spending money")
	scene.rule_boxes["heat"].button_pressed = true
	_expect(scene.send_form.disabled, "A changed observation invalidates the previous price")
	_expect(_press(scene, "Рассчитать") and scene.offer_form.amount == 102, "The new sign changes the new total")
	_expect(_press(scene, "+10") and _press(scene, "+10") and scene.offer_form.amount == 122
		and scene.offer_price_label.text == "122 ₽", "The price buttons adjust the calculated amount and update the form")
	_expect(_press(scene, "Журнал") and not scene.offer_form.visible and _press(scene, "Бланк") and not scene.journal_panel.visible
		and scene.offer_form.amount == 122 and scene.rule_boxes["heat"].button_pressed, "Consulting the journal keeps the price and observations on the form")
	var saved_form := GameSave.new(save.base_path).load_progress()
	var draft: Dictionary = saved_form.counter.item_at(saved_form.offered_slot) if saved_form != null else {}
	_expect(saved_form != null and saved_form.tanya_discussed_marks and saved_form.offers_left == 1
		and draft.get("offer_draft") == 122 and draft.get("marked_rules") == ["kluchi", "late_lid", "heat"]
		and draft.get("measurements", {}).get("scale") == "6,0 кг", "The autosave includes the draft, instrument readings and narrative choices")
	await _drag_offer(scene)
	_expect(scene.state.money == 178, "Tanya accepts the revised form dropped into the handoff")
	_expect(scene.state.warehouse.anchor_at(STOCK_CORNER) == 0 and scene.state.counter.anchor_at(INITIAL_OFFER + SAMOVAR_CORNER) == -1,
		"The purchased samovar leaves the mat for storage")
	await create_timer(1.10).timeout
	_expect(_open_toolbox(scene), "Open the toolbox for the next visitor")
	await process_frame
	await _drag(scene.documents_board, 4, scene.desk_board, INITIAL_OFFER)
	var glass_uv := Vector2(0.49, 0.57)
	var contact := item_view.global_position + _sprite_point(item_view, glass_uv)
	_aim(item_view, glass_uv)
	await create_timer(ItemView.TEMPERATURE_SECONDS + 0.12).timeout
	_expect(item_view.active_tool == "thermometer" and scene.evidence_label.text.is_empty(),
		"Hovering over glass without holding the probe does not measure it")
	_mouse_button(contact, true)
	await create_timer(0.24).timeout
	_right_click(contact)
	_mouse_button(contact, false)
	_expect(item_view.active_tool.is_empty() and scene.evidence_label.text.is_empty() and scene.screen == "inspect",
		"Right-click cancels a thermometer still in contact")
	_expect(_open_toolbox(scene), "Reopen the toolbox for another temperature measurement")
	await process_frame
	await _drag_at(scene.documents_board, 4, item_view, _sprite_point(item_view, glass_uv))
	_aim(item_view, glass_uv)
	_mouse_button(contact, true)
	await create_timer(ItemView.TEMPERATURE_SECONDS + 0.15).timeout
	_mouse_button(contact, false)
	_expect(scene.evidence_label.text == "Термометр · −12 °C" and scene.state.asking_price() == 70 and scene.offer_form.amount == 0,
		"The thermometer shows only its reading")
	_expect(_press(scene, "Бланк"), "Open a fresh form for the glass")
	_expect(scene.handoff_recipient.text == "Мирон · 70 ₽" and not scene.dialogue_panel.visible,
		"The handoff carries the current seller's name and asking price")
	await process_frame
	_expect(root.get_visible_rect().encloses(scene.offer_form.get_global_rect()),
		"All five observations and the price buttons fit on the form")
	scene.rule_boxes["seam"].button_pressed = true
	scene.rule_boxes["cold"].button_pressed = true
	_right_click(contact)
	_expect(item_view.active_tool.is_empty() and scene.evidence_label.text == "Термометр · −12 °C"
		and scene.rule_boxes["cold"].button_pressed and scene.state.documents.item_at(4).get("id") == "thermometer",
		"Putting the probe away keeps the completed reading and the player's checklist")
	for step in ["+100", "−10", "−10", "−5", "−5", "−1", "−1"]:
		_expect(_press(scene, step), "Adjust a blank form with " + step)
	_expect(scene.offer_form.amount == 68, "Coarse and fine steps can reach an exact price from zero")
	_expect(_press(scene, "Передать бланк") and scene.state.money == 110,
		"Buy the frost glass with a price set entirely by buttons")
	_expect(not scene.dialogue_panel.visible and scene.seller_line.text.is_empty() and scene.item_view.clock_minutes == GameState.EVENING,
		"A closed counter marks evening without a fictional speaker")
	_expect(_press(scene, "Кладовая"), "Open the dedicated warehouse")
	_expect(scene.transition.running and scene.screen == "counter", "The room switches only after the transition begins")
	await scene.transition.finished
	await process_frame
	_expect(root.get_visible_rect().encloses(scene.shelf_screen.get_global_rect()), "Both grids and stock controls fit")
	_expect(scene.forecast_label.text.contains("лопается") and scene.stock_board.danger.has(0), "The larger footprint causes visible danger")
	await _drag(scene.stock_board, STOCK_CORNER, scene.transfer_board, SAMOVAR_CORNER)
	_expect(scene.state.counter.anchor_at(SAMOVAR_CORNER) == 0 and scene.state.warehouse.anchor_at(STOCK_CORNER) == -1,
		"Dragging by the lower right square moves the complete object without shifting the grip")
	await _drag(scene.transfer_board, SAMOVAR_CORNER, scene.stock_board, STOCK_CORNER)
	await _drag(scene.stock_board, 2, scene.stock_board, 1)
	_expect(scene.state.warehouse.anchor_at(2) == 2, "An overlapping drop leaves the glass in place")
	await _drag(scene.stock_board, 2, scene.stock_board, 3)
	_expect(scene.state.warehouse.anchor_at(3) == 3, "A valid drag separates the glass from the samovar")
	scene.field_check.button_pressed = true
	_expect(scene.forecast_label.text.contains("изменений не ожидается"), "Protection applies to the stored objects")
	_expect(_press(scene, "Завершить день"), "Finish the first day")
	_expect(scene.transition.running and scene.state.day == 1, "The night animation starts before advancing the date")
	await scene.transition.finished
	_expect(scene.state.day == 2 and scene.item_view.weather_day == 2 and scene.state.money == 95, "Night changes weather and charges for protection")
	_expect(scene.item_view.calendar_day == 26 and scene.item_view.clock_minutes == GameState.MORNING, "The tabletop calendar flips at dawn")
	_expect(is_zero_approx(scene.item_view.night_level) and scene.dialogue_panel.visible, "Daylight returns before the next visitor arrives")
	_expect(_press(scene, "Кладовая"), "Go back to the warehouse")
	await scene.transition.finished
	await process_frame
	_click(scene.stock_board, STOCK_CORNER)
	_expect(_press(scene, "НИЛ-9 · 230 ₽") and scene.state.money == 325, "The lab buys the samovar at its intrinsic price")
	_expect(scene.state.warehouse.anchor_at(STOCK_CORNER) == -1, "Selling frees all four cells")
	_expect(_press(scene, "К прилавку"), "Return to the counter")
	await scene.transition.finished
	await create_timer(1.10).timeout
	_click(scene.desk_board, INITIAL_OFFER)
	var clock_angle := item_view.dial_angle
	await create_timer(0.56).timeout
	_expect(item_view.item_id == "clock" and item_view.dial_angle < clock_angle, "The clock's hand visibly runs backwards")
	_expect(_press(scene, "К прилавку"), "Return from the clock inspection")
	_expect(_press(scene, "Отпустить") and _press(scene, "Отпустить"), "Pass on the second day's offers")
	_expect(_press(scene, "Завершить день"), "Reach the compass")
	await scene.transition.finished
	await create_timer(1.10).timeout
	_click(scene.desk_board, INITIAL_OFFER)
	var before_angle := item_view.dial_angle
	item_view.rotation_angle = 0.45
	item_view._update_dial()
	_expect(is_equal_approx(item_view.dial_angle + item_view.rotation_angle, before_angle),
		"The compass needle stays pointed in the same direction when rotated")
	_expect(_open_toolbox(scene), "Open the toolbox for the compass")
	await process_frame
	await _drag_at(scene.documents_board, 8, item_view, _sprite_point(item_view, Vector2(0.49, 0.57)))
	_expect(_press(scene, "Бланк"), "Open the form for the compass")
	scene.rule_boxes["bearing"].button_pressed = true
	scene.rule_boxes["light_compass"].button_pressed = true
	_expect(_press(scene, "Рассчитать") and scene.offer_form.amount == 138 and _press(scene, "Передать бланк"), "Buy the compass")
	_expect(_press(scene, "Кладовая"), "Open the transfer view")
	await scene.transition.finished
	await process_frame
	_click(scene.stock_board, 0)
	_expect(_press(scene, "Вернуть Тане"), "Return the compass from storage")
	_expect(_press(scene, "Завершить день"), "Continue after returning the compass")
	await scene.transition.finished
	_expect(scene.state.day == 4 and not scene.state.ended, "The week continues after the compass visit")
	await create_timer(1.10).timeout
	_click(scene.desk_board, scene.state.offered_slot)
	var workshop_angle := item_view.dial_angle
	await create_timer(0.56).timeout
	_expect(item_view.item_id == "workshop_clock" and item_view.dial_angle > workshop_angle, "The workshop clock runs forwards")
	_expect(_press(scene, "К прилавку"), "Return to the counter on day four")
	for day in range(4, GameState.LAST_DAY + 1):
		_expect(scene.state.day == day and scene.item_view.calendar_day == 24 + day, "The calendar matches every day of the week")
		for visit in ItemCatalog.DEALS[day - 1]:
			_expect(scene.state.active_deal() == visit and _press(scene, "Отпустить"), "Each new visit reaches the counter")
		_expect(_press(scene, "Завершить день"), "Finish day %d" % day)
		await scene.transition.finished
	_expect(scene.state.ended and scene.end_text.text.contains("вместе"), "The seventh night opens the matching epilogue")
	_expect(scene.end_panel.visible and not scene.status_label.visible and not scene.hud_row.visible
		and scene.end_report.text == "\n".join(scene.state.night_report), "The epilogue shows the report only inside its card")
	var saved_week := GameSave.new(save.base_path).load_progress()
	_expect(saved_week != null and saved_week.ended and saved_week.compass_returned, "Resuming the finished week preserves the epilogue")
	_expect(_press(scene, "Начать заново") and scene.state.money == 300, "Restart recreates both grids")
	_expect(scene.hud_row.visible and scene.status_label.visible and not scene.end_panel.visible, "A new week restores the counter HUD")
	_remove_test_saves(save)
	scene.queue_free()
	await process_frame


func _click(board: InventoryBoard, cell: int) -> void:
	var position := board.get_global_rect().position + board.cell_center(cell)
	_mouse_button(position, true)
	_mouse_button(position, false)


func _test_save_path(purpose: String) -> String:
	return OS.get_environment("TEMP").path_join("kulturny-test-%d-%s" % [OS.get_process_id(), purpose])


func _remove_test_saves(save: GameSave) -> void:
	for slot in 2:
		if FileAccess.file_exists(save.slot_path(slot)):
			DirAccess.remove_absolute(save.slot_path(slot))


func _open_toolbox(scene: Control) -> bool:
	var box: Rect2 = scene.folder_hotspot.get_global_rect()
	var point := box.position + box.size * Vector2(0.58, 0.66)
	_mouse_button(point, true)
	_mouse_button(point, false)
	return scene.documents_panel.visible


func _drag_offer(scene: Control) -> void:
	var start: Vector2 = scene.send_form.get_global_rect().get_center()
	var finish: Vector2 = scene.form_handoff.get_global_rect().get_center()
	_mouse_button(start, true)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = start + (finish - start).normalized() * 22
	motion.global_position = motion.position
	motion.relative = motion.position - start
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	await process_frame
	motion.relative = finish - motion.position
	motion.position = finish
	motion.global_position = finish
	root.push_input(motion, true)
	await process_frame
	var payload: Variant = root.gui_get_drag_data()
	_expect(scene.form_handoff._can_drop_data(Vector2.ZERO, payload), "The filled paper can be carried to the handoff")
	_expect(payload is Dictionary and payload["amount"] == 122 and payload["marked_rules"] == ["kluchi", "late_lid", "heat"],
		"The submitted form carries the assigned amount and every manually marked observation")
	_mouse_button(finish, false)
	if DisplayServer.get_name() == "headless" and scene.form_handoff._can_drop_data(Vector2.ZERO, payload):
		scene.form_handoff._drop_data(Vector2.ZERO, payload)
	await process_frame


func _hover(board: InventoryBoard, cell: int) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = board.get_global_rect().position + board.cell_center(cell)
	motion.global_position = motion.position
	root.push_input(motion, true)


func _drag(from: InventoryBoard, from_cell: int, to: InventoryBoard, to_cell: int) -> void:
	await _drag_at(from, from_cell, to, to.cell_center(to_cell))


func _sprite_point(view: ItemView, uv: Vector2) -> Vector2:
	var bounds := view._art_bounds(ItemView.stock_art[view.item_id])
	return view._item_center() + ((bounds.position + uv * bounds.size) * view._item_zoom()).rotated(view.rotation_angle)


func _aim(view: ItemView, uv: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = view.global_position + _sprite_point(view, uv)
	motion.global_position = motion.position
	root.push_input(motion, true)


func _drag_at(from: InventoryBoard, from_cell: int, to: Control, target: Vector2) -> void:
	var start := from.get_global_rect().position + from.cell_center(from_cell)
	var finish := to.get_global_rect().position + target
	_mouse_button(start, true)
	await process_frame
	var previous := start
	for position in [start + (finish - start).normalized() * 18.0, finish]:
		var motion := InputEventMouseMotion.new()
		motion.position = position
		motion.global_position = position
		motion.relative = position - previous
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion, true)
		previous = position
		await process_frame
	_expect(root.gui_is_dragging(), "Dragging starts at the occupied %s cell %d" % [from.location, from_cell])
	_expect(from.grid_is_visible(), "An item drag reveals the source grid")
	var payload: Variant = root.gui_get_drag_data()
	if payload is Dictionary:
		var anchor: int = payload["anchor"]
		_expect(from.dragging_anchor == anchor and is_zero_approx(from.previews[anchor].modulate.a),
			"The cursor carries the only visible copy of the item")
		var preview := root.find_child("DragPreview", true, false)
		var ghost := preview.get_child(0) as ItemView if preview != null else null
		var offset := from.previews[anchor].position - from.cell_center(from_cell)
		_expect(ghost != null and ghost.position.is_equal_approx(offset),
			"The sprite stays at its original offset from the point picked up")
	_mouse_button(finish, false)
	# The headless display reports the OS pointer at (0, 0) during drop callbacks.
	if DisplayServer.get_name() == "headless" and to._can_drop_data(target, payload):
		to._drop_data(target, payload)
	if to is InventoryBoard:
		to._clear_drop()
	await process_frame
	_expect(from.dragging_anchor == -1, "The original cell clears its drag state on release")
	_expect(from.grid_is_visible() == (from.location == "documents"), "Releasing leaves only the toolbox grid visible")


func _right_click(position: Vector2) -> void:
	_mouse_button(position, true, MOUSE_BUTTON_RIGHT)
	_mouse_button(position, false, MOUSE_BUTTON_RIGHT)


func _mouse_button(position: Vector2, pressed: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button
	event.pressed = pressed
	root.push_input(event, true)


func _press(scene: Node, title: String) -> bool:
	for button: Button in scene.find_children("*", "Button", true, false):
		if button.get_meta("action_label", button.text) == title and button.is_visible_in_tree() and not button.disabled:
			button.pressed.emit()
			return true
	return false


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)
