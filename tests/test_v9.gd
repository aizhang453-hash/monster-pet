extends TestCase
## 第九版: 混血 (特定的一对 + 照顾得好)、大奖的两族 (特定的一对生下不一样的蛋)、算命的 / 算命屋、身上的遗传 (翅膀、尾巴)。
## 存档写到临时文件夹, 不碰真的存档。

const T0 := Helpers.T0
const DAY := Rules.DAY


func before_each() -> void:
	SaveGame.dir = OS.get_temp_dir().path_join("monster_pet_test_v9_%d" % OS.get_process_id())


func after_each() -> void:
	SaveGame.erase()
	DirAccess.remove_absolute(SaveGame.dir)


## 一只爸妈是 pair 的少年, 少年时失误 mistakes 次, 到时候长成哪一种
func _grow_teen(teen: String, pair: Array, mistakes: int, diff := Rules.EASY, discipline := 4) -> String:
	var p := Helpers.at(teen, diff)
	p.pair = pair
	p.mistakes = mistakes
	p.mistakes_life = mistakes
	p.discipline = discipline
	return Species.next_form(p)


func _game(id := "huolong") -> Game:
	var g := Game.new()
	g.use_system_tz = false
	g.fixed_time = T0
	g.places = ["grass", "lake", "sky"]
	g.pet = Helpers.at(id)
	return g


# ---------------------------------------------------------------- 混血

func test_hybrid_needs_the_pair_and_good_care() -> void:
	eq(_grow_teen("yishou", ["huolong", "hailong"], 0), "zhengqilong", "火焰龙 + 海龙的孩子照顾得好: 蒸汽龙")
	eq(_grow_teen("yishou", ["hailong", "huolong"], 1), "zhengqilong", "谁先谁后都一样")
	eq(_grow_teen("yishou", ["huolong", "hailong"], 3), "linlu", "照顾不好还是长成普通的")
	eq(_grow_teen("nigui", ["huolong", "hailong"], 0, Rules.EASY, 3), "shixiang", "调皮的少年不会长成混血")
	eq(_grow_teen("yishou", ["huolong", "zhenzhu"], 0), "huolong", "不是那一对, 照常长")
	eq(_grow_teen("yishou", [], 0), "huolong", "第一代没有爸妈")
	eq(_grow_teen("yishou", ["huolong", "hailong"], 0, Rules.STRICT), "zhengqilong", "原版严格: 混血比隐藏的优先")
	eq(_grow_teen("paopao", ["huolong", "hailong"], 0), "zhengqilong", "住在哪都一样 (湖泊的少年)")


func test_every_hybrid_and_line_can_happen() -> void:
	var seen := {}
	for id in Species.HYBRIDS:
		var pair: Array = Species.HYBRIDS[id]
		check(Species.DATA[id].get("hybrid", false), "%s 标了混血" % id)
		eq(Species.DATA[id].stage, "adult")
		for sp in pair:
			check(Species.place_of(sp) != "" and not Species.DATA[sp].get("secret", false),
				"%s 的爸妈 %s 是媒人会介绍的那种" % [id, sp])
		var key := ",".join(pair.duplicate().map(func(x): return str(x)))
		check(not seen.has(key), "%s 这一对只生一种" % id)
		seen[key] = true
		eq(Species.hybrid_of(pair), id)
		check(id in Species.ORDER, "%s 在图鉴里" % id)
	for line in Species.LINES:
		var l: Dictionary = Species.LINES[line]
		check(Species.DATA[l.pair[0]].get("hybrid", false), "%s 要先养出混血「%s」" % [line, l.pair[0]])
		check(Species.place_of(l.pair[1]) != "", "另一位是媒人会介绍的")
		eq(Species.line_of(l.pair), line)
		eq(Species.hybrid_of(l.pair), "", "大奖的一对不会再算混血")
		for k in ["baby", "child", "teen", "good", "mid", "bad"]:
			eq(Species.DATA[l[k]].get("line", ""), line, "%s 是 %s 那一族的" % [l[k], line])
			eq(Species.DATA[l[k]].stage, {"baby": "baby", "child": "child", "teen": "teen"}.get(k, "adult"))
			check(Art.has(l[k]), "%s 有图" % l[k])
		eq(Art.rows(l.child), Art.rows(l.baby), "小孩跟宝宝一个样子")


