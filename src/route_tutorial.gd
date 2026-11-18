extends Control

signal enter_workshop
signal return_to_menu

const Style = preload("res://src/workshop_style.gd")
const PythonRunner = preload("res://src/python_runner.gd")
const LeanChecker = preload("res://src/lean_checker.gd")

var route := "python"
var step := 0
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

func _ready() -> void:
	theme = Style.make()
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.035, 0.02, 0.84)
	_place(shade, Rect2(0, 0, 1440, 810), self)
	var panel := Panel.new()
	_place(panel, Rect2(172, 94, 1096, 622), self)
	heading = _label("", Rect2(28, 15, 1020, 50), 29, panel)
	instructions = _label("", Rect2(28, 76, 1021, 92), 20, panel)

	editor = CodeEdit.new()
	editor.text = 'print("准备装车")' if route == "python" else "theorem firstProof : (2 : Nat) = 2 := by\n  rfl"
	editor.gutters_draw_line_numbers = true
	editor.indent_size = 2
	editor.indent_use_spaces = true
	editor.add_theme_color_override("font_color", Color("#3d2817"))
	editor.add_theme_color_override("caret_color", Color("#3d2817"))
	editor.add_theme_color_override("current_line_color", Color("#e9cb96"))
	editor.add_theme_color_override("line_number_color", Color("#6a4c32"))
	editor.add_theme_font_size_override("font_size", 22)
	editor.add_theme_stylebox_override("normal", Style.box(Color("#f8e1b6"), Color("#b7834e"), 6, 16))
	editor.add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, Color("#dfa158"), 6, 16))
	var code_font := SystemFont.new()
	code_font.font_names = ["Consolas", "DejaVu Sans Mono"]
	code_font.fallbacks = [theme.default_font]
	editor.add_theme_font_override("font", code_font)
	_place(editor, Rect2(28, 178, 1040, 135), panel)
	editor.text_changed.connect(_edited)

	solution_hint = _label("", Rect2(28, 328, 834, 70), 17, panel)
	_button("看一步提示", Rect2(900, 341, 168, 40), _show_hint, panel)
	result_view = TextEdit.new()
	result_view.editable = false
	result_view.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	result_view.add_theme_color_override("font_readonly_color", Color("#efd9b3"))
	result_view.add_theme_font_size_override("font_size", 17)
	_place(result_view, Rect2(28, 410, 1040, 103), panel)

	run_button = _button("运行示例", Rect2(28, 544, 157, 48), _run, panel)
	advance_button = _button("下一步 →", Rect2(198, 544, 171, 48), _advance, panel)
	return_button = _button("返回选路", Rect2(737, 544, 150, 48), _return, panel)
	skip_button = _button("跳过教程", Rect2(899, 544, 169, 48), _enter, panel)
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
	var route_name := "Python" if route == "python" else "Lean 4"
	heading.text = "%s 新手教程  ·  %d / 2" % [route_name, step + 1]
	if route == "python":
		instructions.text = ("先点「运行示例」。print 会把引号里的文字显示在下面。" if step == 0 else
			"把引号里的「准备装车」改成「开始备货」，保留引号和括号。然后再点「运行示例」。")
	else:
		instructions.text = ("先点「检查证明」。Nat 表示自然数，等号两边都是 2。rfl 告诉 Lean 检查两边是不是同一个值。" if step == 0 else
			"把第一行等号两边的 2 都改成 3，第二行的 rfl 留着。然后再点「检查证明」。")
	run_button.text = "运行示例" if route == "python" else "检查证明"
	advance_button.text = "下一步 →" if step == 0 else "进入工坊 →"
	solution_hint.text = ""
	result_view.text = "结果会显示在这里。"
	_update_controls()

func _show_hint() -> void:
	if route == "python":
		solution_hint.text = ('现在可以直接运行 print("准备装车")。' if step == 0 else
			'改完的整行是 print("开始备货")。')
	else:
		solution_hint.text = ("保持两行原样。第二行的 rfl 前留两个空格。" if step == 0 else
			"第一行应是 theorem firstProof : (3 : Nat) = 3 := by。下面仍然是缩进的 rfl。")

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
	var value := current_step + 2
	var contract := "theorem zetaVerified : (%d : Nat) = %d := firstProof" % [value, value]
	var result := LeanChecker.check(LeanChecker.tool(), source, {"contract": contract}, {})
	if result.ok:
		result.output = "Lean 已确认：%d = %d。可以继续。" % [value, value]
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
	if step == 1:
		_enter()
		return
	step = 1
	last_pass = false
	_refresh()
	editor.grab_focus()

func _enter() -> void:
	if worker == null:
		enter_workshop.emit()

func _return() -> void:
	if worker == null:
		return_to_menu.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and worker != null and worker.is_started():
		worker.wait_to_finish()
