extends Control
class_name OpeningScreen

signal play_requested(new_game: bool)

enum Stage { SPLASH, MENU, CONFIRM, STORY }

const INK := Color("f5dfb4")
const FADED := Color("bcc9b7")
const GOLD := Color("dbb47c")
const COVER := "opening/cover"
const PAGES := [
	{
		"image": "opening/excavation", "place": "Пихтовая аномалия · 2391 год", "title": "Компас в земле",
		"text": "Ярослав Тальник расчищает раскоп. Газета 1983 года лежит под бронзовым ножом, а под ней — пластик из XXII века. Стрелка компаса с меткой Н. Г. указывает вглубь аномалии.",
	},
	{
		"image": "opening/basement", "place": "Подвал НИЛ-9 · 2391 год", "title": "Квадрат В-2",
		"text": "В подвале Ярослав находит останки в куртке, похожей на его собственную. В глубине стоит странный прибор. Стоит коснуться корпуса, как лампа гаснет.",
	},
	{
		"image": "opening/arrival", "place": "Пихтовый · 20 июля 1983 года", "title": "Дорога из леса",
		"text": "Гаревики находят Ярослава на выжженной опушке. В Пихтовом ему показывают свежую газету за июль 1983 года. Над лесом горит красный огонь Мачты.",
	},
	{
		"image": "counter-background-toolbox", "place": "Лесная улица · 25 июля 1983 года", "title": "Первый рабочий день",
		"text": "Через пять дней Ярослав открывает приёмку с чужим паспортом и долгом за него. Гаревики несут находки с полигона. Среди них он надеется найти след прибора. В дверь стучат.",
	},
]

var stage := Stage.SPLASH
var page := 0
var has_save := false
var replay := false
var fade: Tween

var backdrop: TextureRect
var shade: TextureRect
var veil: ColorRect
var splash: Label
var menu: VBoxContainer
var confirmation: PanelContainer
var story: VBoxContainer
var primary: Button
var new_game_button: Button
var prologue_button: Button
var save_summary: Label
var story_place: Label
var story_title: Label
var story_text: Label
var previous: Button
var skip: Button
var advance_hint: Label
var menu_shade: GradientTexture2D
var story_shade: GradientTexture2D


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	z_index = 50
	backdrop = TextureRect.new()
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.texture_filter = TEXTURE_FILTER_NEAREST
	backdrop.mouse_filter = MOUSE_FILTER_IGNORE
	_place(backdrop, Rect2(0, 0, 1, 1))
	shade = TextureRect.new()
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	_place(shade, Rect2(0, 0, 1, 1))
	menu_shade = _shade(Vector2.RIGHT, [Color("0f1613f6"), Color("101813cb"), Color("0e15113b"), Color("0e151110")])
	story_shade = _shade(Vector2.DOWN, [Color("0b100c00"), Color("0a130f13"), Color("0c1411c7"), Color("0b120ffa")])
	_build_menu()
	_build_story()
	_build_confirmation()
	splash = _label("Культурный слой", 50, INK)
	splash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	splash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	splash.add_theme_color_override("font_shadow_color", Color("10140e"))
	splash.add_theme_constant_override("shadow_offset_y", 3)
	_place(splash, Rect2(0.10, 0.34, 0.80, 0.29))
	veil = ColorRect.new()
	veil.color = Color("111914")
	veil.mouse_filter = MOUSE_FILTER_IGNORE
	_place(veil, Rect2(0, 0, 1, 1))


func present(saved: GameState, unreadable := false) -> void:
	has_save = saved != null
	if has_save:
		save_summary.text = "Неделя завершена" if saved.ended else "День %d · %s" % [saved.day, saved.calendar_date()]
	elif unreadable:
		save_summary.text = "Сохранение не удалось прочитать."
	else:
		save_summary.text = ""
	primary.text = "Продолжить" if has_save else "Начать игру"
	new_game_button.visible = has_save
	prologue_button.visible = has_save
	save_summary.visible = not save_summary.text.is_empty()
	_set_stage(Stage.SPLASH)
	_show_art(COVER, story_shade)
	_fade_in(1.0, 0.46)
	fade.tween_interval(0.95)
	fade.tween_callback(_show_menu)


