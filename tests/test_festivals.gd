extends TestCase
## 第六版: 节日 (按真实日期, 礼物和纪念品)、纪念品、洗澡。存档写到临时文件夹, 不碰真的存档。

const T0 := Helpers.T0


func before_each() -> void:
	SaveGame.dir = OS.get_temp_dir().path_join("monster_pet_test_festivals_%d" % OS.get_process_id())


func after_each() -> void:
	SaveGame.erase()
	DirAccess.remove_absolute(SaveGame.dir)


## 某年某月某日上午 10 点 (时区 0)
func _day(y: int, m: int, d: int, hour := 10) -> int:
	return Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": d, "hour": hour})


func _game(t: int, id := "jianjiao") -> Game:
	var g := Game.new()
	g.use_system_tz = false
	g.fixed_time = t
	g.pet = Helpers.at(id, Rules.EASY, t)
	return g


func test_which_day_is_which_festival() -> void:
	eq(Festivals.today(_day(2026, 1, 1), 0), "newyear")
	eq(Festivals.today(_day(2026, 1, 6), 0), "", "测试开始的那天 (1 月 6 日) 不是节日")
	eq(Festivals.today(_day(2026, 2, 16), 0), "", "除夕不算")
	for d in [17, 18, 19]:
		eq(Festivals.today(_day(2026, 2, d), 0), "spring", "2026 年春节过三天 (2 月 %d 日)" % d)
	eq(Festivals.today(_day(2026, 2, 20), 0), "")
	eq(Festivals.today(_day(2027, 2, 6), 0), "spring", "2027 年春节是 2 月 6 日")
	eq(Festivals.today(_day(2026, 6, 1), 0), "children")
	eq(Festivals.today(_day(2026, 9, 25), 0), "midautumn", "2026 年中秋是 9 月 25 日")
	eq(Festivals.today(_day(2028, 10, 3), 0), "midautumn", "2028 年中秋是 10 月 3 日")
	eq(Festivals.today(_day(2026, 10, 31), 0), "halloween")
	eq(Festivals.today(_day(2026, 12, 24), 0), "christmas")
	eq(Festivals.today(_day(2026, 12, 25), 0), "christmas")
	eq(Festivals.today(_day(2026, 12, 26), 0), "")


func test_festival_uses_local_date() -> void:
	# 世界时间 12 月 31 日下午 4 点半, 在北京 (快 8 小时) 已经是 1 月 1 日半夜 0 点半
	var t := _day(2025, 12, 31, 16) + 30 * 60
	eq(Festivals.today(t, 0), "")
	eq(Festivals.today(t, 8 * 3600), "newyear")


func test_lunar_table_is_long_enough() -> void:
	var year: int = Time.get_datetime_dict_from_system().year
	check(year + 2 <= Festivals.LAST_YEAR, "春节、中秋的日期只写到 %d 年, 该往 scripts/festivals.gd 里加新的年份了" % Festivals.LAST_YEAR)
	for f in Festivals.LUNAR:
		for y in range(2026, Festivals.LAST_YEAR + 1):
			check(Festivals.LUNAR[f].has(y), "%s 缺 %d 年" % [f, y])
	for id in Festivals.LIST:
		check(Festivals.GIFTS.has(id), "%s 有礼物" % id)
		check(Items.SOUVENIRS.has(Festivals.LIST[id].souvenir), "%s 有纪念品" % id)
		check(Art.has(Festivals.LIST[id].deco), "%s 有装饰的图" % id)


func test_new_year_gift_once_a_year() -> void:
	var g := _game(_day(2026, 1, 1))
	var money := g.money
	g.tick()
	eq(g.money, money + 30, "新年礼物: 魔晶 30")
	eq(int(g.souvenirs.get("firework", 0)), 1, "还有新年的纪念品")
	var said := g.take_messages().map(func(m): return m.text)
	check(said.any(func(s): return s.contains("新年快乐")), "说了新年快乐: %s" % [said])
	g.fixed_time += 3 * 3600
	g.tick()
	eq(g.money, money + 30, "同一天再打开不会再送")
	g.fixed_time = _day(2027, 1, 1)
	g.pet = Helpers.at("huolong", Rules.EASY, g.fixed_time)
	g.tick()
	eq(g.money, money + 60, "第二年又送")
	eq(int(g.souvenirs.firework), 2)


func test_spring_and_children_gifts() -> void:
	var g := _game(_day(2026, 2, 18))
	g.tick()
	eq(int(g.items.get("dumpling", 0)), 2, "春节送饺子")
	eq(int(g.souvenirs.get("fu", 0)), 1)
	g.fixed_time = _day(2026, 2, 19)
	g.tick()
	eq(int(g.items.dumpling), 2, "春节三天只送一次")
	var c := _game(_day(2026, 6, 1))
	c.tick()
	check("ball" in c.owned, "儿童节送一个还没有的玩具")
	c.celebrated.clear()
	c.tick()
	check("blocks" in c.owned, "有了皮球就送下一个")


func test_no_gift_on_a_normal_day() -> void:
	var g := _game(T0)
	var money := g.money
	g.tick()
	eq(g.money, money)
	eq(g.souvenirs, {})
	eq(g.festival(), "")


