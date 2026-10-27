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
const OUT_RECT := Rect2(84, 688, 268, 80)
const SITTER_RECT := Rect2(368, 688, 268, 80)

var game: Game
var screen: ScreenView
var buttons := {}
var message: Label
var grid: GridContainer
var play_bar: VBoxContainer       # 玩小游戏时, 下面换成这个 (小游戏的按钮 + 「不玩了」)
var play_row: HBoxContainer
var sitter_button: Button
var out_button: Button
var title: TitleView = null      # 开始界面 (第四版; 按了「开始」就没了)
var dialog: Control = null       # 现在开着的弹窗
var dialog_buttons: Array = []   # 弹窗里的按钮 (测试按它们)
var allow_quit := true
var _tick_timer := 0.0
var _save_timer := 0.0
var _msg_until := 0.0
var _asked_leave := false
var _asked_match := false
var _asked_personality := false
var _shown_end := false


func _ready() -> void:
	theme = Look.theme()
	size = Vector2(720, 1280)
	game = Game.load_saved()
	_build()
	if game.pet != null:
		game.tick()
		game.take_messages()  # 离开期间的事不一条条报, 看画面就知道
		_shown_end = false
	_refresh()
	title = TitleView.new()
	title.game = game
	add_child(title)
	title.start_pressed.connect(start_game)
	title.help_pressed.connect(_show_help)


## 开始界面上按了「开始」/「继续养」
func start_game() -> void:
	if title == null:
		return
	close_dialog()
	title.queue_free()
	title = null
	if game.pet == null:
		_ask_difficulty()
	else:
		game.tick()
		game.take_messages()
	_refresh()


