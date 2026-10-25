extends Control
## 主画面: 魔物蛋的外壳 + 小屏幕 + 下面 8 个按钮 + 各种弹窗。竖着拿, 手机和平板都能点。
## 规矩都在 Pet / Game 里, 这里只管画和按。

## 按钮: 代号、字、图标
const ACTIONS := [
	["feed", "喂食", "meal"], ["lights", "开关灯", "light"], ["play", "玩耍", "game"], ["medicine", "吃药", "medicine"],
	["clean", "打扫", "clean"], ["status", "状态", "status"], ["scold", "管教", "scold"], ["more", "更多", "menu"],
]
const SHELL_RECT := Rect2(30, 160, 660, 640)
const LCD_RECT := Rect2(72, 270, 576, 384)
const CALL_LIGHT := Vector2(360, 222)
const SITTER_RECT := Rect2(200, 688, 320, 80)

var game: Game
var screen: ScreenView
var buttons := {}
var info: Label
var message: Label
var grid: GridContainer
var play_bar: VBoxContainer       # 玩小游戏时, 下面换成这个 (小游戏的按钮 + 「不玩了」)
var play_row: HBoxContainer
var sitter_button: Button
var dialog: Control = null       # 现在开着的弹窗
var dialog_buttons: Array = []   # 弹窗里的按钮 (测试按它们)
var allow_quit := true
var _tick_timer := 0.0
var _save_timer := 0.0
var _msg_until := 0.0
var _asked_leave := false
var _shown_end := false


func _ready() -> void:
	theme = Look.theme()
	size = Vector2(720, 1280)
	game = Game.load_saved()
	_build()
	if game.pet == null:
		_ask_difficulty()
	else:
		game.tick()
		game.take_messages()  # 离开期间的事不一条条报, 看画面就知道
		_shown_end = false
	_refresh()


func _build() -> void:
	var title := Label.new()
	title.text = "魔物蛋"
	title.add_theme_font_size_override("font_size", 54)
	title.position = Vector2(0, 28)
	title.size = Vector2(720, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	info = Label.new()
	info.position = Vector2(0, 98)
	info.size = Vector2(720, 44)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 28)
	info.add_theme_color_override("font_color", Look.TEXT_DIM)
	add_child(info)

	screen = ScreenView.new()
	screen.game = game
	screen.position = LCD_RECT.position
	screen.size = LCD_RECT.size
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.clip_contents = true  # 走出屏幕的魔物不画到外壳上
	add_child(screen)

	# 外壳上、屏幕下面的「托人照看」按钮 (学现代拓麻歌子的暂停 / 照看模式)
	sitter_button = Button.new()
	sitter_button.position = SITTER_RECT.position
	sitter_button.size = SITTER_RECT.size
	sitter_button.add_theme_font_size_override("font_size", 30)
	sitter_button.pressed.connect(do_action.bind("sitter"))
	add_child(sitter_button)

	message = Label.new()
	message.position = Vector2(40, 812)
	message.size = Vector2(640, 84)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 30)
	add_child(message)

	grid = GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(30, 908)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	add_child(grid)
	for a in ACTIONS:
		var b := Button.new()
		b.text = a[1]
		b.icon = Art.texture(a[2], 6)
		b.custom_minimum_size = Vector2(156, 150)
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_font_size_override("font_size", 28)
		b.pressed.connect(do_action.bind(a[0]))
		grid.add_child(b)
		buttons[a[0]] = b

	play_bar = VBoxContainer.new()
	play_bar.position = Vector2(30, 908)
	play_bar.size = Vector2(660, 312)
	play_bar.add_theme_constant_override("separation", 16)
	play_bar.visible = false
	add_child(play_bar)
	play_row = HBoxContainer.new()
	play_row.add_theme_constant_override("separation", 16)
	play_bar.add_child(play_row)
	var quit := Button.new()
	quit.text = "不玩了"
	quit.custom_minimum_size = Vector2(660, 76)
	quit.pressed.connect(quit_play)
	play_bar.add_child(quit)