func test_special_partners() -> void:
	check("hailong" in Species.special_partners("huolong"))
	check("huolong" in Species.special_partners("hailong"), "两边都认得")
	check("fengying" in Species.special_partners("zhengqilong"), "蒸汽龙跟风之鹰能生大奖蛋")
	eq(Species.special_partners("xingguang"), [], "星光龙没有特别有缘的")


# ---------------------------------------------------------------- 大奖

func test_line_egg_hatches_into_its_own_baby_and_grows() -> void:
	var g := _game("zhengqilong")
	g.new_egg(Rules.EASY, T0, "grass", {"gen": 3, "hue": 0.5, "feature": "horn", "extra": "wing", "pair": ["fengying", "zhengqilong"]})
	eq(g.pet.pair, ["fengying", "zhengqilong"])
	has_text(g.messages[-1].text, "闪闪发光")
	Helpers.care(g.pet, T0 + 30 * 60)
	eq(g.pet.species, "yunlong_baby", "孵出来是小云龙")
	Helpers.care(g.pet, T0 + 3 * Rules.HOUR)
	eq(g.pet.species, "yunlong_child", "长成小孩还是小云龙的样子")
	eq(g.pet.stage, "child")
	Helpers.care(g.pet, T0 + 2 * DAY)
	eq(g.pet.species, "yunlong_teen")
	Helpers.care(g.pet, T0 + 4 * DAY)
	eq(g.pet.species, "yunlong_good", "勤快地照顾: 苍穹龙")
	eq(Training.bonus("yunlong_good", "guard"), 15, "大奖照顾得好的那种三样都加 15")


func test_line_adult_depends_on_care() -> void:
	for m in [[0, "dujiao_good"], [1, "dujiao_good"], [3, "dujiao_mid"], [6, "dujiao_bad"]]:
		var p := Helpers.at("dujiao_teen")
		p.mistakes = m[0]
		eq(Species.next_form(p), m[1], "少年时失误 %d 次" % m[0])


func test_marriage_remembers_the_pair() -> void:
	var g := _game()
	g.pet.match_offers = [{"species": "hailong", "hue": 0.6, "feature": "fin", "extra": "tail"}]
	g.pet.wants_match = true
	g.act("match", 0)
	eq(g.pet.end_reason, "married")
	eq(g.next_egg.pair, ["huolong", "hailong"], "蛋记得爸妈是哪两种")
	check(g.next_egg.extra in ["", "tail"], "身上的东西从爸妈之一来")
	g.new_egg(Rules.EASY, g.pet.now, "grass", g.next_egg.duplicate())
	eq(g.pet.pair, ["huolong", "hailong"])
	check(g.save())
	eq(Game.load_saved().pet.pair, ["huolong", "hailong"], "存下来了")


func test_old_age_egg_has_no_pair() -> void:
	var g := _game()
	g.pet.lifespan = 1
	Helpers.care(g.pet, T0 + DAY + Rules.HOUR)
	g.fixed_time = g.pet.now
	g.tick()
	eq(g.pet.end_reason, "old")
	eq(g.next_egg.pair, [], "老死留下的蛋只有一个爸妈, 不会是混血")


func test_hybrid_grow_message() -> void:
	var g := _game()
	var text := g.describe({"kind": "grow", "id": "zhengqilong", "from": "yishou"})
	has_text(text, "蒸汽龙")
	has_text(text, "有缘")
	has_text(g.describe({"kind": "grow", "id": "dujiao_baby", "from": "egg"}), "独角兽一族")


# ---------------------------------------------------------------- 媒人和算命的

