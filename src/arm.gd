extends Control

const BASE := Vector2(1286, 324)
const HOME := Vector2(1158, 243)
const SHELF := Vector2(948, 240)
const FIRST := Vector2(959, 379)
const SECOND := Vector2(969, 451)

var hand := HOME:
	set(value):
		hand = value
		queue_redraw()
var carried := ""
var motion: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func replay(lesson: String, update_display: Callable) -> void:
	if motion and motion.is_valid():
		motion.kill()
	carried = ""
	motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if lesson == "training":
		motion.tween_property(self, "hand", SECOND, 0.36)
		motion.tween_callback(_carry.bind("已验证"))
		motion.tween_property(self, "hand", SHELF, 0.42)
		motion.tween_callback(update_display.bind("练习通过"))
	elif lesson == "reuse":
		motion.tween_property(self, "hand", SHELF, 0.32)
		motion.tween_callback(_carry.bind("奇数和"))
		motion.tween_property(self, "hand", FIRST, 0.42)
		motion.tween_callback(update_display.bind("n² − oddTotal m"))
		motion.tween_property(self, "hand", SECOND, 0.30)
		motion.tween_callback(update_display.bind("n² − m²"))
		motion.tween_property(self, "hand", SHELF, 0.36)
	elif lesson == "odds":
		motion.tween_property(self, "hand", FIRST, 0.32)
		motion.tween_callback(_carry.bind("奇数和"))
		motion.tween_property(self, "hand", SHELF, 0.48)
		motion.tween_callback(update_display.bind("oddTotal n = n²"))
	else:
		motion.tween_property(self, "hand", SECOND, 0.44)
		if lesson == "accumulate":
			for subtotal in ["1", "4", "9", "16"]:
				motion.tween_callback(update_display.bind("oddTotal 4 → " + subtotal))
				motion.tween_interval(0.18)
		else:
			motion.tween_callback(update_display.bind("2 + 3 = 5"))
	motion.tween_callback(_carry.bind(""))
	motion.tween_property(self, "hand", HOME, 0.36)

func halt() -> void:
	if motion and motion.is_valid():
		motion.kill()
	carried = ""
	hand = HOME

func _carry(text: String) -> void:
	carried = text
	queue_redraw()

func _draw() -> void:
	var travel := hand - BASE
	var half := travel.length() / 2.0
	var elbow := (BASE + hand) * 0.5
	elbow -= Vector2(travel.y, -travel.x).normalized() * sqrt(maxf(115.0 * 115.0 - half * half * 0.36, 3500))
	draw_set_transform(BASE + Vector2(0, 23), 0.0, Vector2(1.0, 0.47))
	draw_circle(Vector2.ZERO, 49, Color("#2b170d"), true, -1.0, true)
	draw_circle(Vector2(0, -8), 43, Color("#a16929"), true, -1.0, true)
	draw_arc(Vector2(0, -8), 39, 0, TAU, 40, Color("#edba62"), 2, true)
	draw_set_transform(Vector2.ZERO)
	_link(BASE, elbow, 26)
	_link(elbow, hand, 19)
	_joint(BASE, 26)
	_joint(elbow, 21)
	_joint(hand, 12)
	var prong := 33 if carried.is_empty() else 57
	for side in [-1.0, 1.0]:
		var points := PackedVector2Array([hand + Vector2(side * 7, 4), hand + Vector2(side * prong, 15), hand + Vector2(side * (prong - 4), 27)])
		draw_polyline(points, Color("#36200d"), 8, true)
		draw_polyline(points, Color("#c89245"), 4, true)
	if not carried.is_empty():
		draw_rect(Rect2(hand + Vector2(-53, 20), Vector2(106, 29)), Color("#d59c4e"))
		draw_rect(Rect2(hand + Vector2(-50, 23), Vector2(100, 23)), Color("#153f35"))
		draw_string(get_theme_default_font(), hand + Vector2(-34, 41), carried, HORIZONTAL_ALIGNMENT_CENTER, 68, 15, Color("#fff1cd"))

func _link(from: Vector2, to: Vector2, width: float) -> void:
	var offset := (to - from).orthogonal().normalized() * width * 0.28
	draw_line(from + Vector2(4, 6), to + Vector2(4, 6), Color(0, 0, 0, 0.42), width + 4, true)
	draw_line(from, to, Color("#34200f"), width + 2, true)
	draw_line(from, to, Color("#9d601f"), width - 3, true)
	draw_line(from + offset, to + offset, Color("#eeac53"), 4, true)
	draw_line(from - offset, to - offset, Color("#d28e36"), 3, true)
	draw_line(from, to, Color("#573313"), 3, true)

func _joint(at: Vector2, radius: float) -> void:
	draw_circle(at, radius + 2, Color("#29180e"), true, -1.0, true)
	draw_circle(at, radius, Color("#a26226"), true, -1.0, true)
	draw_arc(at, radius - 2, 0, TAU, 32, Color("#efb96b"), 2, true)
	draw_circle(at, radius * 0.66, Color("#122a24"), true, -1.0, true)
	draw_circle(at, radius * 0.49, Color("#326245"), true, -1.0, true)
	draw_circle(at + Vector2(-radius * 0.18, -radius * 0.2), radius * 0.13, Color("#76ac68"), true, -1.0, true)
