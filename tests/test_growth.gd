extends TestCase
## 长大: 长成哪一种看照顾失误和管教; 睡着的时候不长; 成年时定下寿命和什么时候想离开。

const T0 := Helpers.T0
const HOUR := 3600
const DAY := 86400


func _form(id: String, mistakes: int, discipline: int, life_mistakes := 0, diff := Rules.STRICT) -> String:
	var p := Helpers.at(id, diff)
	p.mistakes = mistakes
	p.discipline = discipline
	p.mistakes_life = maxi(life_mistakes, mistakes)
	return Species.next_form(p)


func test_child_to_teen_by_mistakes() -> void:
	eq(_form("jianjiao", 0, 0), "yishou", "没失误长成小翼兽")
	eq(_form("jianjiao", 2, 0), "yishou", "失误 2 次还是小翼兽")
	eq(_form("jianjiao", 3, 0), "nigui", "失误 3 次长成小泥怪 (原版也以 3 次为界)")


func test_teen_to_adult_table() -> void:
	eq(_form("yishou", 0, 4, 0), "xingguang", "原版严格, 一辈子没失误、管教满: 隐藏的星光龙")
	eq(_form("yishou", 0, 4, 0, Rules.EASY), "huolong", "放宽难度养不出星光龙, 最好是火焰龙 (用户 2026-10-25 定的)")
	eq(_form("yishou", 0, 4, 2), "huolong", "少年没失误、管教满: 火焰龙")
	eq(_form("yishou", 1, 2, 2), "shuiling", "少年失误少、管教不满: 水灵")
	eq(_form("yishou", 3, 4, 3), "linlu")
	eq(_form("yishou", 5, 0, 5), "shixiang")
	eq(_form("nigui", 0, 3, 3), "shixiang", "调皮的但管教得好: 石头魔像")
	eq(_form("nigui", 2, 0, 5), "mogu")
	eq(_form("nigui", 5, 0, 8), "xiaomo")


func test_every_adult_is_reachable() -> void:
	var reached := {}
	var easy := {}
	for place in Species.PLACES:
		for id in [Species.PLACES[place].teen_good, Species.PLACES[place].teen_bad]:
			for m in 7:
				for d in 5:
					for life in [0, 3, 9]:
						reached[_form(id, m, d, life)] = true
						easy[_form(id, m, d, life, Rules.EASY)] = true
	for id in Species.ORDER:
		if Species.DATA[id].stage == "adult" and Species.place_of(id) != "":  # 混血和大奖那两族在 test_v9 里试
			var secret: bool = Species.DATA[id].get("secret", false)
			check(reached.has(id), "%s 能养出来" % id)
			check(easy.has(id) != secret, "放宽: %s %s" % [id, "养不出来" if secret else "能养出来"])


func test_perfect_care_from_egg_grows_all_the_way() -> void:
	var p := Helpers.pet(Rules.STRICT)
	Helpers.care(p, T0 + 4 * DAY)
	eq(p.stage, "adult", "四天后成年了")
	eq(p.mistakes_life, 0, "勤快的主人一次失误都没有")
	check(p.species == "xingguang" or p.species == "huolong",
		"没失误长成星光龙或火焰龙 (看管教满没满), 实际是 %s, 管教 %d" % [p.species, p.discipline])


func test_does_not_grow_while_asleep() -> void:
	# 晚上 10 点做出一只小孩: 24 小时后又是晚上 10 点, 它在睡觉, 要等第二天早上 9 点醒了才长大
	var p := Helpers.at("jianjiao", Rules.EASY, T0 + 12 * HOUR)
	Helpers.care(p, T0 + 12 * HOUR + DAY + HOUR)
	eq(p.stage, "child", "睡着了还没长")
	Helpers.care(p, T0 + 2 * DAY - HOUR - 5 * 60)  # 第三天早上 8:55
	eq(p.stage, "child")
	Helpers.care(p, T0 + 2 * DAY - HOUR)  # 早上 9 点醒
	eq(p.stage, "teen", "醒了就长大")


func test_adult_gets_lifespan_and_leave_time() -> void:
	for s in 50:
		var p := Helpers.at("mogu", Rules.EASY, T0, s + 1)
		check(p.lifespan >= Rules.LIFESPAN_MIN, "寿命至少 8 岁 (实际 %d)" % p.lifespan)
		check(p.lifespan <= 10 + Rules.LIFESPAN_RANDOM[1])
		eq(p.leave_ask_at, T0 + Rules.LEAVE_ASK_AFTER, "成年 3 天后想离开")


func test_growing_records_events() -> void:
	var p := Helpers.pet()
	p.advance(T0 + 6 * 60)
	var kinds := []
	for e in p.events:
		kinds.append(e.kind)
	check("grow" in kinds, "孵出来算一次长大")
	eq(p.events[0].from, "egg")
