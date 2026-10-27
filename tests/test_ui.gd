extends TestCase
## 画面: 打开游戏选难度、喂饭、看状态、玩小游戏、开关灯、图鉴、它想离开时弹窗、结局以后孵新蛋;
## 最后让电脑在画面上乱按一千多下。存档写到临时文件夹, 不碰真的存档; 时间钉住, 不看真的钟。

const T0 := Helpers.T0

var main: Node
var rng := RandomNumberGenerator.new()


func before_each() -> void:
	SaveGame.dir = OS.get_temp_dir().path_join("monster_pet_test_ui_%d" % OS.get_process_id())
	SaveGame.erase()
	main = load("res://scenes/main.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	main.game.use_system_tz = false
	main.game.tz = 0
	main.game.fixed_time = T0
	rng.seed = 20261025


func after_each() -> void:
	main.free()
	SaveGame.erase()
	DirAccess.remove_absolute(SaveGame.dir)


func _start(diff_button := 0) -> void:
	check(main.title != null, "打开先是开始界面")
	main.start_game()
	check(main.dialog != null, "第一次玩, 按了开始先选难度")
	main.choose(diff_button)
	main.game.pet.tz = 0


## 按弹窗里字是这样开头的按钮
func _pick(text: String) -> void:
	for i in main.dialog_buttons.size():
		if main.dialog_buttons[i].text.begins_with(text):
			main.choose(i)
			return
	check(false, "没有「%s」按钮" % text)


func _button_texts() -> Array:
	var texts := []
	for b in main.dialog_buttons:
		texts.append(b.text)
	return texts


## 状态第一页 (名片) 上的字
func _card() -> String:
	return " ".join(main.screen.card_lines(main.game.pet))


func _later(seconds: int) -> void:
	main.game.offset += seconds
	main.game.tick()
	main._asked_personality = true  # 第八版: 长成小孩会问性格, 别的测试不管这个 (test_pick_personality 专门测)
	main._refresh()


func test_title_screen() -> void:
	check(main.title != null, "打开游戏先看到开始界面")
	eq(main.title.start_button.text, "开始", "还没养过: 「开始」")
	main.do_action("feed")
	check(main.dialog == null, "开始界面盖着, 后面的按钮按不到")
	main.title.help_button.pressed.emit()
	check(main.dialog != null, "开始界面能看「怎么玩」")
	main.close_dialog()
	main.title.start_button.pressed.emit()
	check(main.title == null, "按了开始, 开始界面没了")
	check(main.dialog != null, "接着选难度")


func test_title_says_continue_when_raising_one() -> void:
	main.game.fixed_time = -1  # 这一条用真的钟: 再打开的那一个读存档时也是看真的钟
	_start()
	_later(6 * 60)
	main.game.save()
	var again = load("res://scenes/main.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(again)
	has_text(again.title.start_button.text, "继续养「小团子」", "再打开: 继续养")
	again.start_game()
	check(again.dialog == null, "继续养不用再选难度")
	eq(again.game.pet.species, "tuanzi")
	again.free()


func test_first_open_asks_difficulty_and_lays_an_egg() -> void:
	_start(1)
	check(main.dialog == null)
	eq(main.game.pet.stage, "egg")
	eq(main.game.pet.difficulty, Rules.STRICT, "第二个按钮是原版严格")
	check(main.buttons.feed.disabled, "还是蛋的时候不能喂")
	check(not main.buttons.lights.disabled)
	has_text(main.message.text, "孵出来")
	check(FileAccess.file_exists(SaveGame.path()), "选完就存档了 (存在临时文件夹)")


func test_hatch_and_feed() -> void:
	_start()
	_later(6 * 60)
	eq(main.game.pet.stage, "baby")
	check(not main.buttons.feed.disabled)
	has_text(main.message.text, "孵出来")
	main.do_action("feed")
	check(main.dialog != null, "喂食先问喂什么")
	main.choose(0)
	eq(main.game.pet.hunger, 1, "喂了饭")
	has_text(main.message.text, "吃了饭")
	eq(main.screen.effect, "meal", "旁边冒出饭碗")
	main.do_action("feed")
	main.choose(1)
	eq(main.game.pet.happy, 1, "喂了零食")


func test_status_and_lights_and_clean() -> void:
	_start()
	_later(6 * 60)
	main.do_action("status")
	eq(main.screen.mode, "status")
	eq(main.screen.status_page, 1, "第一页是名片 (照拓麻歌子)")
	var card := _card()
	for word in ["小团子", "0 岁", "住在草原", "放宽", "魔晶 30"]:
		has_text(card, word)
	main.do_action("status")
	eq(main.screen.status_page, 2, "第二页: 饿、开心、干净、管教")
	main.do_action("status")
	eq(main.screen.status_page, 3, "第三页: 本事")
	main.do_action("status")
	eq(main.screen.status_page, 4, "第四页: 聪明时尚善良、工作")
	main.do_action("status")
	eq(main.screen.mode, "pet", "按第五次回去")
	main.do_action("lights")
	check(not main.game.pet.lights, "关灯了")
	main.do_action("lights")
	check(main.game.pet.lights)
	main.do_action("clean")
	has_text(main.message.text, "很干净")


func test_play_the_guessing_game() -> void:
	_start()
	_later(6 * 60)
	main.do_action("play")
	check(main.dialog != null, "先问玩什么")
	eq(_button_texts(), ["猜左右", "猜数字", "跳绳", "爬高", "算了"], "宝宝的四个小游戏 (第六版多了三个), 加一个「算了」")
	_pick("猜左右")
	eq(main.screen.mode, "play")
	check(main.play_bar.visible and not main.grid.visible, "玩的时候换成左右两个按钮")
	eq(main.play_row.get_child_count(), 2)
	var g: GuessGame = main.screen.minigame
	for i in GuessGame.ROUNDS:
		g.turn = 0  # 不等动画
		main.play_press("left" if i % 2 == 0 else "right")
	g.step(1.0)
	check(g.done)
	var before: int = main.game.money
	main._process(0.0)
	eq(main.screen.mode, "pet", "玩完自己回去")
	eq(main.game.money, before + g.reward(), "赚了魔晶")
	check(main.message.text.contains("赢啦") or main.message.text.contains("输了"), main.message.text)
	check(main.grid.visible)


func test_quit_a_game_halfway() -> void:
	_start()
	_later(6 * 60)
	var w: int = main.game.pet.weight
	main.do_action("play")
	main.choose(0)
	main.quit_play()
	eq(main.screen.mode, "pet")
	eq(main.game.pet.weight, w, "不玩了不减体重")
	check(main.grid.visible)


func test_menu_dex_and_help() -> void:
	_start()
	_later(6 * 60)
	main.do_action("more")
	var texts := []
	for b in main.dialog_buttons:
		texts.append(b.text)
	check("图鉴" in texts)
	check(texts.any(func(s): return s.begins_with("快进")), "调试版有快进")
	main.choose(texts.find("图鉴"))
	check(main.dialog != null)
	main.close_dialog()
	main.do_action("more")
	main.choose(texts.find("快进 1 小时 (试玩用)"))
	eq(main.game.offset, 6 * 60 + 3600, "快进了一小时")
	eq(main.game.pet.stage, "child", "宝宝一小时就长成小孩")


func test_leaving_and_new_egg() -> void:
	_start()
	_later(6 * 60)
	var p: Pet = main.game.pet
	p.wants_leave = true
	main._refresh()
	check(main.dialog != null, "它想离开时弹窗问你")
	main.choose(1)
	check(not main.game.pet.is_over(), "留下来")
	has_text(main.message.text, "留下来")
	p.wants_leave = true
	main._asked_leave = false
	main._refresh()
	main.choose(0)
	eq(main.game.pet.stage, "gone", "放它走")
	main._refresh()
	check(main.dialog != null, "结局弹窗")
	main.choose(0)
	check(main.dialog != null, "孵新蛋先选难度")
	main.choose(0)
	eq(main.game.pet.stage, "egg", "新的蛋")
	eq(main.game.history.size(), 1, "上一只记下来了")


func test_sitter_button() -> void:
	_start()
	check(main.sitter_button.disabled, "蛋不用托人照看")
	_later(6 * 60)
	eq(main.sitter_button.text, "托人照看")
	main.do_action("sitter")
	check(main.game.pet.sitting())
	eq(main.sitter_button.text, "接回来")
	has_text(main.message.text, "还能托")
	has_text(_card(), "托人照看中", "状态的名片上写着在哪")
	check(main.buttons.feed.disabled, "托出去了不能喂")
	check(not main.buttons.more.disabled)
	_later(3600)
	eq(main._hint(), "", "还剩多久画在小屏幕上, 下面那行不再说一遍 (第七版, 用户嫌重复)")
	main.do_action("sitter")
	check(not main.game.pet.sitting(), "接回来了")
	check(not main.buttons.feed.disabled)


func test_difficulty_text_explains_the_fifteen_minutes() -> void:
	main.start_game()
	check(main.dialog_buttons[0].text.contains("推荐"), "放宽标了推荐")
	check(main.dialog_buttons[1].text.contains("原版严格"))


func test_shop_and_dress_up() -> void:
	_start()
	_later(6 * 60)
	main.game.money = 500
	main.do_action("more")
	main.choose(0)  # 商店
	has_text(main.dialog.get_child(0).get_child(0).get_child(1).text, "500", "商店里写着有多少魔晶")
	_pick("衣服配饰")
	main.choose(0)  # 第一样: 草帽
	check("strawhat" in main.game.owned, "买了草帽")
	eq(main.game.money, 450)
	eq(main.game.equip.get("hat", ""), "strawhat", "第一次买帽子直接戴上")
	check(main.dialog_buttons[0].disabled, "已经有了不能再买")
	main.close_dialog()
	main.do_action("more")
	_pick("装扮")
	_pick("帽子")
	main.choose(0)  # 不要了
	check(not main.game.equip.has("hat"), "摘下了帽子")
	main.close_dialog()
	main.do_action("more")
	main.choose(0)
	_pick("吃的")
	main.choose(0)  # 苹果
	eq(int(main.game.items.get("apple", 0)), 1)
	main.close_dialog()
	main.do_action("feed")
	var texts := []
	for b in main.dialog_buttons:
		texts.append(b.text)
	check(texts.any(func(s): return s.begins_with("苹果")), "喂食里多了苹果: %s" % [texts])
	main.choose(2)
	eq(int(main.game.items.get("apple", 0)), 0, "吃掉了")


func test_toys_in_play_menu() -> void:
	_start()
	_later(6 * 60)
	main.game.owned.append("ball")
	main.game.pet.happy = 1
	main.do_action("play")
	_pick("玩皮球")
	eq(main.game.pet.happy, 2, "玩皮球开心 +1")
	main.do_action("play")
	var texts := _button_texts()
	has_text(texts[texts.size() - 2], "小时后", "刚玩过要等一会儿 (玩具在最后, 「算了」前面)")


func test_child_play_menu() -> void:
	_start()
	_later(6 * 60 + 3600)
	eq(main.game.pet.stage, "child")
	main.do_action("play")
	eq(_button_texts(), ["猜左右", "猜数字", "跳绳", "爬高", "接果子", "拔河", "模仿", "训练", "算了"],
		"小孩: 宝宝的四个 + 接果子、拔河、模仿, 还有训练, 加「算了」")
	_pick("接果子")
	eq(main.screen.minigame.id, "catch")
	check(main.screen.minigame.hold_buttons())
	main._process(0.1)
	has_text(main.message.text, "接住", "玩的时候下面那行显示分数")


func _feed_up() -> void:
	main.game.pet.hunger = 4
	main.game.pet.happy = 4
	main.game.pet._settle()


func test_baby_cannot_go_out() -> void:
	_start()
	_later(6 * 60)
	main.do_action("out")
	check(main.dialog == null, "宝宝不能出门")
	has_text(main.message.text, "太小")


func test_going_out_to_the_park() -> void:
	_start()
	_later(6 * 60 + 3600)
	_feed_up()
	main.do_action("out")
	check(main.dialog != null, "问去哪儿")
	eq(main.dialog_buttons[0].text, "学校", "小孩先是学校")
	eq(main.dialog_buttons[1].text, "公园")
	eq(main.dialog_buttons[2].text, "美食街", "第八版多了美食街")
	eq(main.dialog_buttons[3].text, "旅馆")
	main.choose(1)
	eq(main.screen.mode, "out", "屏幕上看它在公园逛")
	check(Species.DATA.has(main.screen.out_npc), "碰到了一只魔物")
	has_text(main.message.text, "公园")
	main.screen._process(4.0)
	eq(main.screen.mode, "pet", "几秒钟就回来")


func test_hotel_from_the_out_menu() -> void:
	_start()
	_later(6 * 60 + 3600)
	_feed_up()
	main.game.money = 100
	main.do_action("out")
	_pick("旅馆")
	has_text(main.dialog.get_child(0).get_child(0).get_child(1).text, "不管饭")
	main.choose(0)  # 住 2 小时
	check(main.game.pet.in_hotel())
	eq(main.game.money, 100 - 2 * Outings.HOTEL_PRICE)
	eq(main.sitter_button.text, "接回来")
	check(main.buttons.feed.disabled, "住旅馆不能喂")
	check(main.out_button.disabled)
	has_text(_card(), "住旅馆")
	main.do_action("sitter")
	check(not main.game.pet.in_hotel(), "接回来了")


func test_choose_where_to_raise_the_next_egg() -> void:
	_start()
	_later(6 * 60)
	main.game.places.append("lake")
	main.game.pet.wants_leave = true
	main.game.pet.answer_leave(true)
	main.game._take_events()
	main._refresh()
	main.choose(0)  # 孵一颗新蛋
	main.choose(0)  # 放宽
	check(main.dialog != null, "有好几个地方, 先问在哪里养")
	eq(main.dialog_buttons[1].text, "湖泊")
	main.choose(1)
	eq(main.game.pet.place, "lake")
	eq(main.game.pet.stage, "egg")
	main.do_action("more")
	var texts := []
	for b in main.dialog_buttons:
		texts.append(b.text)
	check("搬家" in texts, "更多里有搬家")


func test_training_from_the_play_menu() -> void:
	_start()
	_later(6 * 60 + 3600)
	_feed_up()
	main.do_action("play")
	_pick("训练")
	has_text(main.dialog.get_child(0).get_child(0).get_child(0).text, "练什么")
	main.choose(0)  # 举重
	check(main.game.pet.power >= 3, "力气涨了")
	has_text(main.message.text, "力气 +")
	eq(main.screen.effect, "dumbbell")


func test_tournament_plays_a_battle() -> void:
	_start()
	_later(6 * 60)
	var p: Pet = main.game.pet
	p.hatched_at = p.now
	p._become("huolong")
	p.power = 80
	p.speed = 80
	p.guard = 80
	_feed_up()
	main.game._take_events()
	main.do_action("play")
	var texts := []
	for b in main.dialog_buttons:
		texts.append(b.text)
	var at := texts.find("比赛")
	check(at >= 0, "成年的玩耍里有比赛: %s" % [texts])
	main.choose(at)
	main.choose(0)  # 新手赛
	eq(main.screen.mode, "battle", "屏幕上开始对打")
	has_text(main.message.text, "开始")
	for i in 60:
		main.screen._process(0.5)
		main._process(0.0)
	eq(main.screen.mode, "pet", "打完回去")
	has_text(main.message.text, "新手赛", "打完说结果")
	eq(main.game.pet.rank, 1)


func test_going_to_class() -> void:
	_start()
	_later(6 * 60 + 3600)
	_feed_up()
	main.do_action("out")
	main.choose(0)  # 学校
	has_text(main.dialog.get_child(0).get_child(0).get_child(0).text, "上什么课")
	main.choose(0)  # 数学课
	eq(main.screen.mode, "play")
	eq(main.play_purpose, "school:smart")
	var q: QuizGame = main.screen.minigame
	eq(main.play_row.get_child_count(), 3, "三个选项三个按钮")
	for i in 5:
		var right: int = q.question().answer
		eq(main.play_row.get_child(right).text, q.question().options[right], "按钮上是选项")
		main.play_press(str(right))
		q.step(1.0)
		main._process(0.0)
		if main.screen.mode != "play":
			break
	eq(main.screen.mode, "pet", "五题答完下课")
	eq(main.game.pet.smart, 5, "全答对, 聪明 +5")
	has_text(main.message.text, "数学课")
	eq(main.game.pet.call, "good", "很认真, 该夸了")
	main.do_action("scold")
	main.choose(1)  # 夸它
	eq(main.game.pet.kind, 2, "夸了它, 善良 +2")


func test_finding_a_job_and_working() -> void:
	_start()
	_later(6 * 60)
	var p: Pet = main.game.pet
	p.hatched_at = p.now
	p._become("huolong")
	_feed_up()
	main.game._take_events()
	main.do_action("out")
	eq(main.dialog_buttons[0].text, "上班", "成年先是上班")
	main.choose(0)
	has_text(main.dialog.get_child(0).get_child(0).get_child(0).text, "找工作", "还没工作先找工作")
	check(not main.dialog_buttons[0].disabled, "杂工谁都能做")
	check(main.dialog_buttons[6].disabled, "医生本事不够")
	main.choose(0)
	eq(p.job, "helper")
	main.do_action("out")
	main.choose(0)
	main.choose(0)  # 去上班
	eq(main.play_purpose, "work")
	eq(main.screen.minigame.id, "guess", "杂工上班玩猜左右")
	var m: int = main.game.money
	var g: GuessGame = main.screen.minigame
	for i in 5:
		g.turn = 0
		main.play_press("left")
	g.step(1.0)
	main._process(0.0)
	eq(main.screen.mode, "pet")
	check(main.game.money == m + 15 or main.game.money == m + 7, "上班赚了魔晶 (%d)" % (main.game.money - m))
	has_text(main.message.text, "下班")


func test_petting_by_touching() -> void:
	_start()
	_later(6 * 60)
	main.game.pet.happy = 1
	main.screen.pet_x = 16
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = Vector2(24, 22) * main.screen.px()
	main.screen._gui_input(e)
	eq(main.game.pet.happy, 2, "点它一下, 摸摸它, 开心 +1")
	main.screen._gui_input(e)
	eq(main.game.pet.happy, 2, "摸得太勤, 只是蹭蹭")
	e.position = Vector2(2, 2) * main.screen.px()
	main.game.pet.patted_at = -999999
	main.screen._gui_input(e)
	eq(main.game.pet.happy, 2, "点到旁边不算")


func test_mailbox() -> void:
	_start()
	_later(6 * 60)
	main.game.add_letter("测试的信", "信里的话")
	main._refresh()
	main.do_action("more")
	var texts := []
	for b in main.dialog_buttons:
		texts.append(b.text)
	check(texts.any(func(s): return s.begins_with("信箱 (1 封新信)")), "更多里有信箱, 写着新信: %s" % [texts])
	main.choose(texts.find("信箱 (1 封新信)"))
	main.choose(0)
	has_text(main.dialog.get_child(0).get_child(0).get_child(1).text, "信里的话")
	eq(main.game.unread(), 0, "看过了")


func test_buttons_off_after_the_end() -> void:
	_start()
	_later(6 * 60)
	main.game.pet._end("neglect")
	main.game._take_events()
	main._refresh()
	main.close_dialog()
	main._refresh()
	check(main.buttons.feed.disabled)
	check(not main.buttons.more.disabled, "「更多」还能按 (孵新蛋)")


func test_random_tapping() -> void:
	_start()
	var ids := ["feed", "lights", "play", "medicine", "clean", "status", "scold", "more", "sitter", "out"]
	for i in 1500:
		var r := rng.randf()
		if main.dialog != null:
			if not main.dialog_buttons.is_empty():
				main.choose(rng.randi() % main.dialog_buttons.size())
			else:
				main.close_dialog()
		elif main.screen.mode == "play":
			var g: MiniGame = main.screen.minigame
			var b: Array = g.buttons()
			main.play_press(b[rng.randi() % b.size()][0])
			if rng.randf() < 0.3:
				main.play_release(b[rng.randi() % b.size()][0])
			g.step(rng.randf_range(0.1, 2.0))
			if rng.randf() < 0.03:
				main.quit_play()
		elif r < 0.6:
			main.do_action(ids[rng.randi() % ids.size()])
		else:
			_later(rng.randi_range(60, 3 * 3600))
		main.screen._process(0.3)
		main._process(0.3)
		if main.game.pet != null:
			var p: Pet = main.game.pet
			check(p.hunger >= 0 and p.hunger <= 4 and p.happy >= 0 and p.happy <= 4, "第 %d 下: 心在范围里" % i)
		if failures.size() > 10:
			return
	check(main.game.history.size() >= 1, "乱按了这么久, 至少结束过一只 (实际 %d 只)" % main.game.history.size())


func test_matchmaker_marriage_and_next_generation() -> void:
	_start()
	_later(6 * 60)
	var p: Pet = main.game.pet
	p.hatched_at = p.now
	p._become("huolong")
	_feed_up()
	main.game._take_events()
	_later(Rules.MATCH_AFTER + 60)
	_feed_up()
	check(main.game.pet.wants_match, "成年一天后媒人来了")
	main._refresh()
	check(main.dialog != null, "弹出媒人的弹窗")
	has_text(main.dialog.get_child(0).get_child(0).get_child(0).text, "媒人")
	var texts := _button_texts()
	eq(texts.size(), Genes.OFFERS + 1, "三位对象 + 「现在还不想结婚」: %s" % [texts])
	has_text(texts[0], "头上")
	main.choose(0)
	eq(main.game.pet.end_reason, "married")
	check(main.dialog != null, "结婚的结局画面")
	has_text(main.dialog.get_child(0).get_child(0).get_child(0).text, "结婚了")
	_pick("孵这颗蛋")
	eq(main.game.pet.gen, 2, "孵出第 2 代")
	eq(main.game.pet.stage, "egg")
	_later(6 * 60 + 3600)
	eq(main.game.pet.stage, "child")
	has_text(_card(), "第 2 代")
	_feed_up()
	main.do_action("out")
	check("爸妈家" in _button_texts(), "出门能去爸妈家: %s" % [_button_texts()])
	_pick("爸妈家")
	check(main.game.pet.sitting())
	eq(main.sitter_button.text, "接回来")
	has_text(_card(), "在爸妈家")
	main.do_action("sitter")
	check(not main.game.pet.sitting(), "接回来了")


func test_pick_personality_when_growing_up() -> void:
	_start()
	main.game.offset += 6 * 60 + 3600
	main.game.tick()
	main._refresh()
	eq(main.game.pet.stage, "child")
	check(main.dialog != null, "长成小孩问它是什么性格")
	has_text(main.dialog.get_child(0).get_child(0).get_child(0).text, "性格")
	eq(main.dialog_buttons.size(), Personality.ORDER.size())
	_pick("悠闲")
	eq(main.game.pet.personality, "mellow")
	has_text(_card(), "性格悠闲", "名片上写着性格")


func test_eat_out_from_the_out_menu() -> void:
	_start()
	_later(6 * 60 + 3600)
	_feed_up()
	main.game.pet.hunger = 1
	main.game.money = 50
	main.do_action("out")
	_pick("美食街")
	has_text(main.dialog.get_child(0).get_child(0).get_child(0).text, "美食街")
	_pick("面包店")
	eq(main.game.pet.hunger, 3, "吃了面包")
	eq(main.game.money, 50 - Outings.SHOPS.bakery.price)
	eq(main.screen.mode, "out", "屏幕上看它在美食街吃")


func test_tap_the_pest_away() -> void:
	_start()
	_later(6 * 60 + 3600)
	_feed_up()
	main.game.pet.pest_at = main.game.pet.now
	main._refresh()
	has_text(main._hint(), "捣蛋精", "没有新消息的时候, 下面那行提醒有捣蛋精")
	var r: Rect2 = main.screen.pest_rect()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = (r.position + r.size / 2.0) * main.screen.px()
	main.screen._gui_input(ev)
	eq(main.game.pet.pest_at, 0, "点一下就赶跑了")
	has_text(main.message.text, "赶跑")
