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
	check(main.dialog != null, "第一次打开先选难度")
	main.choose(diff_button)
	main.game.pet.tz = 0


func _later(seconds: int) -> void:
	main.game.offset += seconds
	main.game.tick()
	main._refresh()


func test_first_open_asks_difficulty_and_lays_an_egg() -> void:
	_start(1)
	check(main.dialog == null)
	eq(main.game.pet.stage, "egg")
	eq(main.game.pet.difficulty, Rules.STRICT, "第二个按钮是原版严格")
	check(main.buttons.feed.disabled, "还是蛋的时候不能喂")
	check(not main.buttons.lights.disabled)
	has_text(main.info.text, "孵出来")
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
	main.do_action("status")
	eq(main.screen.mode, "pet", "再按一次回去")
	main.do_action("lights")
	check(not main.game.pet.lights, "关灯了")
	main.do_action("lights")
	check(main.game.pet.lights)
	main.do_action("clean")
	has_text(main.message.text, "没有便便")


func test_play_the_guessing_game() -> void:
	_start()
	_later(6 * 60)
	main.do_action("play")
	eq(main.screen.mode, "play")
	main._refresh()
	check(main.play_bar.visible and not main.grid.visible, "玩的时候换成左右两个按钮")
	for i in Rules.GAME_ROUNDS:
		main.screen.play_turn = 0  # 不等动画
		main.guess(1 if i % 2 == 0 else -1)
	eq(main.screen.play_round, Rules.GAME_ROUNDS)
	main.finish_play()
	eq(main.screen.mode, "pet")
	check(main.message.text.contains("赢了") or main.message.text.contains("输了"), main.message.text)
	main._refresh()
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
	has_text(main.info.text, "托人照看中")
	check(main.buttons.feed.disabled, "托出去了不能喂")
	check(not main.buttons.more.disabled)
	_later(3600)
	has_text(main._hint(), "还能照看", "没有新消息时, 下面那行显示还剩多久")
	main.do_action("sitter")
	check(not main.game.pet.sitting(), "接回来了")
	check(not main.buttons.feed.disabled)


func test_difficulty_text_explains_the_fifteen_minutes() -> void:
	check(main.dialog_buttons[0].text.contains("推荐"), "放宽标了推荐")
	check(main.dialog_buttons[1].text.contains("原版严格"))


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
	var ids := ["feed", "lights", "play", "medicine", "clean", "status", "scold", "more", "sitter"]
	for i in 1500:
		var r := rng.randf()
		if main.dialog != null:
			if not main.dialog_buttons.is_empty():
				main.choose(rng.randi() % main.dialog_buttons.size())
			else:
				main.close_dialog()
		elif main.screen.mode == "play":
			main.screen.play_turn = 0
			if main.guess(1 if rng.randf() < 0.5 else -1) or main.screen.play_round >= Rules.GAME_ROUNDS:
				main.finish_play()
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