func _process(delta: float) -> void:
	_tick_timer += delta
	if _tick_timer >= 1.0:
		_tick_timer = 0.0
		game.tick()
		_refresh()
	_save_timer += delta
	if _save_timer >= 30.0:
		_save()
	if screen.mode == "play" and screen.minigame != null:
		message.text = screen.minigame.status_text()  # 玩的时候, 下面那行字显示分数
		if screen.minigame.done:
			finish_play()
	queue_redraw()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			if game != null:
				game.tick()
				_refresh()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			if game != null:
				_save()


func _save() -> void:
	_save_timer = 0.0
	game.save()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Look.BG)
	draw_style_box(Look.box(Look.SHELL, 160, Look.SHELL_DARK, 8), SHELL_RECT)
	draw_style_box(Look.box(Look.SHELL_LIGHT, 140), SHELL_RECT.grow(-22))
	draw_style_box(Look.box(Look.SHELL, 130), SHELL_RECT.grow(-30))
	draw_style_box(Look.box(Look.LCD_EDGE, 18), LCD_RECT.grow(16))
	# 呼叫灯: 它叫你的时候一闪一闪
	var calling := game != null and game.pet != null and game.pet.call != ""
	var on := calling and int(Time.get_ticks_msec() / 400.0) % 2 == 0
	draw_circle(CALL_LIGHT, 17, Look.SHELL_DARK)
	draw_circle(CALL_LIGHT, 13, Look.CALL if on else (Color("8a2a3a") if calling else Look.SHELL_DARK.darkened(0.2)))
	draw_string(Look.font(), CALL_LIGHT + Vector2(28, 10), "呼叫", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Look.SHELL_LIGHT)


# ---------------------------------------------------------------- 刷新文字和按钮

func _refresh() -> void:
	var pet := game.pet
	info.text = _info_text()
	var fresh := game.take_messages()
	if not fresh.is_empty():
		var best: Dictionary = fresh[0]
		for m in fresh:
			if m.rank >= best.rank:
				best = m
		_say(best.text)
	if Time.get_ticks_msec() / 1000.0 > _msg_until:
		message.text = _hint()
	var playing := screen.mode == "play"
	var away := pet != null and pet.sitting()
	for id in buttons:
		var b: Button = buttons[id]
		b.disabled = pet == null or (pet.is_over() and id != "more" and id != "status") \
			or (pet.stage == "egg" and id not in ["lights", "status", "more"]) \
			or (away and id not in ["status", "more"])
	sitter_button.text = "接回来" if away else "托人照看"
	sitter_button.disabled = pet == null or pet.is_over() or pet.stage == "egg" or playing
	grid.visible = not playing
	play_bar.visible = playing
	if pet == null or dialog != null:
		return
	if not pet.wants_leave:
		_asked_leave = false
	if pet.is_over() and not _shown_end:
		_show_ending()
	elif pet.wants_leave and not _asked_leave:
		_ask_leave()


func _info_text() -> String:
	var pet := game.pet
	if pet == null:
		return ""
	var diff: String = Rules.DIFFICULTY_NAMES[pet.difficulty]
	if pet.stage == "egg":
		var left := maxi(0, pet.stage_at + Rules.STAGE_TIME.egg - pet.now)
		return "魔物蛋 · 大约 %d 分钟后孵出来 · %s" % [ceili(left / 60.0), diff]
	if pet.is_over():
		return "%s · %s" % [pet.display_name(), "离开了" if pet.stage == "gone" else "已经不在了"]
	if pet.sitting():
		return "%s · %d 岁 · 托人照看中 · 魔晶 %d" % [pet.display_name(), pet.age(), game.money]
	return "%s · %d 岁 · %s · 魔晶 %d" % [pet.display_name(), pet.age(), diff, game.money]


## 没有新消息的时候, 下面那行显示现在该做什么
func _hint() -> String:
	var pet := game.pet
	if pet == null or pet.is_over():
		return ""
	if pet.sitting():
		return "托给别人照看了, 还能照看 %s" % Game.sitter_text(pet.sitter_left())
	if pet.call != "":
		return game.describe({"kind": "call", "what": pet.call})
	if pet.sick:
		return "它生病了, 给它吃药"
	if pet.asleep:
		return "嘘…… 它在睡觉" if not pet.lights else "它睡着了, 记得关灯"
	if pet.poop > 0:
		return "有便便, 记得打扫"
	if pet.stage == "egg":
		return "蛋在动…… 等它孵出来"
	return ""


