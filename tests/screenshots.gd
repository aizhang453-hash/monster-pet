extends SceneTree
## 拍画面: 打开游戏, 摆出几种场面各拍一张, 存到给定的文件夹 (会开一下窗口, 拍完自己关)。
##   /Applications/Godot.app/Contents/MacOS/Godot --path . -s tests/screenshots.gd -- 存图的文件夹
## 假屏幕 (--headless) 画不出东西, 要开真窗口。存档放临时文件夹, 时间钉住, 不碰真的存档和钟。

const T0 := 1767225600 + 5 * 86400 + 10 * 3600   # 2026-01-06 (不是节日)

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


## 玩一个小游戏: 先让它走 frames 帧 (每帧 0.05 秒), 中间按 presses 里的 [第几帧, 按什么]
func _play(id: String, frames: int, presses := [], name := "") -> void:
	main.start_play(id, 3)
	var g: MiniGame = main.screen.minigame
	for i in frames:
		for pr in presses:
			if pr[0] == i:
				main.play_press(pr[1])
		g.step(0.05)
	main.screen.t += 3.0  # 跳过一开始那 2.5 秒的说明, 下面那行显示分数
	main._process(0.0)
	await _shot(name)
	main.quit_play()


func _v6_games() -> void:
	main.do_action("play")
	await _shot("53_玩什么_十三个小游戏")
	main.close_dialog()
	await _play("number", 2, [[1, "big"]], "54_猜数字")
	await _play("rope", 12, [[4, "jump"]], "55_跳绳")
	await _play("climb", 10, [[1, "l"], [2, "r"], [3, "l"], [4, "r"], [5, "l"], [6, "r"], [7, "l"]], "56_爬高")
	var pulls := []
	for i in 40:
		if i % 3 == 0:
			pulls.append([i, "pull"])
	await _play("tug", 40, pulls, "57_拔河")
	await _play("mimic", 5, [], "58_模仿")
	await _play("flag", 16, [[14, "red"]], "59_举旗")
	var runs := []
	for i in 60:
		if i % 4 == 0:
			runs.append([i, "run"])
	await _play("sprint", 60, runs, "60_赛跑")
	await _play("dance", 40, [], "61_跳舞")
	await _play("burger", 10, [[2, "bun"]], "62_做汉堡")


func _v6_festivals() -> void:
	var g: Game = main.game
	g.offset = 0
	g.fixed_time = Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 12, "day": 25, "hour": 10})
	g.pet = Helpers.at("huolong", Rules.EASY, g.fixed_time)
	main.screen.pet_x = 14
	g.tick()
	main._refresh()
	await _shot("63_圣诞节")
	for f in [[2027, 2, 6, "64_春节"], [2026, 10, 31, "65_万圣节"], [2026, 9, 25, "66_中秋"]]:
		g.fixed_time = Time.get_unix_time_from_datetime_dict({"year": f[0], "month": f[1], "day": f[2], "hour": 10})
		g.pet = Helpers.at("linlu", Rules.EASY, g.fixed_time)
		g.tick()
		main._refresh()
		await _shot(f[3])
	main._show_shop_page("吃的")
	await _shot("67_中秋的商店")
	main.close_dialog()
	for s in ["pebble", "shell", "key", "firework", "fu", "pumpkin", "snowman"]:
		g.add_souvenir(s)
	g.add_souvenir("pebble")
	main._show_souvenirs()
	await _shot("68_纪念品")
	main.close_dialog()
	g.fixed_time = T0
	g.pet = Helpers.at("huolong", Rules.EASY, T0)
	g.pet.tidy = 0
	main._refresh()
	await _shot("69_脏兮兮")
	main.screen.mode = "status"
	main.screen.status_page = 2
	main.screen.status_until = main.screen.t + 99
	g.pet.tidy = 2
	g.pet.discipline = 3
	await _shot("70_状态第一页_干净")
	main.screen.mode = "pet"
	main.do_action("clean")
	await _shot("71_洗澡")
	g.outings = ["park", "forest", "lakeside", "night", "hotel"]
	g.rng.seed = 1
	for i in 20:
		g.out_at.clear()
		var out := g.go_out("forest")
		if out.souvenir != "":
			main.screen.show_outing("forest", "", Items.SOUVENIRS[out.souvenir].icon)
			main._say(out.text)
			break
	main.screen.t = main.screen.out_until - 1.0
	await _shot("72_森林带回松果")
	main.screen.mode = "pet"


func _v7_family() -> void:
	var g: Game = main.game
	g.fixed_time = T0
	g.offset = 0
	g.places = ["grass", "lake", "sky"]
	g.pet = Helpers.at("huolong", Rules.EASY, T0)
	g.pet.hunger = 4
	g.pet.happy = 4
	g.rng.seed = 7
	g.pet.wants_match = true
	g.pet.events.append({"kind": "match_ask"})
	g._take_events()
	main._asked_match = false
	main._shown_end = false
	main._refresh()
	await _shot("73_媒人来了")
	main.choose(1)
	main.screen.pet_x = 4
	await _shot("74_结婚了")
	main.close_dialog()
	await _shot("75_结婚的画面")
	main._show_ending()
	main._hatch_next_egg()
	await _shot("76_第二代的蛋")
	var p: Pet = g.pet
	p.hatched_at = p.now
	p._become("jianjiao")
	p.hunger = 4
	p.happy = 4
	g._take_events()
	main.screen.pet_x = 16
	main._refresh()
	await _shot("77_第二代小孩")
	p._become("shuiling")
	p.hunger = 4
	p.happy = 4
	g._take_events()
	main._refresh()
	await _shot("78_第二代长大了")
	main.screen.mode = "status"
	main.screen.status_page = 1
	main.screen.status_until = main.screen.t + 99
	await _shot("78b_状态名片")
	main.screen.mode = "pet"
	main.do_action("out")
	await _shot("79_出门有爸妈家")
	main._go_parents()
	await _shot("80_在爸妈家")
	main.do_action("sitter")
	g.equip.erase("hat")