func test_matchmaker_often_brings_a_special_partner() -> void:
	var rng := RandomNumberGenerator.new()
	var hits := 0
	for i in 300:
		rng.seed = i + 1
		var offers := Genes.offers(["grass", "lake", "sky"], "huolong", rng)
		eq(offers.size(), Genes.OFFERS)
		var names := offers.map(func(o): return o.species)
		check(not "huolong" in names)
		for o in offers:
			check(not Species.DATA[o.species].get("hybrid", false), "不介绍混血的")
			check(o.extra == "" or Genes.EXTRAS.has(o.extra), "身上的东西认识")
		if "hailong" in names:
			hits += 1
	check(hits > 90 and hits < 200, "海龙差不多一半时候会来 (三次里带一次 + 本来就可能来): %d/300" % hits)
	rng.seed = 7
	var none := 0
	for i in 100:
		var offers := Genes.offers(["grass"], "huolong", rng)
		none += int(offers.any(func(o): return o.species == "hailong"))
	eq(none, 0, "湖泊没打开, 海龙不会来")


func test_fortune_preview() -> void:
	var pv := Genes.preview({"species": "huolong", "feature": "flower", "extra": "wing"}, {"species": "hailong", "hue": 0.6, "extra": ""})
	eq(pv.hybrid, "zhengqilong")
	eq(pv.line, "")
	eq(pv.features, ["flower", "fin"])
	eq(pv.extras, ["wing", ""])
	check(absf(pv.hue - Genes.mix(Art.main_hue("huolong"), 0.6)) < 0.0001, "颜色是两个的中间")
	var text := Genes.fortune_text(pv, {})
	has_text(text, "有缘")
	has_text(text, "从没见过")
	check(not "蒸汽龙" in text, "图鉴里没有, 不说名字")
	has_text(Genes.fortune_text(pv, {"zhengqilong": 1}), "蒸汽龙")
	has_text(text, "小翅膀")
	has_text(text, "也可能什么都没有")
	var plain := Genes.preview({"species": "huolong"}, {"species": "linlu"})
	eq(plain.hybrid, "")
	check(not "有缘" in Genes.fortune_text(plain, {}))
	has_text(Genes.fortune_text(plain, {}), "什么都没有")
	var big := Genes.preview({"species": "feilu"}, {"species": "zhenzhu"})
	eq(big.line, "dujiao")
	has_text(Genes.fortune_text(big, {}), "大奖")


# ---------------------------------------------------------------- 身上的遗传

func test_extra_is_inherited_from_a_parent() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var got := {}
	for i in 60:
		var c := Genes.child({"species": "huolong", "extra": "wing"}, {"species": "hailong", "extra": "tail"}, 1, rng)
		got[c.extra] = true
	eq(got.keys().size(), 2, "有时像爸爸、有时像妈妈")
	check(got.has("wing") and got.has("tail"))
	var solo := Genes.child({"species": "huolong", "extra": "startail"}, {}, 1, rng)
	eq(solo.extra, "startail", "老死留下的蛋照它自己的")


func test_extra_shows_from_teen_and_is_drawn() -> void:
	for e in Genes.EXTRAS:
		check(Art.has("extra_" + e), "%s 有图" % e)
	eq(Art.extra_parts("jianjiao", "wing"), [], "小孩还没长出来")
	eq(Art.extra_parts("huolong", "wing").size(), 2, "翅膀两边各一个")
	eq(Art.extra_parts("huolong", "tail").size(), 1, "尾巴一条")
	var right: Vector2 = Art.extra_parts("huolong", "tail")[0][1]
	var left: Vector2 = Art.extra_parts("huolong", "tail", true)[0][1]
	check(right.x > 8 and left.x < 8, "魔物翻过来, 尾巴换到另一边")
	eq(Art.look_texture({"species": "huolong", "extra": "wing"}, 4).get_size(), Vector2(104, 64), "有翅膀的图宽一点")
	eq(Art.look_texture({"species": "huolong", "extra": ""}, 4).get_size(), Vector2(64, 64))
	for id in Species.ORDER:
		if Species.DATA[id].stage in ["teen", "adult"]:
			for e in Genes.EXTRAS:
				for part in Art.extra_parts(id, e):
					var at: Vector2 = part[1]
					check(at.x >= -5 and at.x + Art.size_of(part[0]).x <= 21, "%s 的 %s 不会画得太远" % [id, e])