func _say(text: String) -> void:
	if text == "":
		return
	message.text = text
	_msg_until = Time.get_ticks_msec() / 1000.0 + 4.0


# ---------------------------------------------------------------- 按钮

func do_action(id: String) -> void:
	if dialog != null or game.pet == null:
		return
	var text := ""
	match id:
		"feed":
			game.tick()
			if game.pet.asleep:
				text = "它在睡觉, 别吵它"
			else:
				var options := [["饭 (免费, 饱一点)", _feed.bind("meal")], ["零食 (免费, 开心一点, 会胖)", _feed.bind("snack")]]
				for f in Items.of_kinds(["food"]):
					if int(game.items.get(f, 0)) > 0:
						options.append(["%s ×%d (%s)" % [Items.name_of(f), game.items[f], Items.food_text(f)], _feed.bind(f)])
				options.append(["算了", close_dialog])
				_dialog("喂什么?", "" if options.size() > 3 else "商店 (在「更多」里) 能买更好吃的东西。", options)
		"lights":
			text = game.act("lights")
		"play":
			game.tick()
			var r := game.pet.can_play()
			if r == "ok":
				_ask_play()
			else:
				text = {"asleep": "它在睡觉, 别吵它", "sick": "它生病了, 不想玩"}.get(r, "")
		"medicine":
			text = game.act("medicine")
			if game.last_result in ["more", "cured"]:
				screen.show_effect("medicine")
		"clean":
			text = game.act("clean")
		"status":
			screen.show_status()
		"scold":
			text = game.act("scold")
			if game.last_result in ["good", "sad"]:
				screen.show_effect("angry")
		"more":
			_show_menu()
		"sitter":
			text = game.act("sitter")
	_after(text)


## 做完一个动作: 存档、刷新, 再显示这个动作的结果 (比动作顺带引起的小事要紧, 比如喂完饭它又说不开心)
func _after(text: String) -> void:
	_save()
	_refresh()
	_say(text)


## what: meal 饭 / snack 零食 / 商店买的吃的代号
func _feed(what: String) -> void:
	close_dialog()
	var text := game.act(what) if what in ["meal", "snack"] else game.act("food", what)
	if game.last_result in ["ok", "bland"]:
		screen.show_effect(Items.ICON.get(what, what))
	_after(text)


# ---------------------------------------------------------------- 小游戏和玩具

## 玩什么: 这个阶段能玩的小游戏, 还有买来的玩具
func _ask_play() -> void:
	var options := []
	var lines := ["玩小游戏能赚魔晶。"]
	for id in MiniGames.unlocked(game.pet.stage):
		var info := MiniGames.info(id)
		options.append([info.name, start_play.bind(id)])
		lines.append("%s: %s" % [info.name, info.help])
	for toy in Items.of_kinds(["toy"]):
		if toy in game.owned:
			var wait := game.toy_wait(toy)
			options.append(["玩%s%s" % [Items.name_of(toy), "" if wait == 0 else " (%s以后)" % Game.sitter_text(wait)],
				_play_toy.bind(toy)])
	options.append(["算了", close_dialog])
	if game.pet.stage != "adult":
		lines.append("长大了还有新的小游戏。")
	_dialog("玩什么?", "\n".join(lines), options)


