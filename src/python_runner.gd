extends RefCounted

const Runtime = preload("res://src/android_runtime.gd")

static func executable() -> String:
	var configured := OS.get_environment("FARMER_PYTHON").strip_edges()
	if not configured.is_empty():
		return configured
	var windows := OS.get_name() == "Windows"
	var bundled := OS.get_executable_path().get_base_dir().path_join("python/python.exe")
	if windows and FileAccess.file_exists(bundled):
		return bundled
	return "python" if windows else "python3"

static func check_warmup(source: String, step: int) -> Dictionary:
	var lesson_id := "warmup_print" if step == 0 else "warmup_edit"
	return _run_grader(source, {"id": lesson_id, "file": "warmup.py"})

static func check(source: String, lesson: Dictionary) -> Dictionary:
	var result := _run_grader(source, lesson)
	if not result.ok:
		return result
	var message: String = result.output
	var separator := message.rfind("\n")
	var boxes: Variant = JSON.parse_string(message.substr(separator + 1))
	if not boxes is Array or boxes.is_empty():
		return {"ok": false, "output": "脚本通过，但工坊没有收到发货清单。"}
	return {"ok": true, "output": message.substr(0, separator).strip_edges(), "boxes": boxes}

static func _run_grader(source: String, lesson: Dictionary) -> Dictionary:
	var path := Runtime.local_path("python_runtime/%d" % OS.get_process_id())
	var directory_error := DirAccess.make_dir_recursive_absolute(path)
	if directory_error != OK:
		return {"ok": false, "output": "无法建立本地 Python 工作目录（%s）：%s" % [error_string(directory_error), path]}
	var grader_path := path.path_join("grader.py")
	var player_path: String = path.path_join(lesson.file)
	var grader_source := FileAccess.get_file_as_string("res://src/python_grader.py")
	if grader_source.is_empty() or not _write(grader_path, grader_source) or not _write(player_path, source):
		return {"ok": false, "output": "无法准备练习脚本。"}
	var output: Array = []
	var status := Runtime.execute("python", executable(), ["-X", "utf8", grader_path, lesson.id, player_path], output)
	if status == -1:
		return {"ok": false, "output": "无法启动 Python。请安装 Python 3，或设置 FARMER_PYTHON。"}
	var message := String(output[0]).strip_edges() if not output.is_empty() else ""
	return {"ok": status == 0, "output": message}

static func _write(path: String, value: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(value)
	file.close()
	return true
