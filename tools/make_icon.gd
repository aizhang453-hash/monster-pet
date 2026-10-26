extends SceneTree
## 画游戏的图标 (第四版, iPhone / iPad 的 App 图标要 1024 × 1024): 紫色的底, 中间一颗魔物蛋和小团子。
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/make_icon.gd
## 会写到 icon.png (项目设置里的图标)。


func _initialize() -> void:
	var size := 1024
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Look.SHELL)
	# 淡一圈的「屏幕」
	img.fill_rect(Rect2i(112, 112, 800, 800), Look.SHELL_LIGHT)
	img.fill_rect(Rect2i(144, 144, 736, 736), Look.LCD)
	var egg := Art.image("egg", 26)        # 16 × 26 = 416
	img.blit_rect_mask(egg, egg, Rect2i(Vector2i.ZERO, egg.get_size()), Vector2i(150, 300))  # 透明的地方不盖
	var baby := Art.image("tuanzi", 26)
	img.blit_rect_mask(baby, baby, Rect2i(Vector2i.ZERO, baby.get_size()), Vector2i(470, 330))
	img.save_png(ProjectSettings.globalize_path("res://icon.png"))
	print("画好了 icon.png")
	quit()
