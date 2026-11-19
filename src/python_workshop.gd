extends Control

signal return_to_menu

const Course = preload("res://src/python_course.gd")
const Runner = preload("res://src/python_runner.gd")
const Style = preload("res://src/workshop_style.gd")
const Crate = preload("res://src/shipment_crate.gd")
const SAVE := "user://python_workshop.cfg"
const STATION_ORDER_VERSION := 2
const HOPPER := Vector2(591, 314)
const BELT := Vector2(659, 391)
const CART := Vector2(1247, 381)

var stage := 0
var completed := {}
var drafts := {}
var worker: Thread
var floor: TextureRect
var freight: Control
var editor: CodeEdit
var output: TextEdit
var station: Label
var title: Label
var goal: Label
var sample: Label
var hint: Label
var status: Label
var tally: Label
var cargo: Label
var info: Panel
var code_panel: Panel
var home_button: Button
var check_button: Button
var next_button: Button
var fold_button: Button
var step_button: Button
var ship_button: Button
var hint_page := -1
var save_timer: Timer
var parcels: Array = []
var loaded := 0
var loading := false
var active_crates: Array[Control] = []
var code_folded := false

func _ready() -> void:
	theme = Style.make()
	_load()
	_create_yard()
	_refresh()
	set_process(false)

func _create_yard() -> void:
	floor = TextureRect.new()
	floor.texture = load("res://assets/shipping-yard.webp")
	floor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	floor.stretch_mode = TextureRect.STRETCH_SCALE
	floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(floor, Rect2(0, 0, 1440, 810))
	freight = Control.new()
	freight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(freight, Rect2(0, 0, 1440, 810))

	var heading := Panel.new()
	_place(heading, Rect2(22, 17, 1396, 63))
	_label(str(ProjectSettings.get_setting("application/config/name")), Rect2(17, 8, 245, 45), 23, heading)
	_label("Python · 发货车间", Rect2(271, 10, 290, 42), 22, heading)
	home_button = _button("返回选路", Rect2(1248, 11, 130, 40), _go_home, heading)

	var order := Panel.new()
	_place(order, Rect2(568, 103, 511, 95))
	station = _label("", Rect2(18, 7, 450, 39), 22, order)
	tally = _label("", Rect2(18, 49, 459, 32), 17, order)

	code_panel = Panel.new()
	_place(code_panel, Rect2(22, 106, 512, 527))
	title = _label("", Rect2(15, 7, 423, 35), 18, code_panel)
	fold_button = _button("−", Rect2(458, 8, 40, 33), _fold_editor, code_panel)
	fold_button.tooltip_text = "展开或收起代码"
	_create_editor()

	var controls := Panel.new()
	_place(controls, Rect2(568, 585, 850, 203))
	status = _label("", Rect2(21, 14, 799, 40), 20, controls)
	cargo = _label("", Rect2(21, 66, 799, 48), 17, controls)
	check_button = _button("运行脚本", Rect2(21, 139, 147, 42), _check, controls)
	step_button = _button("装一箱", Rect2(179, 139, 113, 42), _start_loading.bind(false), controls)
	ship_button = _button("开始装车", Rect2(303, 139, 146, 42), _start_loading.bind(true), controls)
	_button("i  订单与提示", Rect2(460, 139, 157, 42), _toggle_inspection, controls)
	next_button = _button("下一站 →", Rect2(666, 139, 161, 42), _advance, controls)
	_create_inspection()

	save_timer = Timer.new()
	save_timer.one_shot = true
	save_timer.wait_time = 0.25
	save_timer.timeout.connect(_save)
	add_child(save_timer)

func _create_editor() -> void:
	editor = CodeEdit.new()
	editor.gutters_draw_line_numbers = true
	editor.indent_size = 4
	editor.indent_use_spaces = true
	editor.indent_automatic = true
	editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	editor.add_theme_color_override("font_color", Color("#35251a"))
	editor.add_theme_color_override("caret_color", Color("#35251a"))
	editor.add_theme_color_override("line_number_color", Color("#725440"))
	editor.add_theme_color_override("current_line_color", Color("#e7c18f"))
	editor.add_theme_stylebox_override("normal", Style.box(Color("#f8e1b6"), Color("#a9773d"), 7, 13))
	editor.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, Color("#d0a456"), 7, 13))
	var code_font := SystemFont.new()
	code_font.font_names = ["Consolas", "DejaVu Sans Mono"]
	code_font.fallbacks = [theme.default_font]
	editor.add_theme_font_override("font", code_font)
	editor.add_theme_font_size_override("font_size", 15)
	var code_colors := CodeHighlighter.new()
	for word in ["def", "class", "import", "from", "as", "with", "for", "in", "if", "return", "pass"]:
		code_colors.add_keyword_color(word, Color("#733984"))
	code_colors.add_color_region("#", "", Color("#61694b"), true)
	code_colors.add_color_region('"', '"', Color("#265943"))
	editor.syntax_highlighter = code_colors
	_place(editor, Rect2(12, 51, 488, 459), code_panel)
	editor.text_changed.connect(_edited)