func _build_menu() -> void:
	menu = VBoxContainer.new()
	menu.mouse_filter = MOUSE_FILTER_IGNORE
	menu.add_theme_constant_override("separation", 10)
	_place(menu, Rect2(0.077, 0.188, 0.395, 0.0))
	var title := _label("Культурный\nслой", 60, INK)
	title.add_theme_constant_override("line_spacing", -10)
	menu.add_child(title)
	menu.add_child(_label("Пихтовый, июль 1983 года", 18, GOLD))
	var buttons := VBoxContainer.new()
	buttons.custom_minimum_size.x = 222
	buttons.size_flags_horizontal = SIZE_SHRINK_BEGIN
	buttons.add_theme_constant_override("separation", 6)
	menu.add_child(buttons)
	save_summary = _label("", 15, FADED, true)
	buttons.add_child(save_summary)
	primary = _button(buttons, "Начать игру", _primary_action, true)
	new_game_button = _button(buttons, "Новая игра", _confirm_new_game)
	prologue_button = _button(buttons, "Пролог", _start_story.bind(true))
	_button(buttons, "Выход", func(): get_tree().quit())


func _build_story() -> void:
	story = VBoxContainer.new()
	story.grow_vertical = GROW_DIRECTION_BEGIN
	story.mouse_filter = MOUSE_FILTER_IGNORE
	story.add_theme_constant_override("separation", 5)
	_place(story, Rect2(0.068, 0.952, 0.631, 0.0))
	var rule := ColorRect.new()
	rule.color = GOLD
	rule.custom_minimum_size = Vector2(57, 2)
	rule.size_flags_horizontal = SIZE_SHRINK_BEGIN
	rule.mouse_filter = MOUSE_FILTER_IGNORE
	story.add_child(rule)
	story_place = _caption(16, GOLD)
	story.add_child(story_place)
	story_title = _caption(35, INK)
	story.add_child(story_title)
	story_text = _caption(19, INK, true)
	story_text.add_theme_constant_override("line_spacing", 2)
	story.add_child(story_text)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	story.add_child(actions)
	previous = _button(actions, "К меню", _back_page)
	previous.flat = true
	previous.custom_minimum_size.x = 76
	skip = _button(actions, "Пропустить", func(): _play(true))
	skip.flat = true
	skip.custom_minimum_size.x = 105
	actions.add_spacer(false)
	advance_hint = _caption(16, GOLD)
	advance_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	actions.add_child(advance_hint)


func _build_confirmation() -> void:
	confirmation = PanelContainer.new()
	confirmation.add_theme_stylebox_override("panel", _box(Color("242d26"), Color("ad8c55"), 18))
	_place(confirmation, Rect2(0.245, 0.35, 0.51, 0.26))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	confirmation.add_child(content)
	content.add_child(_label("Начать новую игру?", 26, INK))
	var warning := _label("Когда начнётся первый день, новая игра заменит текущее автосохранение.", 17, FADED, true)
	warning.size_flags_vertical = SIZE_EXPAND_FILL
	content.add_child(warning)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 9)
	content.add_child(actions)
	_button(actions, "Отмена", _show_menu)
	actions.add_spacer(false)
	_button(actions, "Начать заново", _start_story.bind(false), true)


func _primary_action() -> void:
	if has_save:
		_play(false)
	else:
		_start_story(false)


func _show_menu() -> void:
	var from_splash := stage == Stage.SPLASH
	_set_stage(Stage.MENU)
	_show_art(COVER, menu_shade)
	if not from_splash:
		_fade_in(0.50, 0.25)
	else:
		_fade_in(0.20, 0.22)


func _confirm_new_game() -> void:
	_set_stage(Stage.CONFIRM)


func _start_story(is_replay: bool) -> void:
	replay = is_replay
	page = 0
	_set_stage(Stage.STORY)
	_show_page()


