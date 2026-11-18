extends Control

var item_id := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var front := PackedVector2Array([Vector2(3, 18), Vector2(66, 18), Vector2(66, 66), Vector2(3, 66)])
	var top := PackedVector2Array([Vector2(3, 18), Vector2(17, 4), Vector2(82, 4), Vector2(66, 18)])
	var side := PackedVector2Array([Vector2(66, 18), Vector2(82, 4), Vector2(82, 51), Vector2(66, 66)])
	draw_rect(Rect2(7, 24, 79, 47), Color(0, 0, 0, 0.27))
	draw_colored_polygon(front, Color("#a36330"))
	draw_colored_polygon(top, Color("#d9a060"))
	draw_colored_polygon(side, Color("#6e3f26"))
	draw_rect(Rect2(5, 19, 61, 46), Color("#ddaa6b"), false, 2)
	for offset in [27, 58]:
		draw_line(Vector2(6, offset), Vector2(64, offset), Color("#733c22"), 2)
	for column in [8, 57]:
		draw_rect(Rect2(column, 20, 6, 44), Color("#c89a57"))
		draw_circle(Vector2(column + 3, 23), 1.5, Color("#573a26"))
		draw_circle(Vector2(column + 3, 60), 1.5, Color("#573a26"))
	draw_rect(Rect2(16, 32, 39, 21), Color("#ffe3af"))
	draw_string(get_theme_default_font(), Vector2(16, 48), item_id, HORIZONTAL_ALIGNMENT_CENTER, 39, 14, Color("#492714"))
