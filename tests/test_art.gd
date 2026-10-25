extends TestCase
## 像素图都画对了: 行数、宽度对得上, 每个字都有颜色; 每个种类都有图。


func test_monster_sprites_are_16_by_16() -> void:
	for name in Art.HALF:
		var half: Array = Art.HALF[name]
		eq(half.size(), 16, "%s 有 16 行" % name)
		for i in half.size():
			eq(String(half[i]).length(), 8, "%s 第 %d 行是半边 8 个字" % [name, i])
		var full := Art.rows(name)
		eq(full[0].length(), 16, "%s 补齐以后 16 宽" % name)
		check(full[3] == full[3].substr(0, 8) + _rev(full[3].substr(0, 8)), "%s 左右对称" % name)


func test_icons_are_rectangles() -> void:
	for name in Art.ICONS:
		var rows: Array = Art.ICONS[name]
		for r in rows:
			eq(String(r).length(), String(rows[0]).length(), "%s 每行一样宽" % name)


func test_every_dot_has_a_color() -> void:
	for name in Art.HALF.keys() + Art.ICONS.keys():
		for r in Art.rows(name):
			for ch in r:
				check(ch == "." or Art.COLORS.has(ch), "%s 里的「%s」没有颜色" % [name, ch])


func test_every_species_has_a_picture() -> void:
	for id in Species.DATA:
		check(Art.HALF.has(id), "%s 有图" % id)
	for id in Species.ORDER:
		check(Species.DATA.has(id), "图鉴里的 %s 是一个种类" % id)


func test_images_have_the_right_size() -> void:
	var img := Art.image("huolong", 4)
	eq(img.get_width(), 64)
	eq(img.get_height(), 64)
	check(img.get_pixel(0, 0).a == 0.0, "左上角是透明的")


func _rev(s: String) -> String:
	var out := ""
	for i in range(s.length() - 1, -1, -1):
		out += s[i]
	return out
