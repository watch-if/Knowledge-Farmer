extends Node

const Runtime = preload("res://src/android_runtime.gd")
const MathCourse = preload("res://src/course.gd")
const PythonCourse = preload("res://src/python_course.gd")
const LeanChecker = preload("res://src/lean_checker.gd")
const PythonRunner = preload("res://src/python_runner.gd")

var worker: Thread

func _ready() -> void:
	Runtime.configure()
	print("FARMER_ANDROID_START")
	worker = Thread.new()
	worker.start(_exercise)

func _process(_delta: float) -> void:
	if worker.is_alive():
		return
	var result: String = worker.wait_to_finish()
	set_process(false)
	if result.is_empty():
		print("FARMER_ANDROID_OK two Python lessons and four Lean lessons")
	else:
		print("FARMER_ANDROID_FAIL ", result)
	get_tree().quit(0 if result.is_empty() else 1)

func _exercise() -> String:
	var warmup := PythonRunner.check_warmup('print("开始备货")', 1)
	if not warmup.ok:
		return warmup.output
	for lesson in PythonCourse.LESSONS:
		var result := PythonRunner.check(lesson.solution, lesson)
		if not result.ok:
			return lesson.id + " " + result.output
	var modules := {}
	for lesson in MathCourse.LESSONS:
		var result := LeanChecker.check(LeanChecker.tool(), lesson.solution, lesson, modules)
		if not result.ok:
			return lesson.id + " " + result.output
		modules[lesson.file] = lesson.solution
	return ""