func start_play(id: String, rng_seed := 0) -> void:
	close_dialog()
	screen.start_play(id, rng_seed)
	for b in play_row.get_children():
		play_row.remove_child(b)
		b.queue_free()
	var g := screen.minigame
	var list := g.buttons()
	var w := (660.0 - 16.0 * (list.size() - 1)) / list.size()
	for a in list:
		var b := Button.new()
		b.text = a[1]
		b.custom_minimum_size = Vector2(w, 200)
		b.add_theme_font_size_override("font_size", 40)
		if ScreenView.PLAY_COLORS.has(a[0]):
			var col: Color = ScreenView.PLAY_COLORS[a[0]]
			b.add_theme_stylebox_override("normal", Look.box(col, 18, Look.INK, 3))
			b.add_theme_stylebox_override("hover", Look.box(col.lightened(0.15), 18, Look.INK, 3))
			b.add_theme_stylebox_override("pressed", Look.box(col.darkened(0.15), 18, Look.INK, 3))
		if g.hold_buttons():
			b.button_down.connect(play_press.bind(a[0]))
			b.button_up.connect(play_release.bind(a[0]))
		else:
			b.pressed.connect(play_press.bind(a[0]))
		play_row.add_child(b)
	_refresh()


func play_press(action: String) -> void:
	if screen.minigame != null:
		screen.minigame.press(action)


func play_release(action: String) -> void:
	if screen.minigame != null:
		screen.minigame.release(action)


## 小游戏玩完了: 算赢没赢、给魔晶
func finish_play() -> void:
	var g := screen.minigame
	if screen.mode != "play" or g == null:
		return
	screen.stop_play()
	var text := game.act("game", {"won": g.won(), "reward": g.reward()})
	if game.last_result == "won":
		screen.show_effect("note")
	_after(text)


## 玩到一半不玩了: 不算输赢, 不给魔晶, 也不减体重
func quit_play() -> void:
	screen.stop_play()
	_after("不玩了")


func _play_toy(toy: String) -> void:
	close_dialog()
	var text := game.act("toy", toy)
	if game.last_result == "ok":
		screen.show_effect(Items.ICON[toy])
	_after(text)


# ---------------------------------------------------------------- 弹窗

## 开一个弹窗: 标题、正文、按钮 ([字, 按了做什么], ...)
func _dialog(title_text: String, body: String, options: Array, extra: Control = null) -> void:
	close_dialog()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = Vector2(720, 1280)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	dim.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var head := Label.new()
	head.text = title_text
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 40)
	box.add_child(head)
	if body != "":
		var text := Label.new()
		text.text = body
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(580, 0)
		text.add_theme_font_size_override("font_size", 28)
		box.add_child(text)
	if extra != null:
		box.add_child(extra)
	dialog_buttons = []
	for o in options:
		var b := Button.new()
		b.text = o[0]
		b.custom_minimum_size = Vector2(0, 84)
		b.clip_text = true  # 字太长也不会把弹窗撑出屏幕
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.pressed.connect(o[1])
		box.add_child(b)
		dialog_buttons.append(b)
	dialog = dim
	# 钉在正中间, 内容多大就往四周长多大
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH


func close_dialog() -> void:
	if dialog != null:
		dialog.queue_free()
		dialog = null
		dialog_buttons = []


## 测试用: 按弹窗里第 i 个按钮
func choose(i: int) -> void:
	dialog_buttons[i].pressed.emit()


func _ask_difficulty() -> void:
	_dialog("选难度", "放宽 (推荐): 心掉得慢一半。它叫你以后 2 小时没理才算一次照顾失误, 失误多了也不会死, " +
		"只要别一整天不管它。隔几个小时看一次就行。\n\n" +
		"原版严格 (挑战): 跟 1996 年的原版一样。它叫你以后 15 分钟没理就算失误 " +
		"(不是要你每 15 分钟看一次), 成年以后失误 5 次会死, 一个阶段病 3 次也会死。最好每小时看一次。隐藏的魔物只有这个难度养得出来。\n\n" +
		"两种都能「托人照看」: 上学、上班的时候托给别人, 每天最多 %s。" % Game.sitter_text(Rules.SITTER_PER_DAY),
		[["放宽 (推荐)", _new_egg.bind(Rules.EASY)], ["原版严格 (挑战)", _new_egg.bind(Rules.STRICT)]])


func _new_egg(diff: String) -> void:
	close_dialog()
	game.new_egg(diff)
	screen.mode = "pet"
	screen.pet_x = 16.0
	_shown_end = false
	_asked_leave = false
	_save()
	_refresh()