func _build() -> void:
	var title := Label.new()
	title.text = "魔物蛋"
	title.add_theme_font_size_override("font_size", 54)
	title.position = Vector2(0, 28)
	title.size = Vector2(720, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	# 第七版: 原来这里有一行小字 (名字、岁数、在哪、难度、魔晶), 用户嫌挤、跟屏幕上的重复;
	# 照拓麻歌子改成平时只看魔物, 这些都在「状态」第一页 (名片) 里看

	screen = ScreenView.new()
	screen.game = game
	screen.position = LCD_RECT.position
	screen.size = LCD_RECT.size
	screen.mouse_filter = Control.MOUSE_FILTER_STOP  # 第五版: 能点魔物摸摸它
	screen.pet_touched.connect(_on_pet_touched)
	screen.pest_tapped.connect(_on_pest_tapped)
	screen.clip_contents = true  # 走出屏幕的魔物不画到外壳上
	add_child(screen)

	# 外壳上、屏幕下面的「托人照看」按钮 (学现代拓麻歌子的暂停 / 照看模式)
	sitter_button = Button.new()
	sitter_button.position = SITTER_RECT.position
	sitter_button.size = SITTER_RECT.size
	sitter_button.add_theme_font_size_override("font_size", 30)
	sitter_button.pressed.connect(do_action.bind("sitter"))
	add_child(sitter_button)
	out_button = Button.new()  # 第三版: 出门
	out_button.text = "出门"
	out_button.position = OUT_RECT.position
	out_button.size = OUT_RECT.size
	out_button.add_theme_font_size_override("font_size", 30)
	out_button.pressed.connect(do_action.bind("out"))
	add_child(out_button)

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
	if _battle_text != "" and screen.battle_over():
		_say(_battle_text)  # 比赛的画面放完了再说结果
		_battle_text = ""
	if screen.mode == "play" and screen.minigame != null:
		# 玩的时候, 下面那行字显示分数; 刚开始两秒半先说怎么玩
		var info := MiniGames.info(screen.minigame.id)
		message.text = info.help if screen.minigame.t < 2.5 and not info.is_empty() else screen.minigame.status_text()
		if screen.minigame.buttons_version != _play_version:
			_build_play_row()
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
	var calling := game != null and game.pet != null and (game.pet.call != "" or game.pet.pest_at > 0)
	var on := calling and int(Time.get_ticks_msec() / 400.0) % 2 == 0
	draw_circle(CALL_LIGHT, 17, Look.SHELL_DARK)
	draw_circle(CALL_LIGHT, 13, Look.CALL if on else (Color("8a2a3a") if calling else Look.SHELL_DARK.darkened(0.2)))
	draw_string(Look.font(), CALL_LIGHT + Vector2(28, 10), "呼叫", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Look.SHELL_LIGHT)


# ---------------------------------------------------------------- 刷新文字和按钮

func _refresh() -> void:
	var pet := game.pet
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
	var away := pet != null and pet.away()
	for id in buttons:
		var b: Button = buttons[id]
		b.disabled = pet == null or (pet.is_over() and id != "more" and id != "status") \
			or (pet.stage == "egg" and id not in ["lights", "status", "more"]) \
			or (away and id not in ["status", "more"])
	sitter_button.text = "叫它回来" if pet != null and pet.walking() else ("接回来" if away else "托人照看")
	sitter_button.disabled = pet == null or pet.is_over() or pet.stage == "egg" or playing
	out_button.disabled = pet == null or pet.is_over() or pet.stage == "egg" or playing or away
	grid.visible = not playing
	play_bar.visible = playing
	if pet == null or dialog != null or title != null:
		return
	if not pet.wants_leave:
		_asked_leave = false
	if not pet.wants_match:
		_asked_match = false
	if pet.is_over() and not _shown_end:
		_show_ending()
	elif pet.wants_match and not _asked_match:
		_ask_match()
	elif pet.wants_leave and not _asked_leave:
		_ask_leave()
	elif pet.personality == "" and pet.stage in ["child", "teen", "adult"] and not _asked_personality and not pet.away():
		_ask_personality()


## 没有新消息的时候, 下面那行显示现在该做什么
func _hint() -> String:
	var pet := game.pet
	if pet == null or pet.is_over():
		return ""
	if pet.sitting() or pet.walking():
		return ""  # 在哪、还剩多久, 小屏幕上画着, 不再说一遍
	if pet.pest_at > 0 and not pet.asleep:
		return "有只捣蛋精在捣乱! 在屏幕上点它一下~"
	if pet.in_hotel():
		return "约好的时间记得去接它, 晚了它会生气哦"
	if pet.call != "":
		return game.describe({"kind": "call", "what": pet.call})
	if pet.sick:
		return "它生病了, 快给它吃药"
	if pet.asleep:
		return "嘘…… 它睡得正香" if not pet.lights else "它睡着了, 帮它关个灯吧"
	if pet.poop > 0:
		return "有便便! 记得打扫哦"
	if game.unread() > 0:
		return "有新的信! 在「更多」→ 信箱"
	if pet.stage == "egg":
		return "蛋在动来动去…… 快孵出来了"
	if pet.tidy == 0:
		return "它身上脏兮兮的, 按「打扫」给它洗个澡吧"
	var fest := game.festival()
	if fest != "":
		return "今天是%s, 节日快乐!" % Festivals.name_of(fest)
	return ""


func _say(text: String) -> void:
	if text == "":
		return
	message.text = text
	_msg_until = Time.get_ticks_msec() / 1000.0 + 4.0


# ---------------------------------------------------------------- 按钮

func do_action(id: String) -> void:
	if dialog != null or game.pet == null or title != null:
		return
	var text := ""
	match id:
		"feed":
			game.tick()
			if game.pet.asleep:
				text = "嘘, 它在睡觉呢"
			else:
				var options := [["饭 (免费, 饱一点)", _feed.bind("meal")], ["零食 (免费, 开心一点, 会胖)", _feed.bind("snack")]]
				for f in Items.of_kinds(["food"]):
					if int(game.items.get(f, 0)) > 0:
						options.append(["%s ×%d (%s)" % [Items.name_of(f), game.items[f], Items.food_text(f)], _feed.bind(f)])
				options.append(["算了", close_dialog])
				_dialog("喂点什么?", "" if options.size() > 3 else "想吃更好吃的? 去「更多」→ 商店看看~", options)
		"lights":
			text = game.act("lights")
		"play":
			game.tick()
			var r := game.pet.can_play()
			if r == "ok":
				_ask_play()
			else:
				text = {"asleep": "嘘, 它在睡觉呢", "sick": "它生病了, 没力气玩"}.get(r, "")
		"medicine":
			text = game.act("medicine")
			if game.last_result in ["more", "cured"]:
				screen.show_effect("medicine")
		"clean":
			text = game.act("clean")
			if game.last_result == "bath":
				screen.show_effect("bubble")
		"status":
			screen.show_status()
		"scold":
			# 第五版: 管教里有「骂它」和「夸它」(照 Connection 的管教菜单)
			_dialog("管教", "它耍小脾气的时候说说它, 做了好事的时候夸夸它~ (这两种时候呼叫灯都会闪)", [
				["骂它", _discipline.bind("scold")], ["夸它", _discipline.bind("praise")], ["算了", close_dialog]])
		"more":
			_show_menu()
		"sitter":
			text = game.act("sitter")
		"out":
			_ask_out()
	_after(text)


# ---------------------------------------------------------------- 第三版: 出门、旅馆、住的地方

func _ask_out() -> void:
	var r := game.can_go_out()
	if r != "ok":
		_say({"small": "还太小了, 长到小孩才能出门哦", "asleep": "嘘, 它在睡觉呢", "sick": "它生病了, 先把病治好吧",
			"away": "它不在家"}.get(r, ""))
		return
	var options := []
	var lines := []
	var stage: String = game.pet.stage
	if stage == "child" or stage == "teen":
		options.append(["学校", _ask_school])
		lines.append("学校: 去上课, 变聪明、变时尚、变善良")
	elif stage == "adult":
		options.append(["上班", _ask_work])
		lines.append("上班: 找份工作, 赚点魔晶")
	if game.can_visit_parents():
		options.append(["爸妈家", _go_parents])
		lines.append("爸妈家: 让爸妈帮忙带一会儿 (跟托人照看共用每天 %s), 待满 1 小时还会教它点东西" % Game.sitter_text(Rules.SITTER_PER_DAY))
	for o in Outings.LIST:
		if o.id in game.outings:
			var go: Callable = go_out.bind(o.id)
			if o.id == "hotel":
				go = _ask_hotel
			elif o.id == "food":
				go = _ask_food
			options.append([o.name, go])
			lines.append("%s: %s" % [o.name, o.help])
		else:
			lines.append("？？？: 还没解锁哦 (%s)" % o.unlock)
	options.append(["算了", close_dialog])
	_dialog("去哪儿玩?", "\n".join(lines), options)


## 第八版: 美食街挑一家店
func _ask_food() -> void:
	var options := []
	var menu := []
	for id in Outings.SHOP_ORDER:
		var d: Dictionary = Outings.SHOPS[id]
		options.append(["%s (%d 魔晶)" % [d.name, d.price], _eat_out.bind(id)])
		menu.append("%s: %s, %s" % [d.name, d.food, Items.food_text_of(d)])
	options.append(["算了", close_dialog])
	_dialog("美食街", "你有魔晶 %d。今天想吃点什么呢?\n%s" % [game.money, "\n".join(menu)], options)


func _eat_out(shop: String) -> void:
	close_dialog()
	var res := game.eat_out(shop)
	if res.get("ok", false):
		screen.show_outing("food", "", res.icon)
	_after(res.text)


## 第八版: 点到了捣蛋精
func _on_pest_tapped() -> void:
	if dialog != null or title != null or game.pet == null:
		return
	var text := game.act("shoo")
	if game.last_result == "ok":
		screen.show_effect("angry")
	_after(text)


## 第八版: 长成小孩以后选性格 (学拓麻歌子 Uni)
func _ask_personality() -> void:
	_asked_personality = true
	var options := []
	for id in Personality.ORDER:
		var d: Dictionary = Personality.LIST[id]
		options.append(["%s (%s)" % [d.name, d.help], _pick_personality.bind(id)])
	_dialog("它是什么性格?", "%s长大一点啦, 开始有自己的小脾气了~\n你觉得它是哪一种? (选了就不改了哦)" % game.pet.display_name(), options)


func _pick_personality(id: String) -> void:
	close_dialog()
	_after(game.act("personality", id))


func go_out(id: String) -> void:
	close_dialog()
	var out := game.go_out(id)
	if out.get("ok", false):
		var icon: String = out.item
		if out.get("souvenir", "") != "":
			icon = Items.SOUVENIRS[out.souvenir].icon
		screen.show_outing(id, out.npc, icon)
	_after(out.text)


# ---------------------------------------------------------------- 第五版: 上学和工作

var play_purpose := "game"   # 现在的小游戏是 game 玩 / school:科目 上课 / work 上班
var _play_version := 0


func _ask_school() -> void:
	var r := game.pet.can_study()
	if r != "ok":
		close_dialog()
		_say({"tired": "刚下课, 让它玩一会儿吧 (%s以后)" % Game.sitter_text(maxi(60, game.pet.class_at + School.CLASS_COOLDOWN - game.pet.now)),
			"asleep": "嘘, 它在睡觉呢", "sick": "它生病了, 先休息吧"}.get(r, "现在上不了课"))
		return
	var options := []
	for s in School.SUBJECTS:
		options.append(["%s (%s %d)" % [School.SUBJECTS[s].name, School.SUBJECTS[s].stat, game.pet.ability(s)], _start_class.bind(s)])
	options.append(["算了", close_dialog])
	_dialog("上什么课?", "每节课 5 道题, 答对几题就涨几点。答对 4 题以上算很认真, 记得夸夸它! 上完一节要休息一小时。", options)


func _start_class(subject: String) -> void:
	play_purpose = "school:" + subject
	start_play("quiz_" + subject)


func _ask_work() -> void:
	var p := game.pet
	if p.job == "":
		_ask_job()
		return
	var info: Dictionary = School.JOBS[p.job]
	_dialog("上班", "现在在当%s。干得好给 %d 魔晶, 手忙脚乱就给一半。上完班会累, 要歇 4 小时哦。" % [info.name, info.pay],
		[["去上班", _start_work], ["换工作", _ask_job], ["算了", close_dialog]])


func _ask_job() -> void:
	var cells := []
	for id in School.JOB_ORDER:
		var info: Dictionary = School.JOBS[id]
		var can := School.can_take(game.pet, id)
		cells.append(["%s  %d 魔晶\n要: %s" % [info.name, info.pay, School.need_text(id)], null, _take_job.bind(id), can and game.pet.job != id])
	dialog_buttons = []
	var grid_box := _button_grid(cells)
	var extra := dialog_buttons.duplicate()
	_dialog("找工作", "本事够了才能做哦。多上学、多训练, 能做的工作就多啦。", [["算了", close_dialog]], grid_box)
	dialog_buttons = extra + dialog_buttons


func _take_job(id: String) -> void:
	close_dialog()
	_after({"ok": "找到工作啦: %s! (出门 → 上班)" % School.JOBS[id].name}.get(game.take_job(id), "本事还不太够, 再练练吧"))


func _start_work() -> void:
	var r := game.pet.can_work()
	if r != "ok":
		close_dialog()
		_say({"tired": "刚下班, 让它歇会儿吧 (%s以后)" % Game.sitter_text(maxi(60, game.pet.work_at + School.WORK_COOLDOWN - game.pet.now)),
			"hungry": "肚子饿或者不开心, 上不了班", "asleep": "嘘, 它在睡觉呢", "sick": "它生病了, 先休息吧"}.get(r, "现在上不了班"))
		return
	play_purpose = "work"
	start_play(School.JOBS[game.pet.job].game, 0, game.pet.job == "doctor")


func _show_mail() -> void:
	var options := []
	for i in range(game.letters.size() - 1, -1, -1):
		var l: Dictionary = game.letters[i]
		options.append([("● " if not l.read else "") + l.title, _read_letter.bind(i)])
		if options.size() >= 6:
			break
	options.append(["关闭", close_dialog])
	_dialog("信箱", "信箱空空的。" if game.letters.is_empty() else "一共 %d 封信, 有 %d 封还没看 (● 是没看过的)" % [game.letters.size(), game.unread()], options)


func _read_letter(i: int) -> void:
	game.letters[i].read = true
	_save()
	_dialog(game.letters[i].title, game.letters[i].body, [["返回信箱", _show_mail], ["关闭", close_dialog]])


func _ask_hotel() -> void:
	var options := []
	for h in Outings.HOTEL_HOURS:
		var price: int = h * Outings.HOTEL_PRICE
		options.append(["住 %d 小时 (%d 魔晶)" % [h, price], _hotel.bind(h)])
	options.append(["算了", close_dialog])
	_dialog("旅馆", "你有魔晶 %d。\n旅馆帮你看着它, 不叫你、不算照顾失误。不过旅馆不管饭哦: 饿了或不开心会被送回家, 先喂饱、哄开心再去。\n" % game.money +
		"约好的时间记得去接 (按「接回来」), 晚了它会自己气呼呼地回来。", options)


func _hotel(hours: int) -> void:
	close_dialog()
	var r := game.hotel(hours)
	_after({"ok": "住进旅馆啦, %d 小时以后记得去接它~" % hours, "poor": "魔晶不够啦",
		"hungry": "它饿着肚子或者不开心, 旅馆不收哦, 先喂饱、哄开心再去"}.get(r, "现在去不了旅馆"))


## 在哪里养 (有好几个地方的时候, 孵新蛋先问)
func _ask_place(diff: String) -> void:
	var options := []
	for place in Species.PLACE_ORDER:
		if place in game.places:
			options.append([Species.PLACES[place].name, _new_egg.bind(diff, place)])
	_dialog("在哪里养?", "小孩长成少年的时候住在哪儿, 就会长成那里的魔物哦。宝宝和小孩到哪儿都一样。", options)


func _ask_move() -> void:
	var options := []
	for place in Species.PLACE_ORDER:
		if place in game.places:
			var here: bool = game.pet.place == place
			options.append([Species.PLACES[place].name + (" (现在住这里)" if here else ""), _move.bind(place)])
	options.append(["算了", close_dialog])
	_dialog("搬家", "小孩长成少年的时候住在哪儿, 就会长成那里的魔物哦。已经长大了的话, 搬家只是换换风景。", options)


func _move(place: String) -> void:
	close_dialog()
	var r := game.move(place)
	_after({"ok": "搬到%s啦!" % Species.PLACES[place].name, "grown": "搬到%s啦! 换换风景~" % Species.PLACES[place].name}.get(r, ""))


func _discipline(what: String) -> void:
	close_dialog()
	var text := game.act(what)
	if game.last_result in ["good", "sad"]:
		screen.show_effect("angry" if what == "scold" else "note")
	_after(text)


func _on_pet_touched() -> void:
	if dialog != null or title != null or game.pet == null:
		return
	var text := game.act("pat")
	if game.last_result in ["ok", "again"]:
		screen.show_effect("status")
	_after(text)


## 做完一个动作: 存档、刷新, 再显示这个动作的结果 (比动作顺带引起的小事要紧, 比如喂完饭它又说不开心)
func _after(text: String) -> void:
	_save()
	_refresh()
	_say(text)


# ---------------------------------------------------------------- 第四版: 训练和比赛

func _ask_train() -> void:
	var options := []
	for s in Training.STATS:
		options.append(["%s (%s %d)" % [Training.DRILLS[s][0], Training.STATS[s], game.pet.stat(s)], _train.bind(s)])
	options.append(["算了", close_dialog])
	_dialog("练什么?", "练一次涨 3 到 5 点。练完会有点饿、有点累, 要休息 30 分钟才能再练。\n" +
		"练出来的本事长大了也还在, 少年起就能去比赛啦!", options)


func _train(s: String) -> void:
	close_dialog()
	var text := game.act("train", s)
	if game.last_result == "ok":
		screen.show_effect(Training.DRILLS[s][1])
	_after(text)


func _ask_compete() -> void:
	var p := game.pet
	var options := []
	for i in Training.RANKS.size():
		if i > p.rank:
			break
		var info: Dictionary = Training.RANKS[i]
		options.append(["%s (赢了 %d 魔晶%s)" % [info.name, info.prize, "" if i < p.rank else ", 拿奖杯"], _compete.bind(i)])
	options.append(["算了", close_dialog])
	var st := p.stats()
	_dialog("比赛", "力气 %d  速度 %d  防御 %d\n比赛是自动对打的: 力气大打得疼, 速度快先出手、还容易躲开, 防御高血多、挨打不疼。\n" % [st.power, st.speed, st.guard] +
		"赢了升一级、拿奖杯, 输了也有一点魔晶。比完会累, 要休息 3 小时。", options)


var _battle_text := ""


func _compete(level: int) -> void:
	close_dialog()
	var res := game.compete(level)
	if res.has("error"):
		_after(res.text)
		return
	screen.show_battle(res)
	_battle_text = res.text
	_after("%s开始!" % Training.RANKS[level].name)


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
	# 第六版小游戏多了, 改成一格一格的 (三列), 按了再在屏幕下面那行说怎么玩
	var cells := []
	for id in MiniGames.unlocked(game.pet.stage):
		cells.append([MiniGames.info(id).name, null, start_play.bind(id), true])
	if game.pet.stage != "baby":
		cells.append(["训练", null, _ask_train, true])
	if game.pet.stage in ["teen", "adult"]:
		cells.append(["比赛", null, _ask_compete, true])
	for toy in Items.of_kinds(["toy"]):
		if toy in game.owned:
			var wait := game.toy_wait(toy)
			cells.append(["玩%s%s" % [Items.name_of(toy), "" if wait == 0 else "\n(%s后)" % Game.sitter_text(wait)], null,
				_play_toy.bind(toy), true])
	dialog_buttons = []
	var grid_box := _button_grid(cells, 3)
	var extra := dialog_buttons.duplicate()
	_dialog("玩什么?", "玩小游戏能赚魔晶哦~" + (" 长大了还会有新的小游戏!" if game.pet.stage != "adult" else ""), [["算了", close_dialog]], grid_box)
	dialog_buttons = extra + dialog_buttons


func start_play(id: String, rng_seed := 0, hard := false) -> void:
	close_dialog()
	if not id.begins_with("quiz_") and play_purpose.begins_with("school"):
		play_purpose = "game"
	screen.start_play(id, rng_seed, hard)
	_build_play_row()
	_refresh()


## 小游戏下面的按钮 (答题换题的时候重做一次)
func _build_play_row() -> void:
	for b in play_row.get_children():
		play_row.remove_child(b)
		b.queue_free()
	var g := screen.minigame
	_play_version = g.buttons_version
	var list := g.buttons()
	var w := (660.0 - 16.0 * (list.size() - 1)) / list.size()
	for a in list:
		var b := Button.new()
		b.text = a[1]
		b.custom_minimum_size = Vector2(w, 200)
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 40 if g.id.find("quiz") < 0 else 30)
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
	var text := ""
	if play_purpose.begins_with("school:"):
		text = game.act("study", {"subject": play_purpose.trim_prefix("school:"), "correct": g.score})
	elif play_purpose == "work":
		text = game.act("work", g.won())
	else:
		text = game.act("game", {"won": g.won(), "reward": g.reward()})
	play_purpose = "game"
	if game.last_result == "won":
		screen.show_effect("note")
	_after(text)


