extends SceneTree

const Course = preload("res://src/course.gd")
const Scene = preload("res://main.tscn")
var game: Control
var errors := 0
var assertions := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = Scene.instantiate()
	root.add_child(game)
	await process_frame
	if OS.get_environment("ZETA_CAPTURE") == "1":
		await _capture("ZetaLab-Workshop.png")
	_expect(game.stage == 0, "Fresh progress starts at chapter entry")
	_expect(game.advance_button.disabled, "Next lesson starts locked")
	game._open_hints()
	game._show_next_hint()
	game._toggle_diagram()
	_expect(game.hint_index == 1 and game.showing_diagram, "Hints and diagrams expand")
	game._close_overlay()
	game.editors.Equation.set_caret_column(8)
	game._toggle_file("Equation")
	_expect(not game.editors.has("Equation"), "A minimized window removes the editor")
	game._toggle_file("Equation")
	_expect(game.editors.Equation.get_caret_column() == 8, "Reopened editor restores caret")
	game._new_file()
	_expect(game.editors.has("Notebook1"), "New file opens a Lean editor")
	game.editors.Notebook1.text = "def workshopExample := 8\n"
	game._edited("Notebook1", game.editors.Notebook1)
	game._toggle_file("Notebook1")
	game._new_file()
	game.editors.Notebook2.text = "import Notebook1\nexample : workshopExample = 8 := rfl\n"
	game._edited("Notebook2", game.editors.Notebook2)
	game._run_current()
	await _wait_for_lean()
	_expect(game.screen_status.text.contains("检查通过") and game.archives.is_empty(),
		"Scratch files can import each other without awarding lesson progress")
	game._toggle_file("Notebook2")
	for index in Course.LESSONS.size():
		var lesson: Dictionary = Course.LESSONS[index]
		var editor: CodeEdit = game.editors[lesson.file]
		editor.text = lesson.solution
		game._edited(lesson.file, editor)
		game._run_file(lesson.file)
		await _wait_for_lean()
		_expect(game.archives.has(lesson.file), "Lean verification archives " + lesson.file)
		_expect(not game.advance_button.disabled, "Successful check unlocks the next action")
		if index < Course.LESSONS.size() - 1:
			game._advance()
			_expect(game.stage == index + 1, "Advance selects the next lesson")
	if OS.get_environment("ZETA_CAPTURE") == "1":
		await create_timer(0.55).timeout
		await _capture("ZetaLab-Rewrite.png")
	await create_timer(1.5).timeout
	_expect(game.device_output.text == "n² − m²", "The arm applies the two required rewrites")
	game._locate_rewrite(1)
	var diff: CodeEdit = game.editors.Difference
	_expect(diff.get_line(diff.get_caret_line()).substr(diff.get_caret_column()).begins_with("oddTotal_sq m"),
		"Selecting a workbench term locates its Lean rewrite")
	game._advance()
	_expect(game.overlay_kind == "tree", "Completed chapter opens the roadmap")
	if OS.get_environment("ZETA_CAPTURE") == "1":
		await _capture("ZetaLab-Knowledge-Tree.png")
	game._open_tree()
	_expect(game.overlay == null, "Second press closes the knowledge tree")
	game.queue_free()
	await process_frame
	game = Scene.instantiate()
	root.add_child(game)
	await process_frame
	_expect(game.stage == 3 and game.archives.size() == 4, "Completed progress restores on restart")
	_expect(game.closed.get("Notebook1", false), "Collapsed scratch window state restores")
	if errors == 0:
		print("%d workflow checks passed" % assertions)
	quit(0 if errors == 0 else 1)

func _wait_for_lean() -> void:
	var deadline := Time.get_ticks_msec() + 12000
	while game.worker != null and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(game.worker == null, "Lean check finishes within the test deadline")

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("/workspace/shared/downloads/" + filename)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		errors += 1
		printerr(description)
