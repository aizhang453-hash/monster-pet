extends TestCase
## 第三版: 出门 (照拓麻歌子 On / Meets: 小孩起能出门, 马上去马上回; 新地方做点小事解锁)。

const T0 := Helpers.T0
const HOUR := 3600


func _game(id := "jianjiao") -> Game:
	var g := Game.new()
	g.use_system_tz = false
	g.fixed_time = T0
	g.rng.seed = 7
	g.pet = Helpers.at(id)
	return g


func test_who_can_go_out() -> void:
	var g := _game("tuanzi")
	eq(g.can_go_out(), "small", "宝宝太小")
	g.pet = Helpers.at("jianjiao")
	eq(g.can_go_out(), "ok", "小孩能出门")
	g.pet.sick = true
	eq(g.can_go_out(), "sick")
	g.pet.sick = false
	g.pet.start_sitter()
	eq(g.can_go_out(), "away")


func test_park_meets_a_monster_and_makes_happy() -> void:
	var g := _game()
	g.pet.happy = 2
	var out := g.go_out("park")
	check(Species.DATA.has(out.npc), "碰到了一只魔物 (%s)" % out.npc)
	eq(Species.place_of(out.npc), "grass", "只碰到打开了的地方的魔物")
	eq(g.pet.happy, 3, "开心 +1")
	has_text(out.text, Species.name_of(out.npc))
	g.go_out("park")
	eq(g.pet.happy, 3, "两小时内再去, 打个招呼, 不再加开心")
	g.fixed_time = T0 + 2 * HOUR
	g.tick()
	g.pet.happy = 2
	g.go_out("park")
	eq(g.pet.happy, 3, "过两小时又加")


func test_forest_opens_after_five_park_visits() -> void:
	var g := _game()
	has_text(g.go_out("forest").text, "还没解锁")
	for i in 4:
		g.go_out("park")
	check(not "forest" in g.outings)
	g.go_out("park")
	check("forest" in g.outings, "去公园 5 次, 森林打开")
	var money := g.money
	var out := g.go_out("forest")
	check(out.item == "apple" or out.item == "coin", "森林里捡到东西")
	check(int(g.items.get("apple", 0)) == 1 or g.money > money)


func test_lakeside_opens_after_five_apples() -> void:
	var g := _game()
	g.items["apple"] = 5
	for i in 5:
		g.pet.hunger = 1
		g.act("food", "apple")
	check("lakeside" in g.outings, "吃 5 个苹果, 湖边打开")
	var money := g.money
	g.go_out("lakeside")
	check(g.money >= money + 8, "钓到魔晶")


func test_night_market_opens_in_the_evening() -> void:
	var g := _game()
	g.go_out("park")
	check(not "night" in g.outings, "上午出门不行")
	Helpers.care(g.pet, T0 + 9 * HOUR + 30 * 60)  # 照顾到晚上 7:30
	g.fixed_time = T0 + 9 * HOUR + 30 * 60
	g.tick()
	g.go_out("park")
	check("night" in g.outings, "晚上 7 点到 9 点出门, 夜市打开")
	var out := g.go_out("night")
	check(out.item in ["cake", "icecream"], "夜市送了好吃的")


func test_outing_progress_survives_save() -> void:
	var g := _game()
	for i in 5:
		g.go_out("park")
	var g2 := Game.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	eq(g2.stats.park, 5)
	check("forest" in g2.outings)
	eq(g2.out_at.park, T0)
