extends TestCase
## 第三版: 住的地方 (草原、湖泊、天空岛各一整套魔物, 学 Paradise; 用户 2026-10-25 选了「每个地方一整套」)。
## 小孩长成少年时住在哪就长成哪里的; 养大一只成年就打开下一个地方。

const T0 := Helpers.T0
const DAY := 86400


func test_every_place_has_a_full_set() -> void:
	var all := {}
	for place in Species.PLACES:
		var d: Dictionary = Species.PLACES[place]
		for k in ["teen_good", "teen_bad", "secret", "best", "good", "mid", "low", "bad1", "bad2"]:
			var id: String = d[k]
			check(Species.DATA.has(id), "%s 的 %s 是一个种类" % [place, k])
			check(Art.HALF.has(id), "%s 画了" % id)
			check(not all.has(id), "%s 只属于一个地方" % id)
			all[id] = true
			eq(Species.place_of(id), place)
		check(Species.DATA[d.secret].get("secret", false), "%s 的隐藏种类标了隐藏" % place)
	eq(Species.ORDER.size(), 2 + 9 * Species.PLACES.size(), "图鉴: 宝宝、小孩 + 每个地方 9 种")
	for id in Species.ORDER:
		check(Species.DATA.has(id))


func test_child_grows_into_the_teen_of_where_it_lives() -> void:
	for place in Species.PLACES:
		var p := Helpers.at("jianjiao")
		p.place = place
		eq(Species.next_form(p), Species.PLACES[place].teen_good, "住在%s, 照顾得好" % place)
		p.mistakes = 3
		eq(Species.next_form(p), Species.PLACES[place].teen_bad, "住在%s, 失误多" % place)


func test_teen_stays_in_its_own_set_after_moving() -> void:
	var p := Helpers.at("paopao")
	p.place = "sky"  # 长成少年以后搬家
	p.mistakes = 0
	p.discipline = 4
	p.mistakes_life = 2
	eq(Species.next_form(p), "hailong", "湖泊的少年还是长成湖泊的成年")


func test_whole_life_in_the_lake() -> void:
	var p := Helpers.pet(Rules.STRICT)
	p.place = "lake"
	Helpers.care(p, T0 + 4 * DAY)
	eq(p.stage, "adult")
	eq(Species.place_of(p.species), "lake", "从蛋养到成年都在湖泊 (长成了 %s)" % p.species)


func test_places_open_one_by_one() -> void:
	var g := Game.new()
	g.use_system_tz = false
	eq(g.places, ["grass"], "一开始只有草原")
	g.dex["huolong"] = 1
	g._unlock_places()
	eq(g.places, ["grass", "lake"], "养大一只成年, 打开湖泊")
	has_text(g.messages[-1].text, "湖泊")
	g.dex["hailong"] = 1
	g._unlock_places()
	eq(g.places, ["grass", "lake", "sky"], "再养大一只, 打开天空岛")


func test_unlock_when_growing_up() -> void:
	var g := Game.new()
	g.use_system_tz = false
	g.pet = Helpers.at("yishou")
	Helpers.care(g.pet, T0 + 2 * DAY + 3600)
	g._take_events()
	eq(g.pet.stage, "adult")
	check("lake" in g.places, "长成成年那一刻就打开湖泊")


func test_new_egg_in_a_place_and_moving() -> void:
	var g := Game.new()
	g.use_system_tz = false
	g.new_egg(Rules.EASY, T0, "lake")
	eq(g.pet.place, "grass", "还没打开的地方不能去")
	g.places.append("lake")
	g.new_egg(Rules.EASY, T0, "lake")
	eq(g.pet.place, "lake")
	eq(g.move("sky"), "no", "没打开的地方不能搬")
	eq(g.move("grass"), "ok")
	eq(g.pet.place, "grass")
	g.pet = Helpers.at("huolong")
	eq(g.move("lake"), "grown", "长大了搬家只换风景")


func test_old_saves_open_places_they_earned() -> void:
	var g := Game.new()
	g.dex = {"huolong": 2}
	var d := g.to_dict()
	d.erase("places")
	var g2 := Game.from_dict(JSON.parse_string(JSON.stringify(d)))
	eq(g2.places, ["grass", "lake", "sky"], "以前养大过两只成年, 两个新地方都打开")
