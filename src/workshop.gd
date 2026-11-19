extends Control

signal return_to_menu

const Style = preload("res://src/workshop_style.gd")
const Course = preload("res://src/course.gd")
const LeanBasics = preload("res://src/lean_basics.gd")
const Checker = preload("res://src/lean_checker.gd")
const Arm = preload("res://src/arm.gd")
const SAVE := "user://workshop.cfg"
const LESSONS := LeanBasics.LESSONS + Course.LESSONS
const PAPER := Color("#f8e1b6")
const INK := Color("#342015")
const GOLD := Color("#eac084")

var arm: Control
var stage := 0
var intro_count := LeanBasics.LESSONS.size()
var intro_reached := 0
var legacy_math_access := false
var drafts := {}
var archives := {}
var closed := {}
var file_positions := {}
var carets := {}
var editors := {}
var windows := {}
var active_skill := 0
var hint_index := 0
var showing_diagram := false
var worker: Thread
var save_timer: Timer
var file_stack: HBoxContainer
var editor_layer: Control
var resource_label: Label
var device_title: Label
var device_output: Label
var slot_one: Label
var slot_two: Label
var rewrite_slots: Array[Button] = []
var screen_status: Label
var screen_goal: Label
var shelf: Array[Label] = []
var overlay: Panel
var modal_input_shield: ColorRect
var return_button: Button
var run_button: Button
var advance_button: Button
var current_file := ""

func _ready() -> void:
	_load()
	theme = Style.make()
	_create_shell()
	_refresh()
	if stage < intro_count and stage == intro_reached:
		_open_hints()
	set_process(false)

func _place(node: Control, bounds: Rect2, parent: Control = self) -> void:
	parent.add_child(node)
	node.position = bounds.position
	node.size = bounds.size

func _text(value: String, bounds: Rect2, pixels: int, color: Color = GOLD,
		parent: Control = self, wrap: bool = false) -> Label:
	var label := Label.new()
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(label, bounds, parent)
	label.text = value
	return label

func _button(value: String, bounds: Rect2, action: Callable, parent: Control = self) -> Button:
	var button := Button.new()
	button.text = value
	button.pressed.connect(action)
	_place(button, bounds, parent)
	return button

func _create_shell() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/workshop.webp")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(bg, Rect2(0, 0, 1440, 810))

	var header := Panel.new()
	_place(header, Rect2(18, 12, 1404, 62))
	_text("farmer · Math", Rect2(20, 6, 203, 48), 25, GOLD, header)
	return_button = _button("返回选路", Rect2(1107, 10, 122, 42), _go_to_menu, header)
	var resources := _button("", Rect2(225, 10, 493, 42), _open_catalog, header)
	resources.tooltip_text = "查看已归档的知识"
	resource_label = _text("", Rect2(12, 7, 468, 27), 17, GOLD, resources)
	var new_file := _button("+", Rect2(1246, 10, 42, 42), _new_file, header)
	new_file.tooltip_text = "新建 Lean 文件"
	var info := _button("i", Rect2(1295, 10, 42, 42), _open_hints, header)
	info.tooltip_text = "当前目标的提示"
	var tree := _button("⌃", Rect2(1344, 10, 42, 42), _open_tree, header)
	tree.tooltip_text = "展开或折叠知识树"

	for index in 3:
		var label := _text("", Rect2(849, 124 + 53 * index, 198, 25), 16, INK)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shelf.append(label)
	device_title = _text("", Rect2(658, 290, 156, 26), 20, INK)
	device_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_one = _text("", Rect2(658, 363, 150, 24), 16, INK)
	slot_one.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_two = _text("", Rect2(662, 437, 150, 24), 16, INK)
	slot_two.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for index in 2:
		var slot := _button("", Rect2(648, 354 + 74 * index, 173, 42), _locate_rewrite.bind(index))
		slot.flat = true
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot.tooltip_text = "定位到检查此项的 Lean 改写"
		rewrite_slots.append(slot)
	device_output = _text("", Rect2(692, 517, 391, 103), 24, INK)
	device_output.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	device_output.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	device_output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	arm = Arm.new()
	_place(arm, Rect2(0, 0, 1440, 810))

	var footer := Panel.new()
	_place(footer, Rect2(18, 690, 560, 102))
	screen_status = _text("", Rect2(14, 9, 531, 36), 15, GOLD, footer)
	screen_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	run_button = _button("检查 Lean", Rect2(14, 53, 147, 34), _run_current, footer)
	_button("查看诊断", Rect2(169, 53, 143, 34), _open_diagnostics, footer)
	advance_button = _button("下一关 →", Rect2(387, 53, 157, 34), _advance, footer)
	screen_goal = _text("", Rect2(29, 96, 520, 52), 23)
	screen_goal.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	editor_layer = Control.new()
	editor_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(editor_layer, Rect2(0, 0, 1440, 810))
	var file_rail := ScrollContainer.new()
	file_rail.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	file_rail.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_place(file_rail, Rect2(27, 148, 554, 53), editor_layer)
	file_stack = HBoxContainer.new()
	file_stack.add_theme_constant_override("separation", 5)
	file_rail.add_child(file_stack)
	save_timer = Timer.new()
	save_timer.one_shot = true
	save_timer.wait_time = 0.25
	save_timer.timeout.connect(_save)
	add_child(save_timer)

