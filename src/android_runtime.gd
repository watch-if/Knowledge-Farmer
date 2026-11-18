extends RefCounted

const ARCHIVE := "res://assets/android-runtime/runtime.zip"
const STAMP := "res://assets/android-runtime/revision.txt"
const GLIBC_LIBS := ["c", "m", "dl", "pthread", "rt", "util"]

static var runtime_lock := Mutex.new()
static var installed_root := ""

static func execute(program: String, desktop_executable: String, arguments: PackedStringArray, output: Array) -> int:
	if OS.get_name() != "Android":
		return OS.execute(desktop_executable, arguments, output, true)
	runtime_lock.lock()
	var result := _execute_mobile(program, arguments, output)
	runtime_lock.unlock()
	return result

static func native_directory_from_maps(maps: String) -> String:
	for line in maps.split("\n"):
		if line.ends_with("/libgodot_android.so"):
			var start := line.find("/")
			if start >= 0:
				return line.substr(start).get_base_dir()
	return ""

static func safe_asset_path(path: String) -> bool:
	return (path.begins_with("lean/") or path.begins_with("python/")) and not path.contains("\\") and not path.contains(":") and path.simplify_path() == path

static func command_prefix(native_dir: String, program: String) -> PackedStringArray:
	var preloads := PackedStringArray()
	for name in GLIBC_LIBS:
		preloads.append(native_dir.path_join("libfarmer_%s.so" % name))
	return PackedStringArray([
		native_dir.path_join("libfarmer_loader.so"),
		"--library-path", native_dir,
		"--preload", ":".join(preloads),
		native_dir.path_join("libfarmer_%s.so" % program),
	])

static func _execute_mobile(program: String, arguments: PackedStringArray, output: Array) -> int:
	var native_dir := _native_directory()
	if native_dir.is_empty():
		output.append("无法找到 APK 内的运行时目录。请使用完整的 farmer Android 安装包。")
		return 1
	var error := _install_data()
	if not error.is_empty():
		output.append(error)
		return 1
	var settings := {
		"TMPDIR": installed_root,
		"LEAN_SYSROOT": installed_root.path_join("lean"),
		"PYTHONHOME": installed_root.path_join("python"),
		"PYTHONNOUSERSITE": "1",
		"FARMER_ANDROID_PYTHON_ARGV": JSON.stringify(Array(command_prefix(native_dir, "python"))),
	}
	var previous := {}
	for setting in settings:
		previous[setting] = OS.get_environment(setting) if OS.has_environment(setting) else null
		OS.set_environment(setting, settings[setting])
	var prefix := command_prefix(native_dir, program)
	var executable := prefix[0]
	prefix.remove_at(0)
	prefix.append_array(arguments)
	var result := OS.execute(executable, prefix, output, true)
	for setting in settings:
		if previous[setting] == null:
			OS.unset_environment(setting)
		else:
			OS.set_environment(setting, previous[setting])
	return result

static func _native_directory() -> String:
	var maps := FileAccess.open("/proc/self/maps", FileAccess.READ)
	if maps == null:
		return ""
	while not maps.eof_reached():
		var directory := native_directory_from_maps(maps.get_line())
		if not directory.is_empty():
			return directory
	return ""

static func _install_data() -> String:
	if not installed_root.is_empty():
		return ""
	var revision := FileAccess.get_file_as_string(STAMP).strip_edges()
	if not revision.is_valid_identifier():
		return "此 APK 缺少 Python 与 Lean 运行时数据。"
	var root := ProjectSettings.globalize_path("user://android-runtime").path_join(revision)
	var marker := root.path_join("ready")
	if FileAccess.file_exists(marker):
		installed_root = root
		return ""
	var archive := ZIPReader.new()
	if archive.open(ARCHIVE) != OK:
		return "无法读取 APK 内的运行时数据。"
	for entry in archive.get_files():
		if not safe_asset_path(entry):
			return "安装包的运行时文件路径无效。"
		var target := root.path_join(entry)
		if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK:
			return "无法建立运行时目录，请检查手机存储空间。"
		var file := FileAccess.open(target, FileAccess.WRITE)
		if file == null or not file.store_buffer(archive.read_file(entry)):
			return "无法解压运行时文件，请检查手机存储空间。"
		file.close()
	archive.close()
	var stamp := FileAccess.open(marker, FileAccess.WRITE)
	if stamp == null or not stamp.store_string(revision):
		return "无法完成运行时安装。"
	stamp.close()
	installed_root = root
	return ""