func test_pair_and_extra_are_saved() -> void:
	var g := _game()
	g.pet.extra = "batwing"
	g.pet.pair = ["linlu", "fengying"]
	check(g.save())
	var back := Game.load_saved()
	eq(back.pet.extra, "batwing")
	eq(back.pet.pair, ["linlu", "fengying"])
	eq(Species.hybrid_of(back.pet.pair), "feilu", "读回来还认得是哪一对")


# ---------------------------------------------------------------- 别的结婚办法: 朋友和戒指

func test_befriend_and_gift() -> void:
	var g := _game()
	eq(g.befriend("yishou"), "", "少年不算朋友 (只交成年的)")
	eq(g.befriend("hailong"), "交情 1/%d" % Rules.FRIEND_MAX)
	for i in 10:
		g.befriend("hailong")
	eq(int(g.friends.hailong.hearts), Rules.FRIEND_MAX, "交情最多 5 颗心")
	g.befriend("linlu")
	g.money = 15
	has_text(g.act("gift", "linlu"), "交情 2/")
	eq(g.money, 15 - Rules.GIFT_PRICE)
	has_text(g.act("gift", "linlu"), "今天已经")
	eq(g.money, 15 - Rules.GIFT_PRICE, "一天只能送一次")
	g.fixed_time += DAY
	has_text(g.act("gift", "linlu"), "魔晶不够")
	eq(g.act("gift", "nobody"), "还不认识它呢")


func test_propose_with_a_ring() -> void:
	var g := _game()
	g.befriend("hailong")
	has_text(g.act("propose", "hailong"), "买个戒指")
	g.items["ring"] = 1
	has_text(g.act("propose", "hailong"), "多认识认识")
	eq(int(g.items.ring), 1, "被婉拒了戒指还在")
	eq(g.pet.end_reason, "")
	g.befriend("hailong")
	g.befriend("hailong")
	g.act("propose", "hailong")
	eq(g.pet.end_reason, "married", "交情 3 颗心, 普通戒指就答应了")
	check(not g.items.has("ring"), "戒指用掉了")
	check(not g.friends.has("hailong"), "娶走的朋友搬去爸妈家了")
	eq(g.next_egg.pair, ["huolong", "hailong"])


func test_diamond_ring_always_works() -> void:
	var g := _game()
	g.befriend("yunyang")
	g.items["ring"] = 1
	g.items["diamond_ring"] = 1
	g.act("propose", "yunyang")
	eq(g.pet.end_reason, "married", "交情只有 1 颗心, 钻石戒指也一定答应")
	eq(int(g.items.ring), 1, "普通戒指不够交情, 用的是钻石的")
	check(not g.items.has("diamond_ring"))


func test_propose_needs_a_grown_up_at_home() -> void:
	var g := _game("jianjiao")
	g.befriend("hailong")
	g.items["diamond_ring"] = 1
	has_text(g.act("propose", "hailong"), "长大了")
	var h := _game()
	h.befriend("huolong")
	h.items["diamond_ring"] = 1
	has_text(h.act("propose", "huolong"), "同一种")
	eq(int(h.items.diamond_ring), 1)


func test_best_friend_comes_to_propose() -> void:
	var g := _game()
	for i in Rules.FRIEND_MAX:
		g.befriend("qingwa")
	g.tick()
	eq(g.proposal, "qingwa", "交情满了, 它来求婚了")
	check(g.messages.any(func(m): return "求婚" in m.text))
	has_text(g.act("proposal", false), "下次")
	eq(g.proposal, "")
	g.tick()
	eq(g.proposal, "", "一天只来一次")
	g.fixed_time += DAY
	Helpers.care(g.pet, g.fixed_time)
	g.tick()
	eq(g.proposal, "qingwa", "第二天又来了")
	g.act("proposal", true)
	eq(g.pet.end_reason, "married")
	eq(g.pet.partner.species, "qingwa")


