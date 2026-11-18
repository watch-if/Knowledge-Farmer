extends SceneTree

const Runtime = preload("res://src/android_runtime.gd")

func _initialize() -> void:
	var map := """
001000-002000 r-xp 0 00:01 99 /data/app/pkg/lib/arm64/libgodot_android.so
003000-004000 r-xp 0 00:01 22 /data/app/pkg/lib/arm64/libc++_shared.so
"""
	assert(Runtime.native_directory_from_maps(map) == "/data/app/pkg/lib/arm64")
	assert(Runtime.safe_asset_path("lean/lib/lean/Init.olean"))
	assert(Runtime.safe_asset_path("python/lib/python3.12/csv.py"))
	for invalid in ["../temp.py", "lean/../../outside", "/lean/lib", "python/lib/../tmp", "outside.csv", "lean\\..\\tmp"]:
		assert(not Runtime.safe_asset_path(invalid), invalid)
	var argv := Runtime.command_prefix("/data/app/pkg/lib/arm64", "lean")
	assert(argv[0].ends_with("/libfarmer_loader.so"))
	assert(argv[-1].ends_with("/libfarmer_lean.so"))
	assert(argv[4].contains("libfarmer_c.so") and argv[4].contains("libfarmer_util.so"))
	print("Android runtime path and launcher checks passed")
	quit()