func _show_page() -> void:
	var entry: Dictionary = PAGES[page]
	_show_art(entry["image"], story_shade)
	story_place.text = entry["place"]
	story_title.text = entry["title"]
	story_text.text = entry["text"]
	previous.text = "К меню" if page == 0 else "Назад"
	skip.visible = not replay
	if page + 1 == PAGES.size():
		advance_hint.text = "ПКМ  ·  К меню" if replay else "ПКМ  ·  За прилавок"
	else:
		advance_hint.text = "ПКМ  ·  Следующий кадр"
	_fade_in(0.63, 0.30)


func _advance() -> void:
	if page + 1 < PAGES.size():
		page += 1
		_show_page()
	elif replay:
		_show_menu()
	else:
		_play(true)


func _back_page() -> void:
	if page == 0:
		_show_menu()
	else:
		page -= 1
		_show_page()


func _play(new_game: bool) -> void:
	if fade:
		fade.kill()
	hide()
	play_requested.emit(new_game)


func _set_stage(value: Stage) -> void:
	stage = value
	splash.visible = value == Stage.SPLASH
	menu.visible = value == Stage.MENU
	confirmation.visible = value == Stage.CONFIRM
	story.visible = value == Stage.STORY


func _show_art(id: String, lighting: GradientTexture2D) -> void:
	var limit := Vector2i(900, 540) if id.begins_with("opening/") else Vector2i(640, 428)
	backdrop.texture = PixelArt.load_asset(id, limit)
	shade.texture = lighting


func _fade_in(alpha: float, seconds: float) -> void:
	if fade:
		fade.kill()
	veil.modulate.a = alpha
	fade = create_tween()
	fade.tween_property(veil, "modulate:a", 0.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _gui_input(event: InputEvent) -> void:
	if stage == Stage.SPLASH and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_show_menu()
		accept_event()


func _input(event: InputEvent) -> void:
	if visible and stage == Stage.STORY and event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		get_viewport().set_input_as_handled()
		_advance()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if stage == Stage.SPLASH and event.keycode in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE]:
		_show_menu()
	elif stage == Stage.STORY and event.keycode in [KEY_RIGHT, KEY_ENTER]:
		_advance()
	elif stage == Stage.STORY and event.keycode == KEY_LEFT and page > 0:
		_back_page()
	elif stage in [Stage.STORY, Stage.CONFIRM] and event.keycode == KEY_ESCAPE:
		_show_menu()
	else:
		return
	get_viewport().set_input_as_handled()


func _button(parent: Control, title: String, action: Callable, highlighted := false) -> Button:
	var button := Button.new()
	button.text = title
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(113, 38)
	button.add_theme_stylebox_override("normal", _box(Color("746245") if highlighted else Color("292f28"), Color("ac8c58") if highlighted else Color("67624b"), 5))
	button.add_theme_stylebox_override("hover", _box(Color("86704d") if highlighted else Color("46513b"), Color("d2ae72"), 5))
	button.add_theme_stylebox_override("pressed", _box(Color("5c543a"), Color("c19460"), 5))
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _label(text: String, font_size: int, ink: Color, wrap := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ink)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _caption(font_size: int, ink: Color, wrap := false) -> Label:
	var label := _label("", font_size, ink, wrap)
	label.add_theme_color_override("font_shadow_color", Color("080e0bdd"))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _place(control: Control, bounds: Rect2) -> void:
	add_child(control)
	control.anchor_left = bounds.position.x
	control.anchor_top = bounds.position.y
	control.anchor_right = bounds.end.x
	control.anchor_bottom = bounds.end.y
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func _box(fill: Color, border: Color, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_content_margin_all(margin)
	return style


func _shade(axis: Vector2, colors: PackedColorArray) -> GradientTexture2D:
	var tint := Gradient.new()
	tint.offsets = PackedFloat32Array([0.0, 0.38, 0.72, 1.0])
	tint.colors = colors
	var texture := GradientTexture2D.new()
	texture.gradient = tint
	texture.fill_to = axis
	return texture