func test_festival_food_only_in_shop_that_day() -> void:
	SaveGame.dir = OS.get_temp_dir().path_join("monster_pet_test_festivals_ui_%d" % OS.get_process_id())
	var main = load("res://scenes/main.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	main.game.use_system_tz = false
	main.game.tz = 0
	main.game.fixed_time = _day(2026, 9, 25)
	main._show_shop_page("吃的")
	var texts: Array = main.dialog_buttons.map(func(b): return b.text)
	check(texts.any(func(s): return s.begins_with("月饼")), "中秋节的商店有月饼: %s" % [texts])
	check(not texts.any(func(s): return s.begins_with("饺子")), "没有饺子 (春节才有)")
	main.game.fixed_time = T0
	main._show_shop_page("吃的")
	texts = main.dialog_buttons.map(func(b): return b.text)
	check(not texts.any(func(s): return s.begins_with("月饼")), "平时没有月饼")
	main.free()


func test_outings_bring_back_souvenirs() -> void:
	var g := _game(T0)
	g.outings = ["park", "forest", "lakeside", "hotel"]
	var got := 0
	for i in 30:
		g.out_at.clear()  # 当作隔了好久才又来 (不拨钟, 一直是白天)
		var out := g.go_out("park")
		check(out.get("ok", false), "出得去")
		if out.get("souvenir", "") != "":
			eq(out.souvenir, "pebble", "公园带回圆石子")
			got += 1
	check(got >= 3 and got <= 20, "30 次有收获的出门, 带回纪念品 %d 次 (大约三成)" % got)
	eq(int(g.souvenirs.get("pebble", 0)), got)


func test_souvenirs_and_festivals_are_saved() -> void:
	var g := _game(_day(2026, 10, 31))
	g.tick()
	g.add_souvenir("shell")
	check(g.save())
	var back := Game.load_saved()
	eq(int(back.souvenirs.pumpkin), 1)
	eq(int(back.souvenirs.shell), 1)
	check(back.celebrated.has("halloween2026"), "记得今年万圣节送过了")
	back.fixed_time = _day(2026, 10, 31, 20)
	back.use_system_tz = false
	var money := back.money
	back.tick()
	eq(back.money, money)
	eq(int(back.souvenirs.pumpkin), 1, "读档以后同一天不会再送")


# ---------------------------------------------------------------- 洗澡

func test_gets_dirty_while_awake_and_bath_cleans() -> void:
	var p := Helpers.at("jianjiao")
	eq(p.tidy, 4, "一开始干干净净")
	p.advance(T0 + Rules.DIRTY_EVERY[Rules.EASY] + 60)
	eq(p.tidy, 3, "醒着 6 小时脏一格")
	p.poop = 0
	eq(p.clean(), "bath", "没有便便的时候打扫 = 洗澡")
	eq(p.tidy, 4)
	eq(p.clean(), "nothing", "干净了就不用洗")
	p.poop = 2
	p.tidy = 2
	eq(p.clean(), "ok", "有便便先清便便")
	eq(p.poop, 0)
	eq(p.tidy, 2)
	eq(p.clean(), "bath", "再按一次洗澡")


func test_too_dirty_makes_it_unhappy() -> void:
	var p := Helpers.at("jianjiao", Rules.STRICT)
	p.tidy = 0
	p.next_dirty = p.now + 60
	p.next_happy = p.now + 10 * Rules.HOUR
	p.advance(p.now + 120)
	eq(p.happy, 3, "脏透了还不洗, 开心 -1")
	eq(p.call, "", "不会叫你")
	eq(p.mistakes, 0, "也不算失误")


func test_training_and_outings_make_it_dirty() -> void:
	var p := Helpers.at("jianjiao")
	eq(p.train("power"), "ok")
	eq(p.tidy, 3, "练完脏一格")
	var g := _game(T0)
	g.outings = ["park"]
	g.go_out("park")
	eq(g.pet.tidy, 3, "出门玩脏一格")


func test_sitter_and_hotel_give_a_bath() -> void:
	var p := Helpers.at("jianjiao")
	p.tidy = 1
	eq(p.start_sitter(), "ok")
	eq(p.tidy, 4, "照看的人帮它洗澡")
	p.end_sitter()
	p.tidy = 0
	eq(p.start_hotel(p.now + 2 * Rules.HOUR), "ok")
	eq(p.tidy, 4, "旅馆也帮它洗澡")


func test_no_bath_while_asleep() -> void:
	var p := Helpers.at("jianjiao")
	p.tidy = 2
	p.asleep = true
	eq(p.clean(), "asleep", "睡着了不洗澡")
	eq(p.tidy, 2)


func test_old_save_without_tidy_is_clean() -> void:
	var p := Helpers.at("jianjiao")
	var d := p.to_dict()
	d.erase("tidy")
	d.erase("next_dirty")
	var back := Pet.from_dict(d)
	eq(back.tidy, 4, "以前版本的存档: 干干净净")
	back.advance(back.now + Rules.HOUR)
	check(back.next_dirty > back.now, "开始算什么时候脏")
	eq(back.tidy, 4)