func _refresh() -> void:
	var lesson: Dictionary = LESSONS[stage]
	var file: String = lesson.file
	if not drafts.has(file):
		drafts[file] = lesson.starter
	if current_file.is_empty():
		current_file = file
	screen_goal.text = ("Lean %02d / %02d · %s" % [stage + 1, intro_count, lesson.title]
		if stage < intro_count else lesson.title)
	if stage < intro_count:
		current_status("先读右侧任务，再编辑草稿并检查。按 i 可打开提示。")
	elif stage == intro_count and not archives.has(file):
		current_status("第 1 步：把第二行的 sorry 改成 rfl，再点「检查 Lean」。")
	else:
		current_status("打开任务提示 i，或编辑 %s.lean 后检查。" % file)
	_update_progress()
	_render_files()
	_prepare_machine()

func _prepare_machine() -> void:
	if stage < intro_count:
		device_title.text = "Lean 练习台"
		slot_one.text = "草稿"
		slot_two.text = "检验"
		for slot in rewrite_slots:
			slot.hide()
		_set_display(LESSONS[stage].symbol)
		return
	var index := stage - intro_count
	var lesson: Dictionary = LESSONS[stage]
	device_title.text = lesson.action
	for slot in rewrite_slots:
		slot.visible = lesson.id == "reuse"
	slot_one.text = ["左边", "奇数项", "零的情形", "oddTotal n"][index]
	slot_two.text = ["右边", "部分和", "后继的情形", "oddTotal m"][index]
	_set_display(["2 + 3   =   ?", "1 + 3 + 5 + 7", "oddTotal n = n²", "oddTotal n − oddTotal m"][index])

func _locate_rewrite(index: int) -> void:
	var filename: String = LESSONS[stage].file
	if not editors.has(filename):
		_toggle_file(filename)
	var edit: CodeEdit = editors[filename]
	edit.grab_focus()
	var token := "oddTotal_sq n" if index == 0 else "oddTotal_sq m"
	for line in edit.get_line_count():
		var column := edit.get_line(line).find(token)
		if column >= 0:
			edit.set_caret_line(line)
			edit.set_caret_column(column)
			edit.center_viewport_to_caret()
			return
	current_status("当前草稿还没有这一项的改写。打开 i 可查看提示。")

