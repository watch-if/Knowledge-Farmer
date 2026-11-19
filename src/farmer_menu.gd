extends Control

const Runtime = preload("res://src/android_runtime.gd")
const Style = preload("res://src/workshop_style.gd")
const MathWorkshop = preload("res://main.tscn")
const PythonWorkshop = preload("res://src/python_workshop.gd")
const Tutorial = preload("res://src/route_tutorial.gd")
const TUTORIAL_SAVE := "user://route_tutorials.cfg"

var route_menu: Control
var math_button: Button
var python_button: Button
var python_tutorial_button: Button
var tutorial: Control
var tutorial_progress := ConfigFile.new()
var active_workshop: Control
var active_route := ""

func _ready() -> void:
	Runtime.configure()
	theme = Style.make()
	tutorial_progress.load(TUTORIAL_SAVE)
	route_menu = Control.new()
	route_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(route_menu)
	var artwork := TextureRect.new()
	artwork.texture = load("res://assets/farmer-room.webp")
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_SCALE
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	route_menu.add_child(artwork)
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var plaque := Panel.new()
	plaque.position = Vector2(413, 196)
	plaque.size = Vector2(614, 405)
	plaque.add_theme_stylebox_override("panel", Style.box(Color("#261810ee"), Color("#aa743f"), 15, 0))
	route_menu.add_child(plaque)

	var nameplate := Label.new()
	nameplate.text = str(ProjectSettings.get_setting("application/config/name"))
	nameplate.add_theme_font_size_override("font_size", 53)
	nameplate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nameplate.position = Vector2(0, 27)
	nameplate.size = Vector2(614, 105)
	plaque.add_child(nameplate)

	python_button = _route_button(plaque, "Python", "发货车间", Vector2(38, 171), "python")
	math_button = _route_button(plaque, "Math", "Lean 4 证明工坊", Vector2(324, 171), "math")
	python_tutorial_button = _tutorial_button(plaque, "Python 教程", Vector2(77, 346))
	python_button.grab_focus()

func _route_button(panel: Panel, name: String, description: String, at: Vector2, route: String) -> Button:
	var button := Button.new()
	button.position = at
	button.size = Vector2(252, 158)
	button.pressed.connect(_enter.bind(route))
	panel.add_child(button)
	var title := Label.new()
	title.text = name
	title.add_theme_font_size_override("font_size", 35)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.position = Vector2(0, 28)
	title.size = Vector2(252, 49)
	button.add_child(title)
	var caption := Label.new()
	caption.text = description
	caption.add_theme_font_size_override("font_size", 17)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.position = Vector2(0, 94)
	caption.size = Vector2(252, 31)
	button.add_child(caption)
	return button

func _tutorial_button(panel: Panel, caption: String, at: Vector2) -> Button:
	var button := Button.new()
	button.text = caption
	button.position = at
	button.size = Vector2(174, 36)
	button.pressed.connect(_show_tutorial)
	panel.add_child(button)
	return button

func _enter(route: String) -> void:
	if route == "math" or tutorial_progress.get_value("seen", "python", false):
		_open_workshop(route)
	else:
		_show_tutorial()

func _show_tutorial() -> void:
	if tutorial != null or not active_route.is_empty():
		return
	for button in [python_button, math_button, python_tutorial_button]:
		button.disabled = true
	tutorial = Tutorial.new()
	tutorial.enter_workshop.connect(_finish_tutorial)
	tutorial.return_to_menu.connect(_close_tutorial)
	add_child(tutorial)
	tutorial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _finish_tutorial() -> void:
	tutorial_progress.set_value("seen", "python", true)
	tutorial_progress.save(TUTORIAL_SAVE)
	_close_tutorial()
	_open_workshop("python")

func _close_tutorial() -> void:
	if tutorial == null:
		return
	tutorial.hide()
	tutorial.queue_free()
	tutorial = null
	for button in [python_button, math_button, python_tutorial_button]:
		button.disabled = false
	python_button.grab_focus()

func _open_workshop(route: String) -> void:
	if tutorial != null or not active_route.is_empty():
		return
	route_menu.hide()
	active_route = route
	active_workshop = MathWorkshop.instantiate() if route == "math" else PythonWorkshop.new()
	active_workshop.return_to_menu.connect(_return_to_menu)
	add_child(active_workshop)
	active_workshop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _return_to_menu() -> void:
	var focus := math_button if active_route == "math" else python_button
	active_workshop.hide()
	active_workshop.queue_free()
	active_workshop = null
	active_route = ""
	route_menu.show()
	focus.grab_focus()