## 玩到一半不玩了: 不算输赢, 不给魔晶, 也不减体重 (上课、上班也是: 这次不算)
func quit_play() -> void:
	screen.stop_play()
	play_purpose = "game"
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
		if body.length() > 300:
			# 字太多 (比如「怎么玩」): 放进能上下滑的框里, 不把弹窗顶出屏幕 (第八版截图才发现以前就顶出去了)
			var scroll := ScrollContainer.new()
			scroll.custom_minimum_size = Vector2(600, 760)
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.add_child(text)
			box.add_child(scroll)
		else:
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
	_dialog("选难度", "放宽 (推荐): 心掉得慢一半, 它叫你以后 2 小时内去照顾就行。失误多了也不会死, " +
		"只要别一整天不管它。隔几个小时看一眼就好~\n\n" +
		"原版严格 (挑战): 跟 1996 年的原版一样! 它叫你以后 15 分钟没理就算一次失误 " +
		"(不是要你每 15 分钟看一次哦)。成年以后失误 5 次、一个阶段病 3 次都会死, 最好每小时看一眼。隐藏的魔物只有这个难度养得出来。\n\n" +
		"两种都能「托人照看」: 上学、上班的时候托给别人, 每天最多 %s。" % Game.sitter_text(Rules.SITTER_PER_DAY),
		[["放宽 (推荐)", _choose_difficulty.bind(Rules.EASY)], ["原版严格 (挑战)", _choose_difficulty.bind(Rules.STRICT)]])