func _update_progress() -> void:
	var catalog: Array[String] = []
	for lesson in Course.LESSONS:
		if archives.has(lesson.file):
			catalog.append(lesson.symbol)
	var count := catalog.size()
	var definitions := 1 if archives.has("Accumulation") else 0
	var chapter := 1 if count == Course.LESSONS.size() else 0
	resource_label.text = ("Lean 入门  %d / %d" % [intro_reached, intro_count] if stage < intro_count else
		"定义  %d     ·     定理  %d     ·     章节印章  %d" % [definitions, count - definitions, chapter])
	for index in shelf.size():
		shelf[index].text = catalog[index] if index < catalog.size() else "—"
	advance_button.disabled = not _level_complete(stage)
	advance_button.text = "知识树 ⌃" if stage == LESSONS.size() - 1 else "下一关 →"

func _level_complete(index: int) -> bool:
	return index < intro_reached or archives.has(LESSONS[index].file)

func _level_available(index: int) -> bool:
	return (index == 0 or (index == intro_count and legacy_math_access)
		or (index > 0 and index < LESSONS.size() and _level_complete(index - 1)))

func _render_files() -> void:
	for filename in editors:
		var editor: CodeEdit = editors[filename]
		carets[filename] = Vector2i(editor.get_caret_line(), editor.get_caret_column())
	for panel in windows.values():
		panel.hide()
		panel.queue_free()
	for strip in file_stack.get_children():
		file_stack.remove_child(strip)
		strip.queue_free()
	editors.clear()
	windows.clear()
	for filename in drafts:
		if closed.get(filename, false):
			var strip := Button.new()
			strip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			strip.text = "▸   " + filename + ".lean"
			strip.pressed.connect(_toggle_file.bind(filename))
			file_stack.add_child(strip)
		else:
			_open_editor(filename)
	if windows.has(current_file):
		windows[current_file].move_to_front()

func _open_editor(filename: String) -> void:
	var sequence := windows.size()
	var bounds := Rect2(file_positions.get(filename, Vector2(27 + 22 * sequence, 211 + 24 * sequence)), Vector2(554, 448))
	var panel := Panel.new()
	_place(panel, bounds, editor_layer)
	windows[filename] = panel
	var grip := Label.new()
	grip.text = "    %s.lean" % filename
	grip.mouse_filter = Control.MOUSE_FILTER_STOP
	_place(grip, Rect2(0, 0, 456, 43), panel)
	grip.gui_input.connect(_drag.bind(filename, panel))
	_button("▶", Rect2(460, 6, 36, 31), _run_file.bind(filename), panel).tooltip_text = "检查此文件"
	_button("−", Rect2(503, 6, 39, 31), _toggle_file.bind(filename), panel).tooltip_text = "收起代码窗口"

	var edit := CodeEdit.new()
	edit.text = drafts[filename]
	edit.gutters_draw_line_numbers = true
	edit.indent_automatic = true
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.indent_use_spaces = true
	edit.indent_size = 2
	edit.add_theme_font_size_override("font_size", 17)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Cascadia Mono", "Consolas"])
	mono.fallbacks = [theme.default_font]
	edit.add_theme_font_override("font", mono)
	edit.add_theme_color_override("font_color", INK)
	edit.add_theme_color_override("caret_color", INK)
	edit.add_theme_color_override("current_line_color", Color("#ecd09f"))
	edit.add_theme_color_override("line_number_color", Color("#7b5b42"))
	edit.add_theme_color_override("selection_color", Color("#d7c8a2"))
	edit.add_theme_stylebox_override("normal", Style.box(PAPER, Color("#d09a50"), 4, 15))
	edit.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, Color("#d0a456"), 4, 15))
	var highlighting := CodeHighlighter.new()
	for word in ["import", "def", "theorem", "by", "induction", "with", "calc", "sorry", "rw", "rfl"]:
		highlighting.add_keyword_color(word, Color("#703784"))
	highlighting.number_color = Color("#25613a")
	highlighting.symbol_color = Color("#765439")
	highlighting.add_color_region("--", "", Color("#777057"), true)
	edit.syntax_highlighter = highlighting
	_place(edit, Rect2(8, 44, 538, 395), panel)
	editors[filename] = edit
	var caret: Vector2i = carets.get(filename, Vector2i.ZERO)
	edit.set_caret_line(caret.x)
	edit.set_caret_column(caret.y)
	edit.caret_changed.connect(_remember_caret.bind(filename, edit))
	edit.text_changed.connect(_edited.bind(filename, edit))
	edit.focus_entered.connect(_select_file.bind(filename, panel))

