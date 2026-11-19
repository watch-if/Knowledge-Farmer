extends Node

const Runtime = preload("res://src/android_runtime.gd")
const MathCourse = preload("res://src/course.gd")
const LeanBasics = preload("res://src/lean_basics.gd")
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
		print("FARMER_ANDROID_OK %d Python lessons and %d Math lessons, including the first Lean proof" % [
			PythonCourse.LESSONS.size(), MathCourse.LESSONS.size()])
	else:
		print("FARMER_ANDROID_FAIL ", result)
	get_tree().quit(0 if result.is_empty() else 1)

func _exercise() -> String:
	var first_proof: Dictionary = LeanBasics.LESSONS[0]
	var lean := LeanChecker.tool()
	var unfinished := LeanChecker.check(lean, first_proof.starter, first_proof, LeanBasics.MODULES)
	if unfinished.ok or not unfinished.output.contains("⊢"):
		return "Lean starter did not show the unfinished goal: " + unfinished.output
	var checked := LeanChecker.check(lean, first_proof.starter.replace("sorry", "rfl"), first_proof, LeanBasics.MODULES)
	if not checked.ok:
		return "Lean first proof: " + checked.output
	print("FARMER_ANDROID_LEAN_INTRO_OK")
	var warmup := PythonRunner.check_warmup('print("开始备货")', 1)
	if not warmup.ok:
		return "Python warmup: " + warmup.output
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