func _show_ending() -> void:
	_shown_end = true
	var pet := game.pet
	var head := "%s 出发了" % pet.display_name() if pet.stage == "gone" else "再见了, %s" % pet.display_name()
	_dialog(head, "%s\n活了 %d 岁。已经记进图鉴。" % [Game.ending_text(pet.end_reason), pet.age()],
		[["孵一颗新蛋", _ask_difficulty], ["先看看", close_dialog]])


func _ask_leave() -> void:
	_asked_leave = true
	_dialog("它想出去闯荡", "%s 长大了, 想出去看看外面的世界。\n\n放它走: 它会出发去闯荡 (记进图鉴)。\n留下来: 它继续陪着你, 一直到老。" %
		game.pet.display_name(), [["放它走", _answer_leave.bind(true)], ["留下来", _answer_leave.bind(false)]])


func _answer_leave(let_go: bool) -> void:
	close_dialog()
	_after(game.act("leave", let_go))


func _show_menu() -> void:
	var options := [["商店", _show_shop], ["装扮", _show_dress], ["图鉴", _show_dex], ["怎么玩", _show_help]]
	if game.pet != null and game.pet.is_over():
		options.append(["孵一颗新蛋", _ask_difficulty])
	if OS.is_debug_build():
		options.append(["快进 10 分钟 (试玩用)", _fast_forward.bind(10 * Rules.MIN)])
		options.append(["快进 1 小时 (试玩用)", _fast_forward.bind(Rules.HOUR)])
		options.append(["快进 8 小时 (试玩用)", _fast_forward.bind(8 * Rules.HOUR)])
	options.append(["关闭", close_dialog])
	_dialog("更多", "", options)


func _fast_forward(seconds: int) -> void:
	close_dialog()
	game.fast_forward(seconds)
	_save()
	_refresh()


## 一格一格的按钮 (商店、装扮里用): items = [[字, 图, 按了做什么, 能不能按], ...]
func _button_grid(items: Array) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	for it in items:
		var b := Button.new()
		b.text = it[0]
		if it[1] != null:
			b.icon = it[1]
		b.custom_minimum_size = Vector2(290, 96)
		b.add_theme_font_size_override("font_size", 24)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not it[3]
		b.pressed.connect(it[2])
		g.add_child(b)
		dialog_buttons.append(b)
	return g


static func item_icon(id: String) -> Texture2D:
	if Items.ICON.has(id):
		return Art.texture(Items.ICON[id], 5)
	return Art.swatch(Color(Items.DATA[id].color), 40, 40)


func _show_shop() -> void:
	var options := []
	for c in Items.SHOP:
		options.append([c[0], _show_shop_page.bind(c[0])])
	options.append(["关闭", close_dialog])
	_dialog("商店", "你有魔晶 %d。玩小游戏能赚魔晶。\n饭、零食、药一直免费; 这里卖更好吃的、玩具、衣服配饰和房间布置。" % game.money, options)


func _show_shop_page(category: String) -> void:
	var kinds: Array = []
	for c in Items.SHOP:
		if c[0] == category:
			kinds = c[1]
	var cells := []
	for id in Items.of_kinds(kinds):
		var d: Dictionary = Items.DATA[id]
		var line := "%s  %d 魔晶" % [d.name, d.price]
		var can := true
		if d.kind == "food":
			line += "\n%s (有 %d)" % [Items.food_text(id), int(game.items.get(id, 0))]
			can = int(game.items.get(id, 0)) < Items.MAX_STACK
		elif id in game.owned:
			line += "\n已经有了"
			can = false
		elif d.kind == "toy":
			line += "\n陪它玩, 开心 +1"
		cells.append([line, item_icon(id), _buy.bind(id, category), can])
	dialog_buttons = []
	var grid_box := _button_grid(cells)
	var extra := dialog_buttons.duplicate()
	_dialog(category, "你有魔晶 %d" % game.money, [["返回", _show_shop], ["关闭", close_dialog]], grid_box)
	dialog_buttons = extra + dialog_buttons