var dragged := ""
var drag_position := Vector2.ZERO

func _drag(event: InputEvent, filename: String, panel: Control) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragged = filename if event.pressed else ""
		drag_position = get_global_mouse_position() - panel.position
		_select_file(filename, panel)
	elif event is InputEventMouseMotion and dragged == filename and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		panel.position = (get_global_mouse_position() - drag_position).clamp(Vector2(10, 205), Vector2(870, 347))
		file_positions[filename] = panel.position
		save_timer.start()

func _select_file(filename: String, panel: Control) -> void:
	current_file = filename
	panel.move_to_front()

func _remember_caret(filename: String, editor: CodeEdit) -> void:
	if editors.get(filename) != editor or not save_timer.is_inside_tree():
		return
	carets[filename] = Vector2i(editor.get_caret_line(), editor.get_caret_column())
	save_timer.start()

func _edited(filename: String, editor: CodeEdit) -> void:
	drafts[filename] = editor.text
	save_timer.start()

func _toggle_file(filename: String) -> void:
	closed[filename] = not closed.get(filename, false)
	if not closed[filename]:
		current_file = filename
	elif current_file == filename:
		current_file = LESSONS[stage].file
	_render_files()
	_save()

func _new_file() -> void:
	var number := 1
	while drafts.has("Notebook%d" % number):
		number += 1
	current_file = "Notebook%d" % number
	drafts[current_file] = "-- Lean 4\n\n"
	_render_files()
	editors[current_file].grab_focus()
	_save()

func _advance() -> void:
	if worker != null or not _level_complete(stage):
		return
	if stage == LESSONS.size() - 1:
		_open_tree()
		return
	_switch_stage(stage + 1)

func _switch_stage(index: int) -> void:
	if worker != null or not _level_available(index):
		return
	if index == stage:
		_close_overlay()
		return
	_close_overlay()
	arm.halt()
	closed[LESSONS[stage].file] = true
	stage = index
	current_file = LESSONS[stage].file
	closed[current_file] = false
	hint_index = 0
	showing_diagram = false
	_refresh()
	if stage < intro_count and not _level_complete(stage):
		_open_hints()
	_save()

var last_diagnostics := "检查后，Lean 4 的诊断会出现在这里。"
var checked_file := ""
var checked_stage := -1
var checked_source := ""

func _run_current() -> void:
	_run_file(current_file)

func _run_file(filename: String) -> void:
	if worker != null or not drafts.has(filename):
		return
	checked_file = filename
	checked_stage = stage if filename == LESSONS[stage].file else -1
	var lesson: Dictionary = LESSONS[checked_stage] if checked_stage >= 0 else {}
	checked_source = String(drafts[filename])
	var executable := Checker.tool()
	worker = Thread.new()
	var modules := archives.duplicate()
	if intro_reached >= intro_count - 1:
		modules.merge(LeanBasics.MODULES)
	for draft in drafts:
		if draft.begins_with("Notebook") and draft != filename:
			modules[draft] = drafts[draft]
	if worker.start(Checker.check.bind(executable, checked_source, lesson, modules)) != OK:
		worker = null
		current_status("无法启动后台检查。")
		return
	set_process(true)
	run_button.disabled = true
	return_button.disabled = true
	current_status("Lean 正在检查 %s.lean…" % filename)

