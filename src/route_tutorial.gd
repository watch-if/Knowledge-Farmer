extends Control

signal enter_workshop
signal return_to_menu
signal lesson_advanced

const Style = preload("res://src/workshop_style.gd")
const PythonRunner = preload("res://src/python_runner.gd")
const LeanChecker = preload("res://src/lean_checker.gd")
const LeanBasics = preload("res://src/lean_basics.gd")

var route := "python"
var step := 0
var saved_draft: Variant = null
var worker: Thread
var editor: CodeEdit
var run_button: Button
var advance_button: Button
var return_button: Button
var skip_button: Button
var heading: Label
var instructions: Label
var result_view: TextEdit
var last_pass := false
var solution_hint: Label
var example_view: TextEdit
var hint_index := 0

func _ready() -> void:
	theme = Style.make()
	var math := route == "math"
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.035, 0.02, 0.84)
	_place(shade, Rect2(0, 0, 1440, 810), self)
	var panel := Panel.new()
	_place(panel, Rect2(172, 65, 1096, 680) if math else Rect2(172, 94, 1096, 622), self)
	heading = _label("", Rect2(28, 15, 1020, 50), 29, panel)
	instructions = _label("", Rect2(28, 76, 1021, 92), 20, panel)

	editor = CodeEdit.new()
	editor.text = 'print("准备装车")'
	editor.gutters_draw_line_numbers = true
	editor.indent_size = 2
	editor.indent_use_spaces = true
	editor.indent_automatic = math
	editor.add_theme_color_override("font_color", Color("#3d2817"))
	editor.add_theme_color_override("caret_color", Color("#3d2817"))
	editor.add_theme_color_override("current_line_color", Color("#e9cb96"))
	editor.add_theme_color_override("line_number_color", Color("#6a4c32"))
	editor.add_theme_font_size_override("font_size", 19 if math else 22)
	editor.add_theme_stylebox_override("normal", Style.box(Color("#f8e1b6"), Color("#b7834e"), 6, 16))
	editor.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, Color("#dfa158"), 6, 16))
	var code_font := SystemFont.new()
	code_font.font_names = ["Consolas", "DejaVu Sans Mono"]
	code_font.fallbacks = [theme.default_font]
	editor.add_theme_font_override("font", code_font)
	_place(editor, Rect2(28, 187, 608, 233) if math else Rect2(28, 178, 1040, 135), panel)
	editor.text_changed.connect(_edited)
	if math:
		editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		editor.text = LeanBasics.LESSONS[step].starter if saved_draft == null else str(saved_draft)
		_label("练习草稿", Rect2(28, 151, 608, 30), 17, panel)
		_label("参考例子", Rect2(654, 151, 414, 30), 17, panel)
		example_view = TextEdit.new()
		example_view.editable = false
		example_view.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		example_view.add_theme_font_override("font", code_font)
		example_view.add_theme_color_override("font_readonly_color", Color("#efd9b3"))
		example_view.add_theme_font_size_override("font_size", 18)
		_place(example_view, Rect2(654, 187, 414, 233), panel)
		instructions.size.y = 70

	solution_hint = _label("", Rect2(28, 428 if math else 328, 834, 58 if math else 70), 17, panel)
	_button("看一步提示", Rect2(900, 435 if math else 341, 168, 40), _show_hint, panel)
	result_view = TextEdit.new()
	result_view.editable = false
	result_view.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	result_view.add_theme_color_override("font_readonly_color", Color("#efd9b3"))
	result_view.add_theme_font_size_override("font_size", 17)
	_place(result_view, Rect2(28, 492 if math else 410, 1040, 103), panel)

	var controls_y := 610 if math else 544
	run_button = _button("运行示例", Rect2(28, controls_y, 157, 48), _run, panel)
	advance_button = _button("下一步 →", Rect2(198, controls_y, 171, 48), _advance, panel)
	return_button = _button("返回选路", Rect2(918 if math else 737, controls_y, 150, 48), _return, panel)
	skip_button = _button("跳过教程", Rect2(899, controls_y, 169, 48), _enter, panel)
	skip_button.visible = not math
	_refresh()
	run_button.grab_focus()
	set_process(false)

func _place(node: Control, bounds: Rect2, host: Control) -> void:
	host.add_child(node)
	node.position = bounds.position
	node.size = bounds.size

func _label(value: String, bounds: Rect2, pixels: int, host: Control) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", pixels)
	_place(label, bounds, host)
	return label