func _choose_difficulty(diff: String) -> void:
	if game.places.size() > 1:
		_ask_place(diff)
	else:
		_new_egg(diff)


func _new_egg(diff: String, place := "grass", genes := {}) -> void:
	close_dialog()
	game.new_egg(diff, -1, place, genes)
	screen.mode = "pet"
	screen.pet_x = 16.0
	_shown_end = false
	_asked_leave = false
	_asked_match = false
	_asked_personality = false
	_save()
	_refresh()


func _show_ending() -> void:
	_shown_end = true
	var pet := game.pet
	var head := "%s 出发了" % pet.display_name() if pet.stage == "gone" else "再见了, %s" % pet.display_name()
	if pet.end_reason == "married":
		head = "%s 结婚了" % pet.display_name()
	var options := [["孵一颗新蛋", _ask_difficulty], ["先看看", close_dialog]]
	var more := ""
	if not game.next_egg.is_empty():
		# 第七版: 结婚生的、老死留下的蛋 (孩子长成哪一种还是看照顾, 颜色和头上的特征遗传)
		options = [["孵这颗蛋 (第 %d 代)" % game.next_egg.gen, _hatch_next_egg], ["换一颗新蛋 (这颗就不要了)", _ask_difficulty],
			["先看看", close_dialog]]
		more = "\n\n这颗蛋长成哪一种, 还是看你照顾得好不好; 身上的颜色和头上的「%s」是从爸妈那儿遗传来的哦。" % \
			Genes.FEATURES.get(game.next_egg.feature, "")
	_dialog(head, "%s\n它活了 %d 岁, 已经记进图鉴啦。%s" % [Game.ending_text(pet.end_reason), pet.age(), more], options)


