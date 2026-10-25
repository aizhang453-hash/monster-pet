extends SceneTree
## 拍画面: 打开游戏, 摆出几种场面各拍一张, 存到给定的文件夹 (会开一下窗口, 拍完自己关)。
##   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tests/screenshots.gd -- 存图的文件夹
## 假屏幕 (--headless) 画不出东西, 要开真窗口。存档放临时文件夹, 时间钉住, 不碰真的存档和钟。

const T0 := 1767225600 + 10 * 3600

var out := ""
var main: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(540, 960))
	SaveGame.dir = OS.get_temp_dir().path_join("monster_pet_shot_saves")
	SaveGame.erase()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()


func _wait(frames := 6) -> void:
	for i in frames:
		await process_frame


func _shot(name: String) -> void:
	await _wait()
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("拍了 ", name)


func _later(seconds: int) -> void:
	main.game.offset += seconds
	main.game.tick()
	main._refresh()


func _run() -> void:
	main.game.use_system_tz = false  # 游戏的 _ready 这时候才跑完
	main.game.tz = 0
	main.game.fixed_time = T0
	await _shot("01_选难度")
	main.choose(0)
	await _shot("02_蛋")
	_later(6 * 60)
	await _shot("03_刚孵出来")
	main.do_action("feed")
	await _shot("04_喂什么")
	main.choose(0)
	await _shot("05_吃了饭")
	main.screen.show_status()
	await _shot("06_状态")
	main.screen.mode = "pet"
	main.do_action("play")
	main.choose(0)
	main.play_press("right")
	await _shot("07_小游戏")
	main.quit_play()
	main.do_action("sitter")
	_later(3 * 3600)
	await _shot("07b_托人照看")
	main.do_action("sitter")
	var p: Pet = main.game.pet
	# 换成一只成年的火焰龙, 摆出便便、生病
	p.hatched_at = p.now - 4 * 86400
	p._become("huolong")
	p.poop = 3
	p.poop_since = p.now
	p._get_sick(false)
	p.hunger = 1
	p.happy = 0
	p._settle()
	main.game._take_events()
	main._refresh()
	await _shot("08_成年_便便_生病")
	main.screen.show_status()
	await _shot("09_成年的状态")
	main.screen.mode = "pet"
	p.sick = false
	p.poop = 0
	p.asleep = true
	p.lights = false
	p.call = ""
	main._refresh()
	await _shot("10_睡觉关灯")
	p.asleep = false
	p.lights = true
	for id in Species.ORDER:
		main.game.dex[id] = 1
	main.game.dex.erase("xingguang")
	main.do_action("more")
	await _shot("11_更多")
	main.choose(0)
	await _shot("12_图鉴")
	main.close_dialog()
	p.wants_leave = true
	main._asked_leave = false
	main._refresh()
	await _shot("13_想离开")
	main.choose(0)
	main._refresh()
	await _shot("14_出发了")
	main.close_dialog()
	await _shot("15_走了的画面")
	main.game.new_egg(Rules.EASY)
	main._shown_end = false
	main.game.pet.hatched_at = main.game.pet.now
	main.game.pet._become("xiaomo")
	main.game.pet._end("neglect")
	main.game._take_events()
	main._refresh()
	await _shot("16_死了")
	main.close_dialog()
	await _shot("17_幽灵")
	# 第二版: 商店、装扮、房间、小游戏
	main.close_dialog()
	main.game.new_egg(Rules.EASY)
	main._shown_end = false
	var q: Pet = main.game.pet
	q.hatched_at = q.now
	q._become("huolong")
	q.hunger = 4
	q.happy = 4
	q._settle()
	main.game._take_events()
	main.game.money = 900
	main.screen.pet_x = 18.0
	main._refresh()
	main.do_action("more")
	main.choose(0)
	await _shot("18_商店")
	main.choose(2)
	await _shot("19_商店_衣服配饰")
	for id in ["crown", "scarf", "wall_pink", "rug_grass", "plant", "painting", "apple", "cake", "ball"]:
		main.game.buy(id)
	main.close_dialog()
	main._refresh()
	await _shot("20_房间和装扮")
	main.do_action("more")
	main.choose(1)
	await _shot("21_装扮")
	main.close_dialog()
	main.do_action("feed")
	await _shot("22_喂什么_有买的")
	main.close_dialog()
	main.do_action("play")
	await _shot("23_玩什么")
	main.close_dialog()
	main.start_play("catch", 3)
	for i in 70:
		main.screen.minigame.step(0.05)
	await _shot("24_接果子")
	main.quit_play()
	main.start_play("jump", 3)
	for i in 60:
		main.screen.minigame.step(0.05)
	main.play_press("jump")
	for i in 8:
		main.screen.minigame.step(0.05)
	await _shot("25_跳石头")
	main.quit_play()
	main.start_play("memory", 3)
	for i in 14:
		main.screen.minigame.step(0.05)
	await _shot("26_记颜色")
	main.quit_play()
	SaveGame.erase()
	quit()
