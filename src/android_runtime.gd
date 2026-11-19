extends RefCounted

const ARCHIVE := "res://assets/android-runtime/runtime.zip"
const STAMP := "res://assets/android-runtime/revision.txt"
const GLIBC_LIBS := ["c", "m", "dl", "pthread", "rt", "util"]

static var runtime_lock := Mutex.new()
static var installed_root := ""
static var native_dir := ""
static var android_apk_path := ""
static var android_files_dir := ""
static var library_diagnostics := ""

static func configure() -> void:
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"):
		return
	var android: Object = Engine.get_singleton("AndroidRuntime")
	var context: Object = android.getApplicationContext()
	if context == null:
		return
	android_apk_path = String(context.getPackageCodePath())
	var files: Object = context.getFilesDir()
	if files != null:
		android_files_dir = String(files.getAbsolutePath())
	var directories := apk_library_candidates(android_apk_path)
	var class_loader: Object = context.getClassLoader()
	if class_loader != null:
		var loader_path: Variant = class_loader.findLibrary("farmer_loader")
		if loader_path != null:
			var resolved := String(loader_path)
			if resolved.is_absolute_path() and not resolved.contains("!/"):
				native_dir = resolved.get_base_dir()
				return
	library_diagnostics = ", ".join(directories)
	for directory in directories:
		var loader := directory.path_join("libfarmer_loader.so")
		if FileAccess.file_exists(loader) or _java_file_exists(loader):
			native_dir = directory
			return

static func _java_file_exists(path: String) -> bool:
	if not Engine.has_singleton("JavaClassWrapper"):
		return false
	var java: Object = Engine.get_singleton("JavaClassWrapper")
	var file_class: Object = java.wrap("java.io.File")
	if file_class == null:
		return false
	var file: Object = file_class.new(path)
	return file != null and file.exists()

static func apk_library_candidates(apk_path: String) -> PackedStringArray:
	if not apk_path.is_absolute_path():
		return []
	var root := apk_path.get_base_dir().path_join("lib")
	return PackedStringArray([root.path_join("arm64"), root.path_join("x86_64")])

static func local_path(relative: String) -> String:
	if OS.get_name() == "Android" and not android_files_dir.is_empty():
		return android_files_dir.path_join(relative)
	return ProjectSettings.globalize_path("user://" + relative)

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
	if program == "python":
		preloads.append(native_dir.path_join("libfarmer_libpython.so"))
	return PackedStringArray([
		native_dir.path_join("libfarmer_loader.so"),
		"--library-path", native_dir,
		"--preload", ":".join(preloads),
		native_dir.path_join("libfarmer_%s.so" % program),
	])

static func _execute_mobile(program: String, arguments: PackedStringArray, output: Array) -> int:
	if native_dir.is_empty():
		native_dir = _native_directory()
	if native_dir.is_empty():
		output.append("无法找到 APK 内的运行时目录。已检查：" + library_diagnostics)
		return 1
	var error := _install_data()
	if not error.is_empty():
		output.append(error)
		return 1
	var existing_library := OS.get_environment("LEAN_PATH")
	var standard_library := installed_root.path_join("lean/lib/lean")
	var settings := {
		"TMPDIR": installed_root,
		"LEAN_PATH": standard_library if existing_library.is_empty() else existing_library + ":" + standard_library,
		"PYTHONHOME": installed_root.path_join("python"),
		"PYTHONNOUSERSITE": "1",
		# Lean's libuv can use epoll with Android's app syscall policy.
		"UV_USE_IO_URING": "0",
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
	var root := local_path("android-runtime").path_join(revision)
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