## 孵留下的那颗蛋: 难度、住的地方跟上一代一样
func _hatch_next_egg() -> void:
	_new_egg(game.pet.difficulty, game.pet.place, game.next_egg)


## 第七版: 媒人上门, 介绍三位对象 (学拓麻歌子 Connection)
func _ask_match() -> void:
	_asked_match = true
	var cells := []
	for i in game.pet.match_offers.size():
		var o: Dictionary = game.pet.match_offers[i]
		cells.append(["%s\n头上: %s" % [Species.name_of(o.species), Genes.FEATURES.get(o.feature, "")], Art.look_texture(o, 4),
			_answer_match.bind(i), true])
	dialog_buttons = []
	var grid_box := _button_grid(cells)
	var extra := dialog_buttons.duplicate()
	_dialog("媒人来了", "叮咚~ 媒人带着几位对象来看「%s」啦!\n挑一位结婚, 会生下一颗蛋, 两口子就搬去爸妈家住 (忙的时候能把孩子送过去)。" % game.pet.display_name() +
		"孩子长成哪一种还是看你照顾, 颜色和头上的小特征从爸妈那儿遗传。\n还不想结婚也没关系, 媒人过一天再来。",
		[["现在还不想结婚", _answer_match.bind(-1)]], grid_box)
	dialog_buttons = extra + dialog_buttons