func _process(_delta: float) -> void:
	if worker.is_alive():
		return
	var result: Dictionary = worker.wait_to_finish()
	worker = null
	run_button.disabled = false
	return_button.disabled = false
	set_process(false)
	last_diagnostics = String(result.output).strip_edges()
	if last_diagnostics.is_empty():
		last_diagnostics = "Lean 检查通过。"
	if not result.ok:
		current_status("未通过 · 可查看 Lean 诊断或分级提示。")
		if checked_stage >= 0 and checked_stage < intro_count:
			_show_diagnostics()
		return
	if checked_stage < 0:
		current_status("%s.lean 检查通过。" % checked_file)
		return
	archives[checked_file] = checked_source
	if checked_stage < intro_count:
		intro_reached = maxi(intro_reached, checked_stage + 1)
	_update_progress()
	if checked_stage == stage:
		_close_overlay()
		_prepare_machine()
		arm.replay(LESSONS[stage].get("id", "training"), _set_display)
	current_status("已验证并归档 · " + LESSONS[checked_stage].symbol)
	_save()

func _go_to_menu() -> void:
	if worker == null:
		_save()
		return_to_menu.emit()

func _set_display(value: String) -> void:
	device_output.text = value

func current_status(message: String) -> void:
	screen_status.text = message

func _canvas(title: String, bounds: Rect2, modal: bool = true) -> Panel:
	_close_overlay()
	if modal:
		modal_input_shield = ColorRect.new()
		modal_input_shield.color = Color(0.05, 0.03, 0.02, 0.59)
		_place(modal_input_shield, Rect2(0, 74, 1440, 736))
	overlay = Panel.new()
	_place(overlay, bounds)
	_text(title, Rect2(25, 13, bounds.size.x - 108, 45), 28, GOLD, overlay)
	_button("×", Rect2(bounds.size.x - 58, 14, 41, 35), _close_overlay, overlay)
	return overlay

var overlay_kind := ""

func _close_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.hide()
		overlay.queue_free()
	if is_instance_valid(modal_input_shield):
		modal_input_shield.hide()
		modal_input_shield.queue_free()
	modal_input_shield = null
	overlay = null
	overlay_kind = ""

func _open_hints() -> void:
	if overlay_kind == "hints":
		_close_overlay()
		return
	_render_hints()

func _render_hints() -> void:
	if stage < intro_count:
		_render_intro_hints()
		return
	var panel := _canvas("任务与分级提示", Rect2(639, 140, 667, 526))
	overlay_kind = "hints"
	var lesson: Dictionary = LESSONS[stage]
	_text(lesson.task, Rect2(26, 70, 613, 69), 18, GOLD, panel, true)
	_text(lesson.goal, Rect2(26, 150, 613, 87), 17, Color("#f5efdc"), panel)
	_text("提示 %d   %s" % [hint_index + 1, lesson.hints[hint_index]], Rect2(26, 250, 613, 82), 16, GOLD, panel, true)
	var next := _button("下一层提示", Rect2(26, 337, 149, 38), _show_next_hint, panel)
	next.disabled = hint_index >= lesson.hints.size() - 1
	_button("图解", Rect2(187, 337, 110, 38), _toggle_diagram, panel)
	if showing_diagram:
		_text(lesson.diagram, Rect2(26, 391, 610, 105), 18, GOLD, panel)

func _render_intro_hints() -> void:
	var panel := _canvas("练习任务 · " + LESSONS[stage].symbol, Rect2(616, 135, 738, 525), false)
	overlay_kind = "hints"
	var lesson: Dictionary = LESSONS[stage]
	_text(lesson.guide, Rect2(25, 66, 686, 112), 18, GOLD, panel, true)
	_text("参考例子", Rect2(25, 184, 670, 24), 16, GOLD, panel)
	var example := TextEdit.new()
	example.editable = false
	example.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	example.text = lesson.example
	example.add_theme_color_override("font_readonly_color", Color("#efd9b3"))
	example.add_theme_font_size_override("font_size", 17)
	_place(example, Rect2(25, 216, 686, 178), panel)
	_text("" if hint_index == 0 else lesson.hints[hint_index - 1], Rect2(25, 405, 686, 56), 16, GOLD, panel, true)
	var next := _button("看一步提示", Rect2(25, 470, 147, 34), _show_next_hint, panel)
	next.disabled = hint_index == lesson.hints.size()