# ---------------------------------------------------------------- 别的结婚办法: 约会广场

func test_date_plaza() -> void:
	var kid := _game("jianjiao")
	has_text(kid.go_date(0).text, "还没长大")
	var g := _game()
	g.pet.place = "lake"
	var offers := g.date_list()
	eq(offers.size(), Rules.DATE_OFFERS)
	for o in offers:
		eq(Species.place_of(o.species), "lake", "从住的地方来")
	eq(g.date_list(), offers, "没约之前一直是这几位")
	g.pet.hunger = 1
	var res := g.go_date(0)
	check(not res.ok, "饿着约会不顺利")
	has_text(res.text, "饿")
	check(g.friends.has(offers[0].species), "约过一次就认识了")
	check(g.date_list() != offers, "约过就换一批")
	g.pet.hunger = 4
	g.go_date(0)
	g.go_date(0)
	eq(g.dates_left(), 0)
	has_text(g.go_date(0).text, "明天再来")
	g.fixed_time += DAY
	Helpers.care(g.pet, g.fixed_time)
	eq(g.dates_left(), Rules.DATE_PER_DAY, "第二天又能约了")


func test_special_pair_date_always_works_and_can_marry() -> void:
	var g := _game()
	g.pet.place = "lake"
	g.date_offers = [{"species": "hailong", "hue": 0.6, "feature": "fin", "extra": ""}]
	g.pet.hunger = 2
	g.pet.happy = 2
	var res := g.go_date(0)
	check(res.ok, "特别有缘的一定顺利")
	eq(g.date_ok.species, "hailong")
	has_text(g.act("date_propose", false), "好朋友")
	eq(g.pet.end_reason, "")
	check(g.friends.has("hailong"))
	g.date_offers = [{"species": "hailong", "hue": 0.6, "feature": "fin", "extra": ""}]
	g.go_date(0)
	g.act("date_propose", true)
	eq(g.pet.end_reason, "married", "约会顺利就能求婚 (不用戒指)")
	eq(Species.hybrid_of(g.next_egg.pair), "zhengqilong", "这一对生的孩子照顾得好会长成蒸汽龙")


func test_date_success_depends_on_mood() -> void:
	var good := 0
	var meh := 0
	for i in 200:
		var g := _game("huolong")
		g.rng.seed = i + 1
		g.date_offers = [{"species": "qingwa", "hue": 0.3, "feature": "leaf", "extra": ""}]
		g.pet.hunger = 4
		g.pet.happy = 4
		good += int(g.go_date(0).ok)
		var h := _game("huolong")
		h.rng.seed = i + 1
		h.date_offers = [{"species": "qingwa", "hue": 0.3, "feature": "leaf", "extra": ""}]
		h.pet.hunger = 2
		h.pet.happy = 2
		meh += int(h.go_date(0).ok)
	check(good > 160, "吃饱又开心: 差不多 9 成顺利 (%d/200)" % good)
	check(meh > 70 and meh < 140, "都只有 2 颗心: 一半左右 (%d/200)" % meh)


# ---------------------------------------------------------------- 别的结婚办法: 节日嘉宾