func _answer_match(i: int) -> void:
	close_dialog()
	_after(game.act("match", i))


func _go_parents() -> void:
	close_dialog()
	_after(game.act("parents"))


func _ask_leave() -> void:
	_asked_leave = true
	_dialog("它想出去闯荡", "%s长大了, 想出去看看外面的世界。\n\n放它走: 它会背上小包出发 (记进图鉴)。\n留下来: 它继续陪着你, 一直到老。" %
		game.pet.display_name(), [["放它走", _answer_leave.bind(true)], ["留下来", _answer_leave.bind(false)]])


func _answer_leave(let_go: bool) -> void:
	close_dialog()
	_after(game.act("leave", let_go))


func _show_menu() -> void:
	var mail := "信箱" + (" (%d 封新信)" % game.unread() if game.unread() > 0 else "")
	var options := [["商店", _show_shop], ["装扮", _show_dress], ["图鉴", _show_dex], ["纪念品", _show_souvenirs], [mail, _show_mail],
		["怎么玩", _show_help]]
	if game.places.size() > 1 and game.pet != null and not game.pet.is_over():
		options.insert(2, ["搬家", _ask_move])
	if game.pet != null and game.pet.is_over():
		if not game.next_egg.is_empty():
			options.append(["孵留下的那颗蛋 (第 %d 代)" % game.next_egg.gen, _hatch_next_egg])
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
func _button_grid(items: Array, columns := 2) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	for it in items:
		var b := Button.new()
		b.text = it[0]
		if it[1] != null:
			b.icon = it[1]
		b.custom_minimum_size = Vector2(290, 96) if columns == 2 else Vector2(188, 84)
		b.add_theme_font_size_override("font_size", 24 if columns == 2 else 26)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT if columns == 2 else HORIZONTAL_ALIGNMENT_CENTER
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # 字太长就换行, 不把弹窗撑出屏幕
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
	_dialog("商店", "欢迎光临~ 你有魔晶 %d。\n饭、零食、药一直免费, 这里卖的是更好吃的、好玩的和好看的。" % game.money, options)


