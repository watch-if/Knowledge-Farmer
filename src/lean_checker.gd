extends RefCounted

const Runtime = preload("res://src/android_runtime.gd")

const STANDARD_AXIOMS := ["propext", "Classical.choice", "Quot.sound"]
static var mutex := Mutex.new()

static func tool() -> String:
	var configured := OS.get_environment("ZETA_LEAN").strip_edges()
	if not configured.is_empty():
		return configured
	var windows := OS.get_name() == "Windows"
	var filename := "lean.exe" if windows else "lean"
	var folder := OS.get_executable_path().get_base_dir()
	var bundled := folder.path_join("lean/bin").path_join(filename)
	return bundled if FileAccess.file_exists(bundled) else filename

static func check(executable: String, source: String, lesson: Dictionary, library: Dictionary) -> Dictionary:
	mutex.lock()
	var result := _check(executable, source, lesson, library)
	mutex.unlock()
	return result

static func _check(executable: String, source: String, lesson: Dictionary, library: Dictionary) -> Dictionary:
	var dir := Runtime.local_path("lean_runtime/%d" % OS.get_process_id())
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return {"ok": false, "output": "无法创建本地 Lean 工作目录。"}
	var former := OS.get_environment("LEAN_PATH")
	OS.set_environment("LEAN_PATH", dir)
	var result := _run(executable, dir, source, lesson, library)
	if former.is_empty():
		OS.unset_environment("LEAN_PATH")
	else:
		OS.set_environment("LEAN_PATH", former)
	return result

static func _run(executable: String, dir: String, source: String, lesson: Dictionary, library: Dictionary) -> Dictionary:
	# Recompile local dependencies mentioned by the submitted source.
	for previous in DirAccess.get_files_at(dir):
		if previous.ends_with(".olean"):
			DirAccess.remove_absolute(dir.path_join(previous))
	library = library.duplicate()
	library.erase(lesson.get("file", ""))
	var dependencies := _compile_imports(executable, dir, source, library, {}, {})
	if not dependencies.ok:
		return dependencies
	var current: String = dir.path_join("ZetaAttempt.lean")
	var suffix := ""
	if lesson.has("contract"):
		suffix = "\n\n" + lesson.contract + "\n#print axioms zetaVerified\n"
	if not _write(current, source + suffix):
		return {"ok": false, "output": "无法保存 Lean 检查文件。"}
	var result := _execute(executable, ["--root=" + dir, current])
	if not result.ok or suffix.is_empty():
		return result
	var lines: PackedStringArray = result.output.strip_edges().split("\n")
	var report := lines[-1].strip_edges()
	if report == "'zetaVerified' does not depend on any axioms":
		return result
	var prefix := "'zetaVerified' depends on axioms: ["
	if report.begins_with(prefix) and report.ends_with("]"):
		var axioms := report.substr(prefix.length(), report.length() - prefix.length() - 1)
		for axiom in axioms.split(","):
			if axiom.strip_edges() not in STANDARD_AXIOMS:
				return {"ok": false, "output": "证明仍依赖未验证的公理或 sorry。\n" + result.output}
		return result
	return {"ok": false, "output": "Lean 未返回关卡所需的公理检查。\n" + result.output}

static func _compile_imports(executable: String, dir: String, source: String, modules: Dictionary,
		visited: Dictionary, visiting: Dictionary) -> Dictionary:
	var imports := RegEx.new()
	imports.compile("(?m)^\\s*import[ \\t]+([A-Za-z][A-Za-z0-9_]*)[ \\t]*(?:$|--)")
	for match_result in imports.search_all(source):
		var module := match_result.get_string(1)
		if not modules.has(module) or visited.has(module):
			continue
		if visiting.has(module):
			return {"ok": false, "output": "本地文件循环导入：" + module}
		visiting[module] = true
		var module_source: String = modules[module]
		var dependencies := _compile_imports(executable, dir, module_source, modules, visited, visiting)
		if not dependencies.ok:
			return dependencies
		var path := dir.path_join(module + ".lean")
		if not _write(path, module_source):
			return {"ok": false, "output": "无法写入知识架模块 " + module}
		var result := _execute(executable, ["--root=" + dir, "-o", dir.path_join(module + ".olean"), path])
		if not result.ok:
			return result
		visited[module] = true
		visiting.erase(module)
	return {"ok": true}

static func _execute(executable: String, arguments: PackedStringArray) -> Dictionary:
	var output: Array = []
	var status := Runtime.execute("lean", executable, arguments, output)
	if status == -1:
		return {"ok": false, "output": "无法启动 Lean 4。请设置 ZETA_LEAN，或使用含 Lean 的 Windows 试玩包。"}
	var message := String(output[0]) if not output.is_empty() else ""
	return {"ok": status == 0, "output": message}

static func _write(path: String, contents: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(contents)
	file.close()
	return true