func test_festival_guest() -> void:
	var xmas := int(Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 12, "day": 25, "hour": 10, "minute": 0, "second": 0}))
	var g := Game.new()
	g.use_system_tz = false
	g.fixed_time = xmas
	g.places = ["grass", "lake", "sky"]
	g.pet = Helpers.at("zhenzhu", Rules.EASY, xmas)
	g.pet.place = "lake"
	eq(g.festival(), "christmas")
	var offers := g.date_list()
	var guest: Array = offers.filter(func(o): return o.get("guest", false))
	eq(guest.size(), 1, "约会广场来了一位节日嘉宾")
	eq(guest[0].species, Festivals.GUESTS.christmas, "圣诞节的嘉宾是飞鹿")
	g.pet.match_at = xmas
	g.pet.events.append({"kind": "match_ask"})
	g._take_events()
	check(g.pet.match_offers.any(func(o): return o.species == "feilu" and o.get("guest", false)), "媒人也带来了节日嘉宾")
	var i: int = g.date_offers.find(guest[0])
	g.go_date(i)
	g.act("date_propose", true)
	eq(g.pet.end_reason, "married")
	check(not g.pet.partner.has("guest"), "结了婚就不是嘉宾了")
	eq(Species.line_of(g.next_egg.pair), "dujiao", "珍珠贝 + 飞鹿 (嘉宾) 生下独角兽一族的大奖蛋")
	var plain := _game()
	check(not plain.date_list().any(func(o): return o.get("guest", false)), "平时没有嘉宾")
	for f in Festivals.GUESTS:
		check(Festivals.LIST.has(f) and Species.DATA[Festivals.GUESTS[f]].get("hybrid", false), "%s 的嘉宾是混血魔物" % f)


func test_park_and_walks_make_friends() -> void:
	var g := _game()
	for i in 12:
		g.fixed_time += 3 * Rules.HOUR
		Helpers.care(g.pet, g.fixed_time)
		g.go_out("park")
	check(not g.friends.is_empty(), "在公园交到了朋友")
	for sp in g.friends:
		eq(Species.DATA[sp].stage, "adult")
		check(int(g.friends[sp].hearts) >= 1)


func test_friends_and_dates_are_saved() -> void:
	var g := _game()
	g.befriend("hailong")
	g.befriend("hailong")
	g.items["ring"] = 2
	g.date_list()
	g.go_date(0)
	check(g.save())
	var back := Game.load_saved()
	eq(int(back.friends.hailong.hearts), 2)
	eq(back.friends.hailong.look.species, "hailong")
	eq(int(back.items.ring), 2)
	eq(back.dates_today, 1)
	eq(back.date_day, g.date_day)


# ---------------------------------------------------------------- 乱玩

## 电脑乱玩结婚这一块: 约会、送礼物、求婚、答应求婚、去公园、买戒指, 结了婚就孵下一代接着玩; 每一步检查状态没坏
func test_random_marriage_play_never_breaks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261026
	var acts := ["date", "date_yes", "date_no", "gift", "propose", "proposal_yes", "proposal_no", "park", "ring", "diamond", "match_yes", "wait"]
	var married := 0
	var specials := {}
	for n in 120:
		var g := _game(["huolong", "hailong", "fengying", "linlu", "zhengqilong", "feilu"][n % 6])
		g.rng.seed = n + 1
		g.money = 2000
		for step in 400:
			if g.pet.is_over():
				if g.pet.end_reason == "married":
					married += 1
					eq(Array(g.next_egg.pair).size(), 2, "结婚生的蛋记得爸妈")
					var sp := Species.hybrid_of(g.next_egg.pair) + Species.line_of(g.next_egg.pair)
					if sp != "":
						specials[sp] = true
					g.new_egg(Rules.EASY, g.clock(), "grass", g.next_egg.duplicate())
				else:
					g.new_egg(Rules.EASY, g.clock(), "grass")
			g.fixed_time += rng.randi_range(5 * 60, 5 * Rules.HOUR)
			Helpers.care(g.pet, g.fixed_time, 20 * 60)
			g.tick()
			var keys := g.friends.keys()
			var anyone: String = keys[rng.randi() % keys.size()] if not keys.is_empty() else "hailong"
			match acts[rng.randi() % acts.size()]:
				"date":
					g.go_date(rng.randi() % Rules.DATE_OFFERS)
				"date_yes":
					g.act("date_propose", true)
				"date_no":
					g.act("date_propose", false)
				"gift":
					g.act("gift", anyone)
				"propose":
					g.act("propose", anyone)
				"proposal_yes":
					g.act("proposal", true)
				"proposal_no":
					g.act("proposal", false)
				"park":
					g.go_out("park")
				"ring":
					g.buy("ring")
				"diamond":
					g.buy("diamond_ring")
				"match_yes":
					if g.pet.wants_match:
						g.act("match", 0)
			for sp in g.friends:
				var h := int(g.friends[sp].hearts)
				check(h >= 1 and h <= Rules.FRIEND_MAX, "交情在 1–5 之间: %s %d" % [sp, h])
				eq(Species.DATA[sp].stage, "adult", "朋友都是成年的")
				check(not g.friends[sp].look.has("guest"))
			check(g.dates_today >= 0 and g.dates_today <= Rules.DATE_PER_DAY, "一天最多约 3 次")
			check(g.proposal == "" or g.friends.has(g.proposal), "来求婚的是朋友")
			check(int(g.items.get("ring", 0)) >= 0 and int(g.items.get("diamond_ring", 0)) >= 0, "戒指不会是负数")
			check(g.money >= 0, "魔晶不会是负数")
			check(Species.DATA.has(g.pet.species), "种类认识")
			check(g.pet.partner.is_empty() or g.pet.end_reason == "married", "有对象就是结婚了")
			if failures.size() > 20:
				return
	check(married > 100, "乱玩也结了不少婚: %d" % married)
	print("  结婚乱玩: 结了 %d 次婚, 碰到的特别的一对: %s" % [married, specials.keys()])