func _show_shop_page(category: String) -> void:
	var kinds: Array = []
	for c in Items.SHOP:
		if c[0] == category:
			kinds = c[1]
	var cells := []
	var fest := game.festival()
	for id in Items.of_kinds(kinds):
		var d: Dictionary = Items.DATA[id]
		if d.has("festival") and d.festival != fest:
			continue  # 第六版: 节日的吃的只在过节那天卖
		var line := "%s  %d 魔晶" % [d.name, d.price]
		if d.has("festival"):
			line = "%s (限定)  %d 魔晶" % [d.name, d.price]
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
	_say({"ok": "买了%s!" % Items.name_of(id), "poor": "魔晶不够啦, 去玩几局小游戏再来吧", "have": "已经有啦",
		"full": "%s已经放满啦" % Items.name_of(id)}[r])
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
	_dialog("装扮", "打扮得漂漂亮亮的~ (只是好看, 不影响别的)" + ("" if any else "\n还什么都没有, 先去商店逛逛吧。"), options)


func _show_dress_slot(slot: String, slot_name: String) -> void:
	var cells := [["不要了", null, _set_equip.bind(slot, ""), game.equip.has(slot)]]
	for id in Items.of_kinds([slot]):
		if id in game.owned:
			var on: bool = game.equip.get(slot, "") == id
			cells.append([Items.name_of(id) + (" (现在用的)" if on else ""), item_icon(id), _set_equip.bind(slot, id), not on])
	dialog_buttons = []
	var grid_box := _button_grid(cells)
	var extra := dialog_buttons.duplicate()
	_dialog(slot_name, "" if cells.size() > 1 else "还没有哦, 去商店看看吧。", [["返回", _show_dress], ["关闭", close_dialog]], grid_box)
	dialog_buttons = extra + dialog_buttons


func _set_equip(slot: String, id: String) -> void:
	game.set_equip(slot, id)
	_save()
	_show_dress()