func _show_next_hint() -> void:
	hint_index += 1
	_render_hints()

func _toggle_diagram() -> void:
	showing_diagram = not showing_diagram
	_render_hints()

func _open_catalog() -> void:
	var panel := _canvas("工坊档案", Rect2(655, 144, 640, 489))
	overlay_kind = "catalog"
	var row := 0
	for lesson in Course.LESSONS:
		if archives.has(lesson.file):
			_text(lesson.symbol + "  ·  " + lesson.title, Rect2(26, 89 + row * 55, 570, 38), 17, GOLD, panel)
			row += 1
	if row == 0:
		_text("完成第一个 Lean 目标后，成果会归档到这里。", Rect2(26, 89, 570, 38), 17, GOLD, panel)
	_text("归档模块可以用 import 在后续 Lean 文件中调用。", Rect2(26, 367, 570, 38), 16, GOLD, panel)

func _open_diagnostics() -> void:
	if overlay_kind == "diagnostics":
		_close_overlay()
		return
	_show_diagnostics()

func _show_diagnostics() -> void:
	var intro := stage < intro_count
	var bounds := Rect2(616, 135, 738, 525) if intro else Rect2(530, 139, 806, 532)
	var panel := _canvas("Lean 4 诊断", bounds, not intro)
	overlay_kind = "diagnostics"
	var output := TextEdit.new()
	output.editable = false
	output.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	output.text = last_diagnostics
	output.add_theme_color_override("font_readonly_color", Color("#efd9b3"))
	output.add_theme_font_size_override("font_size", 16)
	_place(output, Rect2(22, 70, bounds.size.x - 44, bounds.size.y - 94), panel)

func _open_tree() -> void:
	if overlay_kind == "tree":
		_close_overlay()
		return
	active_skill = stage
	_render_tree()

func _render_tree() -> void:
	var panel := _canvas("知识树", Rect2(25, 90, 1390, 691))
	overlay_kind = "tree"
	_button("Lean 4 入门", Rect2(943, 14, 163, 37), _skill_selected.bind(0), panel)
	_button("数学章节", Rect2(1119, 14, 163, 37), _skill_selected.bind(intro_count), panel)
	if active_skill < intro_count:
		_render_intro_tree(panel)
		return
	_tree_path(panel, PackedVector2Array([Vector2(147, 150), Vector2(147, 323)]))
	_tree_path(panel, PackedVector2Array([Vector2(272, 323), Vector2(282, 323),
		Vector2(282, 150), Vector2(303, 150)]))
	for row in range(4):
		var y := 150 + row * 58
		_tree_path(panel, PackedVector2Array([Vector2(544, y), Vector2(846, y)]))
	_tree_path(panel, PackedVector2Array([Vector2(1087, 323), Vector2(1098, 323),
		Vector2(1098, 150), Vector2(1110, 150)]))
	_tree_path(panel, PackedVector2Array([Vector2(1231, 150), Vector2(1231, 267)]))
	for column in Course.ROADMAP.size():
		var branch: Array = Course.ROADMAP[column]
		var x := 22 + column * 271
		_text(branch[0], Rect2(x, 78, 255, 38), 21, GOLD, panel)
		for row in range(1, branch.size()):
			var name: String = branch[row]
			var index := intro_count + row - 1
			var tile := _button(name, Rect2(x, 126 + (row - 1) * 58, 251, 48), _skill_selected.bind(index), panel)
			if column == 0:
				if _level_complete(index):
					tile.text = "✓   " + name
				elif index == stage:
					tile.text = "◆   " + name
			else:
				tile.disabled = true
				tile.tooltip_text = "后续章节"
	var lesson: Dictionary = LESSONS[active_skill]
	_text(lesson.title + "  ·  " + lesson.skill, Rect2(25, 412, 1140, 44), 25, GOLD, panel)
	_text(lesson.task, Rect2(25, 466, 1300, 38), 18, GOLD, panel)
	var enter := _button("进入关卡", Rect2(25, 537, 175, 43), _switch_stage.bind(active_skill), panel)
	enter.disabled = not _level_available(active_skill)
	if enter.disabled:
		_text("先完成前置关卡。", Rect2(221, 545, 400, 30), 17, GOLD, panel)
	_text("终章目标：复推 11/12 与 7/8 预印本中的关键估计。", Rect2(25, 623, 1300, 35), 16, GOLD, panel)