# ---------------------------------------------------------------- 每个地方的小孩 (学乐园)

func test_child_looks_like_where_it_lives() -> void:
	for place in Species.PLACE_ORDER:
		var p := Helpers.at("tuanzi")
		p.place = place
		Helpers.care(p, T0 + 2 * Rules.HOUR)
		eq(p.species, Species.PLACES[place].child, "%s 的宝宝长成那里的小孩" % place)
		eq(p.stage, "child")


func test_child_changes_an_hour_after_moving() -> void:
	var g := _game("jianjiao")
	g.places = ["grass", "lake", "sky"]
	g.pet.mistakes = 1
	eq(g.move("lake"), "child", "小孩搬家, 过一会儿会变样")
	eq(g.pet.species, "jianjiao", "刚搬过去还没变")
	g.fixed_time += 50 * 60
	Helpers.care(g.pet, g.fixed_time)
	g.tick()
	eq(g.pet.species, "jianjiao", "不到一小时还没变")
	g.fixed_time += 15 * 60
	Helpers.care(g.pet, g.fixed_time)
	g.tick()
	eq(g.pet.species, "shuizhu", "住满一小时变成湖泊的小孩")
	eq(g.pet.stage, "child")
	eq(g.pet.mistakes, 1, "变样子不算长大, 失误还在")
	check(g.dex.has("shuizhu"), "记进图鉴")
	eq(g.move("sky"), "child")
	g.fixed_time += 20 * 60
	Helpers.care(g.pet, g.fixed_time)
	eq(g.move("lake"), "ok", "又搬回来, 本来就是湖泊的样子, 不用变")
	eq(g.pet.morph_at, 0)
	g.fixed_time += 2 * Rules.HOUR
	Helpers.care(g.pet, g.fixed_time)
	eq(g.pet.species, "shuizhu")


func test_lake_child_grows_into_lake_teen() -> void:
	var p := Helpers.at("shuizhu")
	p.place = "lake"
	eq(Species.next_form(p), "paopao", "湖泊的小孩长成湖泊的少年")
	p.place = "sky"
	eq(Species.next_form(p), "yunduo", "长成少年时住在哪, 就是哪里的少年 (跟以前一样)")
	var t := Helpers.at("yishou")
	t.set_place("lake")
	eq(t.morph_at, 0, "少年搬家不变样子")
	var line := Helpers.at("yunlong_child")
	line.set_place("lake")
	eq(line.morph_at, 0, "大奖那一族的小孩不跟着地方变")