func _create_inspection() -> void:
	info = Panel.new()
	_place(info, Rect2(568, 103, 827, 453))
	_label("装车订单", Rect2(19, 9, 735, 36), 23, info)
	_button("×", Rect2(770, 12, 36, 32), _toggle_inspection, info)
	goal = _label("", Rect2(20, 53, 793, 76), 17, info)
	sample = _label("", Rect2(20, 123, 372, 188), 15, info)
	_label("运行详情", Rect2(419, 126, 377, 30), 17, info)
	output = TextEdit.new()
	output.editable = false
	output.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	output.add_theme_font_size_override("font_size", 15)
	output.add_theme_color_override("font_readonly_color", Color("#efd2a7"))
	_place(output, Rect2(419, 163, 381, 185), info)
	hint = _label("", Rect2(20, 358, 623, 80), 16, info)
	_button("下一条提示", Rect2(664, 377, 137, 40), _show_hint, info)
	info.hide()

func _place(node: Control, bounds: Rect2, parent: Control = self) -> void:
	parent.add_child(node)
	node.position = bounds.position
	node.size = bounds.size

func _label(caption: String, bounds: Rect2, pixels: int, parent: Control) -> Label:
	var node := Label.new()
	node.text = caption
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", pixels)
	_place(node, bounds, parent)
	return node

func _button(caption: String, bounds: Rect2, action: Callable, parent: Control) -> Button:
	var node := Button.new()
	node.text = caption
	node.pressed.connect(action)
	_place(node, bounds, parent)
	return node

func _refresh() -> void:
	var lesson: Dictionary = Course.LESSONS[stage]
	station.text = "%d/%d  ·  %s" % [stage + 1, Course.LESSONS.size(), lesson.title]
	title.text = lesson.file
	goal.text = lesson.goal
	sample.text = lesson.sample
	editor.text = drafts.get(stage, lesson.starter)
	output.text = "运行脚本后，这里会显示两组验收和清单预览。"
	hint_page = -1
	hint.text = ""
	status.text = "脚本通过验收后，把零件箱装进货车。"
	cargo.text = lesson.first_action if not completed.has(stage) else "打开 i 看订单，或修改脚本后运行。"
	_clear_freight()
	_update_controls()
	_show_editor()

func _clear_freight() -> void:
	for crate in active_crates:
		crate.queue_free()
	active_crates.clear()
	parcels.clear()
	loaded = 0

func _edited() -> void:
	drafts[stage] = editor.text
	save_timer.start()
	if not parcels.is_empty():
		_clear_freight()
		status.text = "脚本已改变，重新运行以备货。"
		cargo.text = ""
		_update_controls()

func _fold_editor() -> void:
	code_folded = not code_folded
	_show_editor()
	if not code_folded:
		editor.grab_focus()
	_save()

func _show_editor() -> void:
	editor.visible = not code_folded
	code_panel.size.y = 49.0 if code_folded else 527.0
	fold_button.text = "+" if code_folded else "−"

func _toggle_inspection() -> void:
	info.visible = not info.visible
	if info.visible and hint_page < 0:
		_show_hint()

func _show_hint() -> void:
	var hints: Array = Course.LESSONS[stage].hints
	hint_page = (hint_page + 1) % hints.size()
	hint.text = "提示 %d/%d  ·  %s" % [hint_page + 1, hints.size(), hints[hint_page]]

func _update_controls() -> void:
	var busy := worker != null or loading
	var can_load := not busy and loaded < parcels.size()
	check_button.disabled = busy
	home_button.disabled = busy
	editor.editable = not busy
	ship_button.disabled = not can_load
	step_button.disabled = not can_load
	next_button.disabled = busy or not completed.has(stage)
	next_button.text = "收工" if stage + 1 == Course.LESSONS.size() else "下一站 →"
	tally.text = "已装车  %d / %d" % [loaded, parcels.size()] if not parcels.is_empty() else "等候脚本备货"

