extends TestCase
## 第十一版: 一家人住在一起 (结婚的两口子、放走的、双胞胎的另一只住进长大的地方, 每个地方最多 4 位) 和双胞胎。
## 存档写到临时文件夹, 不碰真的存档。

const T0 := Helpers.T0
const DAY := Rules.DAY


func before_each() -> void:
	SaveGame.dir = OS.get_temp_dir().path_join("monster_pet_test_v11_%d" % OS.get_process_id())


func after_each() -> void:
	SaveGame.erase()
	DirAccess.remove_absolute(SaveGame.dir)


func _game(id := "huolong", place := "grass") -> Game:
	var g := Game.new()
	g.use_system_tz = false
	g.fixed_time = T0
	g.places = ["grass", "lake", "sky"]
	g.family_id = 1
	g.pet = Helpers.at(id)
	g.pet.place = place
	g.pet.lifespan = 99
	return g


func _marry(g: Game, partner: String) -> void:
	g.pet.match_offers = [{"species": partner, "hue": 0.6, "feature": "fin", "extra": ""}]
	g.pet.wants_match = true
	g.act("match", 0)


# ---------------------------------------------------------------- 双胞胎

func test_twins_come_from_marriage_sometimes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var twins := 0
	var same := 0
	for i in 1000:
		var c := Genes.child({"species": "huolong", "hue": 0.0, "feature": "horn", "extra": "wing"},
			{"species": "hailong", "hue": 0.6, "feature": "fin", "extra": "tail"}, 1, rng)
		if c.has("twin"):
			twins += 1
			if c.twin.hue == c.hue and c.twin.feature == c.feature and c.twin.extra == c.extra:
				same += 1
	check(twins > 140 and twins < 260, "大概两成是双胞胎: %d/1000" % twins)
	check(same > twins / 4 and same < twins, "有一模一样的, 也有长得不一样的: %d/%d" % [same, twins])
	for i in 200:
		check(not Genes.child({"species": "huolong"}, {}, 1, rng).has("twin"), "老死留下的蛋 (只有一个爸妈) 不会是双胞胎")


func test_twin_egg_hatches_two_cared_together() -> void:
	var g := _game()
	g.new_egg(Rules.EASY, T0, "grass", {"gen": 2, "hue": 0.1, "feature": "horn", "extra": "", "pair": ["huolong", "hailong"],
		"twin": {"hue": 0.5, "feature": "leaf", "extra": "wing"}})
	eq(float(g.pet.twin.hue), 0.5)
	has_text(g.messages[-1].text, "双胞胎蛋")
	Helpers.care(g.pet, T0 + 30 * 60)
	eq(g.pet.species, "tuanzi")
	eq(g.pet.twin_look().species, "tuanzi", "两只是同一种 (一起照顾)")
	has_text(g.describe({"kind": "grow", "id": "tuanzi", "from": "egg"}), "双胞胎")
	eq(g.pet.twin_look().feature, "leaf", "老二有自己的样子")


func test_choose_which_twin_marries() -> void:
	var g := _game()
	g.pet.hue = 0.1
	g.pet.feature = "horn"
	g.pet.twin = {"hue": 0.5, "feature": "leaf", "extra": "wing"}
	g.pet.choose_twin(1)
	eq(g.pet.feature, "leaf", "挑了老二")
	eq(g.pet.twin.feature, "horn", "老大变成留下的那只")
	_marry(g, "hailong")
	eq(g.pet.end_reason, "married")
	var here: Array = g.residents.grass
	eq(here.size(), 3, "两口子 + 双胞胎的另一只")
	eq(here[2].why, "twin")
	eq(here[2].feature, "horn", "搬去住的是没结婚的老大")
	eq(g.family_tree()[0].twin.feature, "horn", "家谱记着双胞胎")


# ---------------------------------------------------------------- 一家人住在一起

func test_married_couple_and_left_ones_move_in() -> void:
	var g := _game("huolong", "lake")
	_marry(g, "hailong")
	eq(g.residents.lake.size(), 2, "两口子住到它长大的湖泊")
	eq(g.residents.lake[0].species, "huolong")
	eq(g.residents.lake[1].species, "hailong")
	eq(g.residents.lake[0].why, "parents")
	var h := _game("linlu", "sky")
	h.pet.twin = {"hue": 0.2, "feature": "tuft", "extra": ""}
	h.pet.wants_leave = true
	h.act("leave", true)
	eq(h.residents.sky.size(), 2, "放走的和它的双胞胎一起住到天空岛")
	eq(h.residents.sky[0].why, "left")
	var d := _game("mogu")
	d.pet.lifespan = 1
	Helpers.care(d.pet, T0 + DAY + Rules.HOUR)
	d.fixed_time = d.pet.now
	d.tick()
	eq(d.pet.end_reason, "old")
	eq(d.places_with_family(), [], "老死的不住进去")


func test_matchmaker_leaves_its_twin_behind() -> void:
	var g := _game()
	g.pet.twin = {"hue": 0.2, "feature": "tuft", "extra": ""}
	g.pet.old = true
	g.pet.wants_retire = true
	g.act("retire", true)
	eq(g.pet.end_reason, "matchmaker")
	eq(g.residents.grass.size(), 1, "去当媒人的不住, 双胞胎的另一只住进来")
	eq(g.residents.grass[0].why, "twin")


func test_each_place_holds_four() -> void:
	var g := _game()
	for sp in ["huolong", "shuiling", "linlu"]:
		g.pet = Helpers.at(sp)
		g.pet.place = "grass"
		_marry(g, "hailong")
	eq(g.residents.grass.size(), Rules.RESIDENTS_MAX, "最多住 4 位")
	eq(g.residents.grass[0].species, "shuiling", "最早来的火焰龙两口子被挤走了")
	check(g.messages.any(func(m): return "旅行" in m.text), "说一声它出门旅行去了")


func test_visit_family() -> void:
	var g := _game()
	eq(g.visit_family("grass").ok, false, "还没有家人")
	_marry(g, "hailong")
	g.new_egg(Rules.EASY, g.pet.now, "grass", g.next_egg.duplicate())
	eq(g.visit_family("grass").ok, false, "还是蛋, 不能出门")
	g.pet.hatched_at = g.pet.now
	g.pet._become("jianjiao")
	g.pet.happy = 2
	var res := g.visit_family("grass")
	check(res.ok)
	has_text(res.text, "开心 +1")
	eq(g.pet.happy, 3)
	res = g.visit_family("grass")
	check(res.ok)
	eq(g.pet.happy, 3, "两小时内再去只是挥挥手")
	g.fixed_time += 3 * Rules.HOUR
	Helpers.care(g.pet, g.fixed_time)
	g.pet.happy = 2
	check(g.visit_family("grass").text.contains("开心 +1"), "过了两小时又能开心一下")
	eq(g.visit_family("lake").ok, false, "湖泊没有家人")


func test_residents_and_twins_are_saved() -> void:
	var g := _game()
	g.pet.twin = {"hue": 0.3, "feature": "flower", "extra": "tail"}
	check(g.save())
	var back := Game.load_saved()
	back.use_system_tz = false
	back.fixed_time = g.fixed_time  # 读出来的游戏看真的钟, 钉回测试的时间 (不然一下过去好几个月)
	eq(back.pet.twin.feature, "flower")
	_marry(back, "hailong")
	check(back.save())
	var again := Game.load_saved()
	eq(again.residents.grass.size(), 3)
	eq(again.places_with_family(), ["grass"])