func _show_dex() -> void:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	var found := 0
	var groups := [["宝宝和小孩", ["tuanzi", "jianjiao"], ""]]
	for place in Species.PLACE_ORDER:
		var d: Dictionary = Species.PLACES[place]
		groups.append([d.name, [d.teen_good, d.teen_bad, d.best, d.good, d.mid, d.low, d.bad1, d.bad2, d.secret], place])
	for grp in groups:
		var head := Label.new()
		head.text = grp[0] + ("" if grp[2] == "" or grp[2] in game.places else " (还没去过)")
		head.add_theme_font_size_override("font_size", 28)
		head.add_theme_color_override("font_color", Look.SHELL_LIGHT)
		list.add_child(head)
		var g := GridContainer.new()
		g.columns = 3
		g.add_theme_constant_override("h_separation", 16)
		g.add_theme_constant_override("v_separation", 10)
		for id in grp[1]:
			var seen := game.dex.has(id)
			if seen:
				found += 1
			var cell := VBoxContainer.new()
			cell.custom_minimum_size = Vector2(186, 0)
			var pic := TextureRect.new()
			pic.texture = Art.texture(id, 5, Color.WHITE if seen else Color(0.15, 0.13, 0.2))
			pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			pic.custom_minimum_size = Vector2(80, 80)
			cell.add_child(pic)
			var name_label := Label.new()
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.add_theme_font_size_override("font_size", 22)
			if seen:
				name_label.text = "%s ×%d" % [Species.name_of(id), game.dex[id]]
			else:
				name_label.text = "？？？" + (" (隐藏)" if Species.DATA[id].get("secret", false) else "")
				name_label.add_theme_color_override("font_color", Look.TEXT_DIM)
			cell.add_child(name_label)
			g.add_child(cell)
		list.add_child(g)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 760)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(list)
	var cups := []
	for i in Training.RANK_NAMES.size():
		if int(game.trophies.get(i, 0)) > 0:
			cups.append("%s ×%d" % [Training.RANK_NAMES[i], game.trophies[i]])
	_dialog("图鉴 %d/%d" % [found, Species.ORDER.size()], "一共养过 %d 只啦。隐藏的魔物只有「原版严格」养得出来哦。\n奖杯: %s" %
		[game.history.size(), "、".join(cups) if not cups.is_empty() else "还没有"], [["关闭", close_dialog]], scroll)


## 第六版: 纪念品柜 (有的亮着, 没有的是黑影, 写着在哪里能得到)
func _show_souvenirs() -> void:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 10)
	var have := 0
	for id in Items.SOUVENIRS:
		var d: Dictionary = Items.SOUVENIRS[id]
		var got := int(game.souvenirs.get(id, 0))
		if got > 0:
			have += 1
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(186, 0)
		var pic := TextureRect.new()
		pic.texture = Art.texture(d.icon, 7, Color.WHITE if got > 0 else Color(0.15, 0.13, 0.2))
		pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		pic.custom_minimum_size = Vector2(80, 64)
		cell.add_child(pic)
		var name_label := Label.new()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 22)
		if got > 0:
			name_label.text = "%s ×%d" % [d.name, got] if got > 1 else d.name
		else:
			name_label.text = "？？？\n(%s)" % d.from
			name_label.add_theme_color_override("font_color", Look.TEXT_DIM)
		cell.add_child(name_label)
		g.add_child(cell)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 700)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(g)
	_dialog("纪念品 %d/%d" % [have, Items.SOUVENIRS.size()], "出门玩的时候, 有时会带回那里的纪念品; 过节那天打开游戏, 也会收到节日的纪念品哦。",
		[["关闭", close_dialog]], scroll)


func _show_help() -> void:
	_dialog("怎么玩", "你的魔物会跟着真实的时间慢慢长大, 一天长一岁哦。\n\n" +
		"它饿了、不开心、耍小脾气、睡着了没关灯的时候, 上面的「呼叫」灯会一闪一闪。" +
		"没及时照顾就算一次失误, 失误多少会决定它长成哪一种。\n\n" +
		"喂食: 饭让它吃饱, 零食让它开心 (吃多了会胖)\n" +
		"玩耍: 玩小游戏赚魔晶, 还能训练、去比赛\n" +
		"吃药: 头上冒小骷髅, 就是生病啦\n" +
		"打扫: 扫便便; 没便便的时候就是给它洗澡\n" +
		"管教: 耍小脾气时说说它, 做了好事时夸夸它\n" +
		"状态: 名片、心情、本事、学习, 按一下翻一页\n" +
		"用手指点点它, 就是摸摸它~\n\n" +
		"出门: 公园、美食街、学校、上班、旅馆…… 有的地方要先解锁\n" +
		"托人照看: 上学、上班的时候托给别人, 每天最多 %s\n" % Game.sitter_text(Rules.SITTER_PER_DAY) +
		"更多: 商店、装扮、图鉴、纪念品、信箱\n\n" +
		"它有时会自己溜出去散步; 有捣蛋精来捣乱的话, 在屏幕上点它一下就跑啦。过节那天打开游戏有礼物哦!\n" +
		"长大以后, 媒人会上门介绍对象, 结婚会生下一颗蛋。它也可能想出去闯荡, 放不放它走由你决定。",
		[["知道了", close_dialog]])