func _button(value: String, bounds: Rect2, action: Callable, host: Control) -> Button:
	var button := Button.new()
	button.text = value
	button.pressed.connect(action)
	_place(button, bounds, host)
	return button

func _refresh() -> void:
	hint_index = 0
	if route == "python":
		heading.text = "Python 新手教程  ·  %d / 2" % (step + 1)
		instructions.text = ("先点「运行示例」。print 会把引号里的文字显示在下面。" if step == 0 else
			"把引号里的「准备装车」改成「开始备货」，保留引号和括号。然后再点「运行示例」。")
	else:
		var lesson: Dictionary = LeanBasics.LESSONS[step]
		heading.text = "Lean 4 入门  ·  %02d / %02d  %s" % [step + 1, LeanBasics.LESSONS.size(), lesson.title]
		instructions.text = lesson.guide
		example_view.text = lesson.example
	run_button.text = "运行示例" if route == "python" else "检查 Lean"
	if step == _lesson_count() - 1:
		advance_button.text = "进入工坊 →"
	else:
		advance_button.text = "下一步 →" if route == "python" else "下一课 →"
	solution_hint.text = ""
	result_view.text = "结果会显示在这里。"
	_update_controls()

func _show_hint() -> void:
	if route == "python":
		solution_hint.text = ('现在可以直接运行 print("准备装车")。' if step == 0 else
			'改完的整行是 print("开始备货")。')
	else:
		var hints: Array = LeanBasics.LESSONS[step].hints
		solution_hint.text = hints[hint_index]
		hint_index = mini(hint_index + 1, hints.size() - 1)

func _updated_result(result: Dictionary) -> void:
	last_pass = result.ok
	result_view.text = result.output
	_update_controls()

func _edited() -> void:
	if last_pass:
		last_pass = false
		result_view.text = "代码已变更，请再检查一次。"
		_update_controls()

func _update_controls() -> void:
	var busy := worker != null
	editor.editable = not busy
	run_button.disabled = busy
	advance_button.disabled = busy or not last_pass
	skip_button.disabled = busy
	return_button.disabled = busy

func _run() -> void:
	if worker != null:
		return
	last_pass = false
	var pending := Thread.new()
	if pending.start(_check.bind(route, editor.text, step)) != OK:
		_updated_result({"ok": false, "output": "暂时无法启动检查。"})
		return
	worker = pending
	result_view.text = "检查中…"
	_update_controls()
	set_process(true)

static func _check(language: String, source: String, current_step: int) -> Dictionary:
	if language == "python":
		return PythonRunner.check_warmup(source, current_step)
	var result := LeanChecker.check(LeanChecker.tool(), source, LeanBasics.LESSONS[current_step], LeanBasics.MODULES)
	if result.ok:
		var output: String = result.output.strip_edges().get_slice("\n'zetaVerified'", 0)
		result.output = "Lean 检查通过，可以继续。\n" + (output if not output.begins_with("'zetaVerified'") else "")
	elif result.output.contains("sorry"):
		result.output = "还有空缺。请找出 sorry 的位置，参考例子或提示补上。\n\n" + result.output
	elif result.output.contains("unsolved goals"):
		result.output = "还有目标未完成。看 ⊢ 后面需要证明什么，再补证明步骤。\n\n" + result.output
	elif result.output.contains("type mismatch"):
		result.output = "类型不匹配。对照 Lean 显示的实际类型和期望类型。\n\n" + result.output
	elif result.output.contains("unknown identifier") or result.output.contains("Unknown identifier"):
		result.output = "Lean 找不到这个名字。检查拼写、大小写，或者是否需要 import。\n\n" + result.output
	return result

func _process(_delta: float) -> void:
	if worker.is_alive():
		return
	var result: Dictionary = worker.wait_to_finish()
	worker = null
	set_process(false)
	_updated_result(result)

func _advance() -> void:
	if not last_pass or worker != null:
		return
	if step == _lesson_count() - 1:
		_enter()
		return
	step += 1
	last_pass = false
	if route == "math":
		editor.text = LeanBasics.LESSONS[step].starter
	_refresh()
	if route == "math":
		lesson_advanced.emit()
	editor.grab_focus()

func _lesson_count() -> int:
	return 2 if route == "python" else LeanBasics.LESSONS.size()

func _enter() -> void:
	if worker == null and (route == "python" or (last_pass and step == _lesson_count() - 1)):
		enter_workshop.emit()

func _return() -> void:
	if worker == null:
		return_to_menu.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and worker != null and worker.is_started():
		worker.wait_to_finish()
