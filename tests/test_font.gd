extends TestCase
## 第四版起自己带字体 (手机上没有电脑里的字体)。游戏里用到的每个字, 带的字体里都要有;
## 缺了就是加了新的中文没重跑 tools/make_font.py。


func test_bundled_font_has_every_character() -> void:
	var f: FontFile = load(Look.FONT_FILE)
	check(f != null, "字体文件在")
	if f == null:
		return
	var missing := {}
	for folder in ["res://scripts"]:
		for file in DirAccess.get_files_at(folder):
			if not file.ends_with(".gd"):
				continue
			var text := FileAccess.get_file_as_string(folder.path_join(file))
			for i in text.length():
				var c := text.unicode_at(i)
				if c > 0x7F and not f.has_char(c):
					missing[char(c)] = true
	eq(missing.keys().size(), 0, "缺这些字, 要重跑 tools/make_font.py: %s" % "".join(missing.keys()))


func test_game_uses_the_bundled_font() -> void:
	check(Look.font() is FontFile, "用的是带的字体, 不是系统字体")
