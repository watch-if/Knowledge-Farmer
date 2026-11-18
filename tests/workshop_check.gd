extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	const Course = preload("res://src/course.gd")
	const Checker = preload("res://src/lean_checker.gd")
	var path := OS.get_environment("ZETA_LEAN")
	if path.is_empty():
		printerr("ZETA_LEAN must point at Lean 4")
		quit(1)
		return
	var library := {}
	for lesson in Course.LESSONS:
		var result: Dictionary = Checker.check(path, lesson.solution, lesson, library)
		if not result.ok:
			printerr("Expected solution for %s to pass: %s" % [lesson.id, result.output])
			quit(1)
			return
		var unfinished: Dictionary = Checker.check(path, lesson.starter, lesson, library)
		if unfinished.ok:
			printerr("Starter for %s passed without a proof" % lesson.id)
			quit(1)
			return
		if lesson.file in ["Accumulation", "OddTotal"]:
			library[lesson.file] = lesson.solution
	var invalid: Dictionary = Checker.check(path, "axiom addTwo : (2 : Nat) + 3 = 5", Course.LESSONS[0], {})
	if invalid.ok:
		printerr("An assumed result earned progress")
		quit(1)
		return
	var wrong: Dictionary = Checker.check(path, "theorem addTwo : (2 : Nat) = 2 := rfl", Course.LESSONS[0], {})
	if wrong.ok:
		printerr("A theorem of the wrong type earned progress")
		quit(1)
		return
	print("10 Lean checks passed")
	quit()
