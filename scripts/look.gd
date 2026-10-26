class_name Look
extends RefCounted
## 界面的样子: 颜色、字体、按钮。魔物蛋的外壳是紫色的, 屏幕是原版那种淡绿色。

const BG := Color("2a2138")
const SHELL := Color("9b6fd0")
const SHELL_DARK := Color("6b44a0")
const SHELL_LIGHT := Color("c7a6f0")
const LCD := Color("dfe9d3")
const LCD_DARK := Color("232733")
const LCD_EDGE := Color("3a2d50")
const TEXT := Color("fff6e8")
const TEXT_DIM := Color("c9bcd9")
const INK := Color("2a2333")
const BUTTON := Color("fff1d0")
const BUTTON_HOVER := Color("ffe2a8")
const BUTTON_DOWN := Color("ffc970")
const CALL := Color("ff4a4a")

## 第四版起自己带字体 (手机上没有电脑里的字体): 思源黑体 Noto Sans SC, 只挑了游戏用到的字 (tools/make_font.py)
const FONT_FILE := "res://fonts/NotoSansSC-Medium-subset.otf"
## 万一缺字, 用系统字体补上。注意: Mac 上要「PingFang SC」会拿到香港字形 (缺简体字), 所以苹方放最后 (《血脉与王冠》踩过的坑)
const FONTS := ["Hiragino Sans GB", "Microsoft YaHei", "Noto Sans CJK SC", "Source Han Sans SC", "STHeiti", "PingFang SC"]

static var _font: Font = null
static var _theme: Theme = null


static func font() -> Font:
	if _font == null:
		var backup := SystemFont.new()
		backup.font_names = PackedStringArray(FONTS)
		backup.font_weight = 600
		var f: FontFile = load(FONT_FILE)
		if f == null:
			_font = backup
		else:
			f.fallbacks = [backup]
			_font = f
	return _font


static func box(color: Color, radius := 18, border := Color(0, 0, 0, 0), border_w := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func theme() -> Theme:
	if _theme == null:
		var t := Theme.new()
		t.default_font = font()
		t.default_font_size = 30
		t.set_stylebox("normal", "Button", box(BUTTON, 18, INK, 3))
		t.set_stylebox("hover", "Button", box(BUTTON_HOVER, 18, INK, 3))
		t.set_stylebox("pressed", "Button", box(BUTTON_DOWN, 18, INK, 3))
		t.set_stylebox("disabled", "Button", box(Color("8f8799"), 18, Color("5a5266"), 3))
		t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			t.set_color(state, "Button", INK)
		t.set_color("font_disabled_color", "Button", Color("4a4256"))
		t.set_color("font_color", "Label", TEXT)
		t.set_stylebox("panel", "PanelContainer", box(Color("3b2d52"), 24, SHELL_LIGHT, 4))
		_theme = t
	return _theme