func _advance() -> void:
	if not completed.has(stage):
		return
	if stage + 1 == Course.LESSONS.size():
		_go_home()
		return
	drafts[stage] = editor.text
	stage += 1
	info.hide()
	_refresh()
	_save()

func _check() -> void:
	if worker != null or loading:
		return
	_clear_freight()
	drafts[stage] = editor.text
	_save()
	var pending := Thread.new()
	if pending.start(Runner.check.bind(editor.text, Course.LESSONS[stage])) != OK:
		status.text = "无法启动脚本检查。"
		return
	worker = pending
	status.text = "备货中… 正在核对两批数据。"
	cargo.text = ""
	info.hide()
	_update_controls()
	set_process(true)

func _process(_delta: float) -> void:
	if worker.is_alive():
		return
	var result: Dictionary = worker.wait_to_finish()
	worker = null
	set_process(false)
	output.text = result.output.strip_edges()
	if result.ok:
		parcels = result.boxes
		status.text = "清单通过。货箱已进站，开始装车。"
		cargo.text = "下一箱 · " + _manifest(parcels[0])
	else:
		status.text = "验收未过，货箱留在货架上。"
		cargo.text = "打开「订单与提示」查看脚本运行详情。"
		if stage < Course.BASIC_STATION_COUNT and not info.visible:
			_toggle_inspection()
	_update_controls()

func _manifest(parcel: Dictionary) -> String:
	return "%s  ·  %s  ·  %s" % [parcel.item_id, parcel.name, parcel.price]

func _start_loading(all: bool) -> void:
	if worker != null or loading or loaded >= parcels.size():
		return
	info.hide()
	loading = true
	status.text = "输送带运转中…"
	_update_controls()
	var count := parcels.size() - loaded if all else 1
	for index in count:
		await _move_crate(parcels[loaded])
		loaded += 1
		_update_controls()
	loading = false
	if loaded == parcels.size():
		completed[stage] = true
		status.text = "货物全部装车。这一站通过。"
		cargo.text = "最后一箱 · " + _manifest(parcels[-1])
		_save()
	else:
		status.text = "装好一箱。可以继续单步，或一次装完。"
		cargo.text = "下一箱 · " + _manifest(parcels[loaded])
	_update_controls()

func _move_crate(parcel: Dictionary) -> void:
	var crate: Control = Crate.new()
	crate.item_id = parcel.item_id
	freight.add_child(crate)
	crate.position = HOPPER
	active_crates.append(crate)
	cargo.text = "装车中 · " + _manifest(parcel)
	var path := create_tween()
	path.tween_property(crate, "position", BELT, 0.23).set_ease(Tween.EASE_OUT)
	path.tween_property(crate, "position", Vector2(1180, 391), 0.85)
	path.tween_property(crate, "position", CART + Vector2(68 * loaded, -5 * loaded), 0.21)
	await path.finished

func _go_home() -> void:
	if worker != null or loading:
		return
	drafts[stage] = editor.text
	_save()
	return_to_menu.emit()

func _load() -> void:
	var file := ConfigFile.new()
	if file.load(SAVE) == OK:
		stage = file.get_value("project", "stage", 0)
		completed = file.get_value("project", "completed", {})
		drafts = file.get_value("project", "drafts", {})
		code_folded = file.get_value("project", "code_folded", false)
		if file.get_value("project", "station_order_version", 1) < STATION_ORDER_VERSION:
			completed = _shift_legacy_stations(completed)
			drafts = _shift_legacy_stations(drafts)
			if not completed.is_empty() or stage > 0:
				stage += Course.BASIC_STATION_COUNT
		stage = clampi(stage, 0, Course.LESSONS.size() - 1)

func _shift_legacy_stations(previous: Dictionary) -> Dictionary:
	var shifted := {}
	for index in previous:
		shifted[int(index) + Course.BASIC_STATION_COUNT] = previous[index]
	return shifted

func _save() -> void:
	var file := ConfigFile.new()
	file.set_value("project", "station_order_version", STATION_ORDER_VERSION)
	file.set_value("project", "stage", stage)
	file.set_value("project", "completed", completed)
	file.set_value("project", "drafts", drafts)
	file.set_value("project", "code_folded", code_folded)
	var pending := SAVE + ".tmp"
	if file.save(pending) != OK or DirAccess.rename_absolute(pending, SAVE) != OK:
		status.text = "本地存档失败，请检查写入权限。"

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(editor):
		drafts[stage] = editor.text
		_save()
	if what == NOTIFICATION_PREDELETE and worker != null and worker.is_started():
		worker.wait_to_finish()
