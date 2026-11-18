extends RefCounted

const GOLD := Color("#eac084")

static func make() -> Theme:
	var result := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK SC", "Microsoft YaHei UI", "Microsoft YaHei", "Segoe UI"])
	font.font_weight = 500
	var packaged := load("res://assets/workshop-sc.otf") as FontFile
	if packaged:
		font.fallbacks = [packaged]
	result.default_font = font
	result.default_font_size = 17
	result.set_color("font_color", "Label", GOLD)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var color := Color("#204b3a")
		match state:
			"hover": color = Color("#36674c")
			"pressed": color = Color("#40261b")
			"disabled": color = Color("#47372b")
		result.set_stylebox(state, "Button", box(color, Color("#ae783a"), 6, 7))
	result.set_color("font_color", "Button", Color("#fff0c9"))
	result.set_color("font_disabled_color", "Button", Color("#b1a088"))
	result.set_stylebox("panel", "Panel", box(Color("#2e1a13"), Color("#a9773d"), 9, 0))
	return result

static func box(fill: Color, edge: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style
