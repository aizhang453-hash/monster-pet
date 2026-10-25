extends SceneTree
## 把所有魔物和小图标画成一张大图, 看画得对不对 (不用开窗口):
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tests/sprite_sheet.gd -- 存图的文件夹


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out)
	var names: Array = Art.HALF.keys()
	var scale := 8
	var cell := 16 * scale + 16
	var cols := 6
	var rows := ceili(names.size() / float(cols)) + 1
	var sheet := Image.create_empty(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Look.LCD)
	for i in names.size():
		var img := Art.image(names[i], scale)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % cols) * cell + 8, (i / cols) * cell + 8))
	var icons: Array = Art.ICONS.keys()
	for i in icons.size():
		var img := Art.image(icons[i], 6)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(8 + i * 60, (rows - 1) * cell + 8 + (i % 2) * 60))
	sheet.save_png(out.path_join("sprites.png"))
	print("画好了: ", out.path_join("sprites.png"), "  顺序: ", names)
	quit()
