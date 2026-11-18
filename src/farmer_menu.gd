extends Control

const Style = preload("res://src/workshop_style.gd")
const MathWorkshop = preload("res://main.tscn")
const PythonWorkshop = preload("res://src/python_workshop.gd")

var route_menu: Control
var math_button: Button
var python_button: Button
var active_workshop: Control
var active_route := ""

func _ready() -> void:
	theme = Style.make()
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
	plaque.size = Vector2(614, 385)
	plaque.add_theme_stylebox_override("panel", Style.box(Color("#261810ee"), Color("#aa743f"), 15, 0))
	route_menu.add_child(plaque)

	var nameplate := Label.new()
	nameplate.text = "farmer"
	nameplate.add_theme_font_size_override("font_size", 76)
	nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nameplate.position = Vector2(0, 27)
	nameplate.size = Vector2(614, 105)
	plaque.add_child(nameplate)

	python_button = _route_button(plaque, "Python", "发货车间", Vector2(38, 171), "python")
	math_button = _route_button(plaque, "Math", "Lean 4 证明工坊", Vector2(324, 171), "math")
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

func _enter(route: String) -> void:
	if not active_route.is_empty():
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