func _run() -> void:
	main.game.use_system_tz = false  # 游戏的 _ready 这时候才跑完
	main.game.tz = 0
	main.game.fixed_time = T0
	await _shot("00_开始界面")
	main.start_game()
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
	# 第三版: 出门、旅馆、住的地方
	for id in ["crown", "scarf", "wall_pink", "rug_grass", "plant", "painting"]:
		main.game.set_equip(Items.kind_of(id), "")
	main.game.places = ["grass", "lake", "sky"]
	main.game.outings = ["park", "forest", "lakeside", "night", "hotel"]
	q.place = "lake"
	q.species = "hailong"
	q.hunger = 4
	q.happy = 4
	main._refresh()
	await _shot("27_湖泊的海龙")
	main.do_action("out")
	await _shot("28_去哪儿")
	main.close_dialog()
	main.game.rng.seed = 3
	main.go_out("park")
	main.screen.t = main.screen.out_until - 1.0
	await _shot("29_公园")
	main.screen.mode = "pet"
	main.go_out("night")
	main.screen.t = main.screen.out_until - 1.0
	await _shot("30_夜市")
	main.screen.mode = "pet"
	q.place = "sky"
	q.species = "fenghuang"
	main._refresh()
	await _shot("31_天空岛的彩虹凤凰")
	main.game.money = 100
	main.game.hotel(4)
	main._refresh()
	await _shot("32_住旅馆")
	main.do_action("sitter")
	for id in Species.ORDER:
		main.game.dex[id] = 1
	main.game.dex.erase("yuejing")
	main.game.dex.erase("fenghuang")
	main.do_action("more")
	main.choose(3)  # 图鉴 (商店、装扮、搬家、图鉴……)
	await _shot("33_图鉴")
	main.close_dialog()
	main._ask_place(Rules.EASY)
	await _shot("34_在哪里养")
	main.close_dialog()
	# 第四版: 训练和比赛
	q.place = "grass"
	q.species = "huolong"
	q.power = 42
	q.speed = 18
	q.guard = 25
	q.rank = 2
	q.hunger = 4
	q.happy = 4
	q.trained_at = -999999
	q.matched_at = -999999
	main._refresh()
	main.do_action("play")
	await _shot("35_玩什么_有训练比赛")
	main.close_dialog()
	main._ask_train()
	await _shot("36_练什么")
	main._train("power")
	await _shot("37_练完")
	main.screen.mode = "status"
	main.screen.status_page = 3
	main.screen.status_until = main.screen.t + 99
	await _shot("38_状态第二页")
	main.screen.mode = "pet"
	main._ask_compete()
	await _shot("39_比赛")
	q.hunger = 4
	q.happy = 4
	q.matched_at = -999999
	main.game.rng.seed = 2
	main._compete(1)
	for i in 6:
		main.screen._process(0.35)
	await _shot("40_对打中")
	for i in 80:
		main.screen._process(0.3)
	await _shot("41_比完")
	# 第五版: 上学、工作、夸它、摸摸它、信
	q.hunger = 4
	q.happy = 4
	q.call = ""
	main._refresh()
	main.do_action("scold")
	await _shot("43_管教_骂还是夸")
	main.close_dialog()
	q.patted_at = -999999
	main.screen.pet_x = 16
	main._on_pet_touched()
	await _shot("44_摸摸它")
	q.smart = 22
	q.style = 41
	q.kind = 18
	main.screen.mode = "status"
	main.screen.status_page = 4
	main.screen.status_until = main.screen.t + 99
	await _shot("45_状态第三页")
	main.screen.mode = "pet"
	main._ask_job()
	await _shot("46_找工作")
	main.close_dialog()
	main.play_purpose = "school:style"
	main.start_play("quiz_style", 4)
	await _shot("47_美术课")
	main.play_press("0")
	await _shot("48_答了一题")
	main.quit_play()
	main.play_purpose = "school:kind"
	main.start_play("quiz_kind", 6)
	await _shot("49_品德课")
	main.quit_play()
	main.play_purpose = "school:smart"
	main.start_play("quiz_smart", 2)
	await _shot("50_数学课")
	main.quit_play()
	main.game.add_letter("学校寄来的成绩单", "「火焰龙」一共上了 5 节课。\n聪明 22、时尚 41、善良 18。\n继续加油!")
	main._show_mail()
	await _shot("51_信箱")
	main._read_letter(main.game.letters.size() - 1)
	await _shot("52_看信")
	main.close_dialog()
	# 第六版: 九个新小游戏
	await _v6_games()
	await _v6_festivals()
	await _v7_family()
	# 开始界面: 养着魔物的时候
	var again = load("res://scenes/main.tscn").instantiate()
	main.game.offset = main.game.clock() - int(Time.get_unix_time_from_system())  # 再打开的那个看真的钟, 拨到一样的时间
	main.game.fixed_time = -1
	main.game.save()
	root.add_child(again)
	await _shot("42_开始界面_继续养")
	SaveGame.erase()
	quit()
