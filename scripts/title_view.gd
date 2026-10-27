class_name TitleView
extends Control
## 开始界面 (第四版, 用户 2026-10-25 要的): 每次打开游戏先看到这个。
## 大字「魔物蛋」, 中间一颗摇来摇去的蛋 (养着魔物的话是你的魔物), 下面「开始」或「继续养」、「怎么玩」, 最下面是版本号。

signal start_pressed
signal help_pressed

var game: Game
var start_button: Button
var help_button: Button
var t := 0.0


func _ready() -> void:
	size = Vector2(720, 1280)
	mouse_filter = Control.MOUSE_FILTER_STOP  # 盖住后面的按钮
	start_button = _button(Vector2(110, 900), Vector2(500, 120), 44)
	start_button.pressed.connect(func(): start_pressed.emit())
	help_button = _button(Vector2(210, 1050), Vector2(300, 84), 32)
	help_button.text = "怎么玩"
	help_button.pressed.connect(func(): help_pressed.emit())
	refresh()


func _button(pos: Vector2, s: Vector2, font_size: int) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = s
	b.add_theme_font_size_override("font_size", font_size)
	add_child(b)
	return b


## 养着魔物就是「继续养」, 没有就是「开始」
func refresh() -> void:
	var pet := game.pet if game != null else null
	if pet != null and not pet.is_over():
		start_button.text = "继续养「%s」" % pet.display_name()
	else:
		start_button.text = "开始"


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Look.BG)
	var f := Look.font()
	draw_string(f, Vector2(0, 230), "魔物蛋", HORIZONTAL_ALIGNMENT_CENTER, 720, 110, Look.TEXT)
	draw_string(f, Vector2(0, 300), "在奇幻世界里, 从一颗蛋养大一只魔物", HORIZONTAL_ALIGNMENT_CENTER, 720, 30, Look.TEXT_DIM)
	# 中间的圆形「屏幕」和蛋 (或者你的魔物)
	draw_circle(Vector2(360, 590), 230, Look.SHELL_DARK)
	draw_circle(Vector2(360, 590), 214, Look.SHELL)
	draw_circle(Vector2(360, 590), 186, Look.LCD)
	var pet := game.pet if game != null else null
	var sprite := "egg"
	if pet != null and not pet.is_over() and pet.stage != "egg":
		sprite = pet.species
	var px := 16.0
	var wobble: float = round(sin(t * 5.0) * 1.5) * px / 4.0 if sprite == "egg" else 0.0
	var bob: float = (1 if int(t * 2.0) % 2 == 0 else 0) * px / 2.0 if sprite != "egg" else 0.0
	var shift := Art.shift_for(sprite, pet.hue) if sprite != "egg" else 0.0  # 第七版: 遗传来的颜色
	Art.draw(self, sprite, Vector2(360 - 8 * px + wobble, 590 - 8 * px + bob), px, false, Color.WHITE, Color(0, 0, 0, 0), shift)
	# 两边的小魔物 (图鉴里有的才露脸, 没有的是黑影)
	var sides := ["huolong", "hailong", "fengying", "shuiling", "yunyang", "linlu"]
	for i in sides.size():
		var id: String = sides[i]
		var seen := game != null and game.dex.has(id)
		var x: float = 40.0 + (i % 3) * 70.0 if i < 3 else 470.0 + (i % 3) * 70.0
		var y: float = 800.0 + (8.0 if (int(t * 2.0) + i) % 2 == 0 else 0.0)
		Art.draw(self, id, Vector2(x, y), 4.0, i >= 3, Color.WHITE if seen else Color(0.1, 0.08, 0.14))
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	draw_string(f, Vector2(0, 1240), "v" + version, HORIZONTAL_ALIGNMENT_CENTER, 720, 24, Look.TEXT_DIM)