func _buy(id: String, category: String) -> void:
	var r := game.buy(id)
	_save()
	_show_shop_page(category)
	_say({"ok": "买了%s!" % Items.name_of(id), "poor": "魔晶不够, 去玩小游戏赚一点吧", "have": "已经有了",
		"full": "%s已经放满了" % Items.name_of(id)}[r])
	_refresh()


func _show_dress() -> void:
	var options := []
	for s in Items.SLOTS:
		var on: String = game.equip.get(s[0], "")
		options.append(["%s: %s" % [s[1], Items.name_of(on) if on != "" else "没有"], _show_dress_slot.bind(s[0], s[1])])
	options.append(["关闭", close_dialog])
	var any := false
	for id in game.owned:
		if Items.kind_of(id) != "toy":
			any = true
	_dialog("装扮", "衣服、配饰和房间布置只是好看。" + ("" if any else "\n还什么都没有, 先去商店看看吧。"), options)


func _show_dress_slot(slot: String, slot_name: String) -> void:
	var cells := [["不要了", null, _set_equip.bind(slot, ""), game.equip.has(slot)]]
	for id in Items.of_kinds([slot]):
		if id in game.owned:
			var on: bool = game.equip.get(slot, "") == id
			cells.append([Items.name_of(id) + (" (现在用的)" if on else ""), item_icon(id), _set_equip.bind(slot, id), not on])
	dialog_buttons = []
	var grid_box := _button_grid(cells)
	var extra := dialog_buttons.duplicate()
	_dialog(slot_name, "" if cells.size() > 1 else "还没有, 去商店买吧。", [["返回", _show_dress], ["关闭", close_dialog]], grid_box)
	dialog_buttons = extra + dialog_buttons


func _set_equip(slot: String, id: String) -> void:
	game.set_equip(slot, id)
	_save()
	_show_dress()


func _show_dex() -> void:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 10)
	var found := 0
	for id in Species.ORDER:
		var seen := game.dex.has(id)
		if seen:
			found += 1
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(190, 0)
		var pic := TextureRect.new()
		pic.texture = Art.texture(id, 5, Color.WHITE if seen else Color(0.15, 0.13, 0.2))
		pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		pic.custom_minimum_size = Vector2(80, 80)
		cell.add_child(pic)
		var name_label := Label.new()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 24)
		if seen:
			name_label.text = "%s ×%d" % [Species.name_of(id), game.dex[id]]
		else:
			name_label.text = "？？？" + (" (隐藏)" if Species.DATA[id].get("secret", false) else "")
			name_label.add_theme_color_override("font_color", Look.TEXT_DIM)
		cell.add_child(name_label)
		g.add_child(cell)
	_dialog("图鉴 %d/%d" % [found, Species.ORDER.size()], "一共养过 %d 只。隐藏的那一种只有「原版严格」养得出来。" %
		game.history.size(), [["关闭", close_dialog]], g)


func _show_help() -> void:
	_dialog("怎么玩", "它饿了、不开心、睡觉没关灯、无理取闹的时候, 上面的「呼叫」灯会闪。" +
		"不及时照顾就算一次照顾失误, 失误多少决定它长成哪一种魔物。\n\n" +
		"喂食: 饭让它饱, 零食让它开心 (会胖), 都免费; 商店还有更好吃的\n" +
		"玩耍: 玩小游戏 (长大了会多几种), 赢了它开心, 还能赚魔晶; 买了玩具也能陪它玩\n" +
		"吃药: 头上有骷髅就是病了\n打扫: 便便放久了会生病\n管教: 它无理取闹的时候管一管\n开关灯: 它睡着了要关灯\n" +
		"托人照看: 上学、上班的时候托给别人, 不叫你、不算失误, 每天最多 %s\n" % Game.sitter_text(Rules.SITTER_PER_DAY) +
		"更多: 商店 (用魔晶买东西)、装扮 (帽子、领结、房间布置, 只是好看)、图鉴\n\n" +
		"它跟着真实的时间长大: 一天长一岁。长大以后它会想出去闯荡, 可以放它走, 也可以留它到老。",
		[["知道了", close_dialog]])
