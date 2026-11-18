extends SceneTree

const Menu = preload("res://menu.tscn")
const PythonRunner = preload("res://src/python_runner.gd")
const PythonCourse = preload("res://src/python_course.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_packed(Menu)
	await scene_changed
	_expect(ProjectSettings.get_setting("application/config/name") == "farmer", "Game name is farmer")
	_expect(ProjectSettings.get_setting("application/run/main_scene") == "res://menu.tscn", "Launcher is main")
	_expect(ProjectSettings.globalize_path("user://").contains("godot/app_userdata/Zeta Lab"), "Old math save path persists")
	var menu = current_scene
	if OS.has_environment("FARMER_CAPTURE"):
		await _capture("farmer-start.png")
	_expect(menu.math_button.visible and menu.python_button.visible, "Both route buttons are visible")
	menu.python_button.pressed.emit()
	_expect(menu.tutorial != null and menu.active_workshop == null, "Fresh Python entry starts the beginner tutorial")
	await _complete_tutorial(menu.tutorial, "python")
	_expect(menu.active_route == "python", "Completing the tutorial opens the Python workbench")
	var track = menu.active_workshop
	track.check_button.pressed.emit()
	await _wait_for_check(track)
	_expect(track.completed.is_empty() and track.ship_button.disabled, "Unfinished scripts cannot dispatch goods")
	track.fold_button.pressed.emit()
	_expect(not track.editor.visible and track.floor.visible, "The loading yard remains visible with the editor folded")
	track.fold_button.pressed.emit()
	_expect(track.editor.visible, "Editor reopens from its title bar")
	var canned := """from pathlib import Path
Path('report.csv').write_text('item_id,name,price\\nA12,Brass Nut,2.50\\nA18,"Angle, Small",16.00\\n')
"""
	var second_case: Dictionary = PythonRunner.check(canned, PythonCourse.LESSONS[0])
	_expect(not second_case.ok and second_case.output.contains("2/2"), "Result hardcoded for one dataset fails the second")
	for index in PythonCourse.LESSONS.size():
		if index == 0:
			track.editor.text = track.editor.text.replace('"name": row["name"],', '"name": row["name"].strip(),')
			track.editor.text = track.editor.text.replace('"price": row["price"],', '"price": format(Decimal(row["price"]), ".2f"),')
		else:
			track.editor.text = PythonCourse.LESSONS[index].solution
		track.check_button.pressed.emit()
		await _wait_for_check(track)
		_expect(not track.completed.has(index) and not track.ship_button.disabled, "Accepted script loads a shipment before clearing the level")
		_expect(track.parcels.size() == 2, "The on-screen crates come from the verified report")
		track.step_button.pressed.emit()
		await _wait_for_loading(track)
		_expect(track.loaded == 1 and not track.completed.has(index), "Single-step loads exactly one actual crate")
		track.ship_button.pressed.emit()
		await _wait_for_loading(track)
		_expect(track.completed.has(index), "Loading the verified shipment completes the level")
		_expect(track.output.text.contains("2/2"), "Both fixture cases are verified")
		_expect(track.output.text.contains("item_id,name,price"), "Accepted report is previewed")
		if index + 1 < PythonCourse.LESSONS.size():
			track.next_button.pressed.emit()
			_expect(track.stage == index + 1, "Next Python lesson unlocks")
	if OS.has_environment("FARMER_CAPTURE"):
		await _capture("farmer-python.png")
		track.fold_button.pressed.emit()
		await _capture("farmer-yard.png")
	track.home_button.pressed.emit()
	_expect(menu.active_route.is_empty(), "Python workbench returns to menu")
	menu.math_button.pressed.emit()
	_expect(menu.tutorial != null, "Fresh Math entry starts a distinct Lean tutorial")
	await _complete_tutorial(menu.tutorial, "math")
	_expect(menu.active_route == "math" and menu.active_workshop.editors.has("Equation"), "Math opens the existing Lean editor")
	menu.active_workshop.return_button.pressed.emit()
	_expect(menu.active_route.is_empty(), "Math workbench returns to menu")
	menu.python_button.pressed.emit()
	_expect(menu.tutorial == null, "Returning players can go directly to the workshop")
	track = menu.active_workshop
	_expect(track.stage == 1 and track.completed.size() == 2, "Python progress survives switching tracks")
	_expect(track.editor.text == PythonCourse.LESSONS[1].solution, "Python source draft is restored")
	track.home_button.pressed.emit()
	menu.python_tutorial_button.pressed.emit()
	_expect(menu.tutorial != null and menu.tutorial.step == 0, "Tutorial can be reopened from the menu")
	menu.tutorial.return_button.pressed.emit()
	_expect(menu.tutorial == null and menu.active_workshop == null, "Cancel returns to route selection")
	change_scene_to_packed(Menu)
	await scene_changed
	menu = current_scene
	menu.math_button.pressed.emit()
	_expect(menu.active_route == "math" and menu.tutorial == null, "Completed tutorial stays dismissed after reloading the menu")
	if failures == 0:
		print("%d farmer route checks passed" % checks)
	quit(0 if failures == 0 else 1)

func _complete_tutorial(guide: Control, route: String) -> void:
	_expect(guide.advance_button.disabled, "Tutorial waits for a real check")
	if OS.has_environment("FARMER_CAPTURE"):
		await _capture("farmer-tutorial-" + route + ".png")
	guide.run_button.pressed.emit()
	await _wait_for_check(guide)
	_expect(not guide.advance_button.disabled, "Prefilled example runs in the real runtime")
	guide.advance_button.pressed.emit()
	_expect(guide.step == 1 and guide.advance_button.disabled, "Second step requires another check")
	guide.run_button.pressed.emit()
	await _wait_for_check(guide)
	_expect(guide.advance_button.disabled, "Unchanged program does not pass the edit step")
	guide.editor.text = 'print("开始备货")' if route == "python" else "theorem firstProof : (3 : Nat) = 3 := by\n  rfl"
	guide.run_button.pressed.emit()
	await _wait_for_check(guide)
	_expect(not guide.advance_button.disabled, "Changing one part passes the tutorial")
	guide.advance_button.pressed.emit()

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("FARMER_CAPTURE").path_join(filename)
	_expect(root.get_texture().get_image().save_png(path) == OK, "Game screenshot written")

func _wait_for_loading(track: Control) -> void:
	var deadline := Time.get_ticks_msec() + 6000
	while track.loading and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(not track.loading, "Conveyor motion completes")

func _wait_for_check(track: Control) -> void:
	var deadline := Time.get_ticks_msec() + 12000
	while track.worker != null and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(track.worker == null, "Python verification completed")

func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(description)