func _render_intro_tree(panel: Panel) -> void:
	for index in intro_count:
		var x := 25 + (index % 2) * 658
		var y := 85 + floori(index / 2.0) * 65
		var mark := "✓ " if _level_complete(index) else ("◆ " if _level_available(index) else "   ")
		var caption := "%s%02d  %s" % [mark, index + 1, LESSONS[index].title]
		_button(caption, Rect2(x, y, 633, 49), _skill_selected.bind(index), panel)
	var lesson: Dictionary = LESSONS[active_skill]
	_text(lesson.title + "  ·  " + lesson.symbol, Rect2(25, 424, 1300, 42), 24, GOLD, panel)
	_text(lesson.guide, Rect2(25, 478, 1315, 68), 18, GOLD, panel, true)
	var enter := _button("进入关卡", Rect2(25, 566, 175, 43), _switch_stage.bind(active_skill), panel)
	enter.disabled = not _level_available(active_skill)
	if enter.disabled:
		_text("先完成前一关。", Rect2(221, 574, 400, 30), 17, GOLD, panel)

func _tree_path(panel: Panel, points: PackedVector2Array) -> void:
	var route := Line2D.new()
	route.points = points
	route.default_color = Color("#987039")
	route.width = 3.0
	route.antialiased = true
	panel.add_child(route)

func _skill_selected(index: int) -> void:
	active_skill = index
	_render_tree()

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE) != OK:
		_load_legacy_tutorial()
		return
	drafts = cfg.get_value("state", "drafts", {})
	archives = cfg.get_value("state", "archives", {})
	closed = cfg.get_value("state", "closed", {})
	file_positions = cfg.get_value("state", "positions", {})
	carets = cfg.get_value("state", "carets", {})
	if cfg.has_section_key("state", "intro_reached"):
		stage = clampi(int(cfg.get_value("state", "stage", 0)), 0, LESSONS.size() - 1)
		intro_reached = clampi(int(cfg.get_value("state", "intro_reached", 0)), 0, intro_count)
		legacy_math_access = bool(cfg.get_value("state", "legacy_math_access", false))
	else:
		_load_legacy_tutorial()
		stage = intro_count + clampi(int(cfg.get_value("state", "stage", 0)), 0, Course.LESSONS.size() - 1)
		legacy_math_access = true

func _load_legacy_tutorial() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://route_tutorials.cfg") != OK:
		return
	if cfg.get_value("lean_basics", "completed", false):
		stage = intro_count
		intro_reached = intro_count
		return
	stage = clampi(int(cfg.get_value("lean_basics", "step", 0)), 0, intro_count - 1)
	intro_reached = stage
	if cfg.has_section_key("lean_basics", "draft"):
		drafts[LESSONS[stage].file] = cfg.get_value("lean_basics", "draft")

func _save() -> void:
	var cfg := ConfigFile.new()
	var state := {"stage": stage, "intro_reached": intro_reached, "legacy_math_access": legacy_math_access,
		"drafts": drafts, "archives": archives, "closed": closed, "positions": file_positions, "carets": carets}
	for key in state:
		cfg.set_value("state", key, state[key])
	var temp := SAVE + ".tmp"
	if cfg.save(temp) != OK or DirAccess.rename_absolute(temp, SAVE) != OK:
		current_status("保存进度失败，请检查本地目录权限。")

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED] and is_instance_valid(save_timer):
		_save()
	if what == NOTIFICATION_PREDELETE and worker != null and worker.is_started():
		worker.wait_to_finish()
