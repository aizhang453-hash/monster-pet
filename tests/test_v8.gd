extends TestCase
## 第八版: 出门吃饭、它自己出去散步、赶走捣蛋精、魔物养的小宠物、性格。存档写到临时文件夹, 不碰真的存档。

const T0 := Helpers.T0
const HOUR := Rules.HOUR


func before_each() -> void:
	SaveGame.dir = OS.get_temp_dir().path_join("monster_pet_test_v8_%d" % OS.get_process_id())


func after_each() -> void:
	SaveGame.erase()
	DirAccess.remove_absolute(SaveGame.dir)


func _game(id := "jianjiao") -> Game:
	var g := Game.new()
	g.use_system_tz = false
	g.fixed_time = T0
	g.pet = Helpers.at(id)
	return g


# ---------------------------------------------------------------- 出门吃饭

func test_eat_out_costs_money_and_fills_up() -> void:
	var g := _game()
	g.money = 50
	g.pet.hunger = 1
	g.pet.happy = 3
	var res := g.eat_out("noodle")
	check(res.ok, res.text)
	eq(g.money, 50 - Outings.SHOPS.noodle.price, "拉面要魔晶")
	eq(g.pet.hunger, 4, "吃得饱饱的")
	eq(g.pet.happy, 4)
	has_text(res.text, "拉面")
	res = g.eat_out("bakery")
	check(not res.ok, "饱了吃不下面包")
	has_text(res.text, "吃不下")
	eq(g.money, 50 - Outings.SHOPS.noodle.price, "吃不下不收钱")
	res = g.eat_out("sweets")
	check(res.ok, "甜点还吃得下 (只加开心)")
	g.money = 3
	g.pet.hunger = 1
	res = g.eat_out("bakery")
	check(not res.ok)
	has_text(res.text, "魔晶不够")


func test_eat_out_needs_to_be_able_to_go_out() -> void:
	var g := _game("tuanzi")
	g.money = 50
	check(not g.eat_out("bakery").ok, "宝宝还不能出门")
	check("food" in g.outings, "美食街一开始就能去")


# ---------------------------------------------------------------- 自己出去散步

func test_goes_for_a_walk_and_comes_back_with_something() -> void:
	var g := _game()
	var p := g.pet
	p.next_walk = p.now + 60
	p.next_pest = p.now + 99 * HOUR
	g.fixed_time = p.now + 120
	g.tick()
	check(p.walking(), "心情好的时候自己溜出去了")
	check(p.away(), "散步的时候不在家")
	eq(g.can_go_out(), "away", "散步的时候不能再出门")
	var before := [g.money, int(g.items.get("apple", 0)), p.happy]
	var hunger := p.hunger
	g.fixed_time = p.walk_until + 60
	g.tick()
	check(not p.walking(), "到时间自己回来")
	eq(p.hunger, hunger, "散步的时候饿不掉")
	check(g.money > before[0] or int(g.items.get("apple", 0)) > before[1] or g.last_gift == "heart",
		"带回来点东西 (魔晶、苹果或者交了朋友)")
	check(g.last_gift in ["coin", "apple", "heart"])


func test_does_not_walk_when_hungry_sick_or_messy() -> void:
	var m := Helpers.at("jianjiao")
	m.poop = 1
	m.poop_since = m.now
	m.next_walk = m.now + 60
	m.next_pest = m.now + 99 * HOUR
	m.advance(m.now + 120)
	check(not m.walking(), "家里有便便不出去 (不然便便放久了生病, 主人又没法打扫)")
	var p := Helpers.at("jianjiao")
	p.hunger = 1
	p.next_walk = p.now + 60
	p.advance(p.now + 120)
	check(not p.walking(), "饿着不出去")
	check(p.next_walk > p.now, "过一会儿再看")
	var q := Helpers.at("jianjiao")
	q._get_sick(false)
	q.next_walk = q.now + 60
	q.advance(q.now + 120)
	check(not q.walking(), "生病不出去")
	var b := Helpers.at("tuanzi")
	b.advance(b.now + 50 * 60)
	check(not b.walking(), "宝宝不会自己出去")


func test_call_it_back() -> void:
	var g := _game()
	g.pet.next_walk = g.pet.now + 60
	g.pet.next_pest = g.pet.now + 99 * HOUR
	g.fixed_time = g.pet.now + 120
	g.tick()
	check(g.pet.walking())
	var money := g.money
	has_text(g.act("sitter"), "叫回来")
	check(not g.pet.walking(), "叫回来了")
	eq(g.money, money, "没逛完, 没带东西")


func test_never_walks_into_bedtime() -> void:
	var p := Helpers.at("jianjiao")  # 晚上 8 点睡
	Helpers.care(p, T0 + 9 * HOUR + 30 * 60)  # 晚上 7 点半
	p.next_walk = p.now + 60
	p.next_pest = p.now + 99 * HOUR
	p.advance(p.now + 120)
	check(not p.walking(), "快睡觉了, 不出去")


# ---------------------------------------------------------------- 捣蛋精

func test_pest_comes_and_shoo_it_away() -> void:
	var g := _game()
	var p := g.pet
	p.next_walk = p.now + 99 * HOUR
	p.next_pest = p.now + 60
	g.fixed_time = p.now + 120
	g.tick()
	check(p.pest_at > 0, "捣蛋精来了")
	has_text(g.act("shoo"), "赶跑")
	eq(p.pest_at, 0)
	eq(p.happy, 4, "赶跑了就没事")
	eq(g.act("shoo"), "", "没有捣蛋精的时候点了也没反应")


func test_pest_left_alone_steals_and_scares() -> void:
	for diff in [Rules.EASY, Rules.STRICT]:
		var p := Helpers.at("jianjiao", diff)
		p.next_walk = p.now + 99 * HOUR
		p.next_pest = p.now + 60
		p.next_hunger = p.now + 99 * HOUR
		p.next_happy = p.now + 99 * HOUR
		p.advance(p.now + 120)
		check(p.pest_at > 0)
		p.advance(p.pest_at + Rules.PEST_WINDOW[diff] + 1)
		eq(p.pest_at, 0, "%s: 捣完乱走了" % diff)
		eq(p.hunger, 4, "不偷吃")
		eq(p.happy, 3, "吓了一跳 (开心 -1)")
		eq(p.mistakes, 0, "不算照顾失误")


func test_pest_leaves_when_it_falls_asleep() -> void:
	var p := Helpers.at("jianjiao")
	Helpers.care(p, T0 + 9 * HOUR + 50 * 60)  # 晚上 7 点 50
	p.pest_at = p.now
	p.advance(T0 + 10 * HOUR + 5 * 60)
	check(p.asleep)
	eq(p.pest_at, 0, "睡着了捣蛋精就走了")
	eq(p.happy, 4)


# ---------------------------------------------------------------- 小宠物

func test_buy_a_buddy() -> void:
	var g := _game()
	g.money = 200
	eq(g.buy("chick"), "ok")
	eq(g.equip.get("buddy", ""), "chick", "第一次领养直接跟着它")
	eq(g.buy("chick"), "have")
	g.buy("bunny")
	eq(g.equip.buddy, "chick", "第二只不会把第一只换掉")
	g.set_equip("buddy", "bunny")
	eq(g.equip.buddy, "bunny")
	for id in Items.of_kinds(["buddy"]):
		check(Art.has(Items.ICON[id]), "%s 有图" % id)


# ---------------------------------------------------------------- 性格

func test_pick_personality_once() -> void:
	var b := Helpers.at("tuanzi")
	eq(b.set_personality("lively"), "no", "宝宝还没有性格")
	var p := Helpers.at("jianjiao")
	eq(p.set_personality("nope"), "no")
	eq(p.set_personality("shy"), "ok")
	eq(p.set_personality("lively"), "no", "选了就不改")
	eq(p.personality, "shy")


func test_personality_perks() -> void:
	var shy := Helpers.at("jianjiao")
	shy.personality = "shy"
	eq(shy.pat(), "ok")
	shy.advance(shy.now + HOUR + 60)
	shy.happy = 2
	eq(shy.pat(), "ok", "害羞的隔一小时就能再摸")
	var plain := Helpers.at("jianjiao")
	plain.pat()
	plain.advance(plain.now + HOUR + 60)
	eq(plain.pat(), "again", "别的要隔两小时")
	var spoiled := Helpers.at("jianjiao")
	spoiled.personality = "spoiled"
	var w := spoiled.weight
	spoiled.feed_snack()
	eq(spoiled.weight, w, "爱撒娇的吃零食不胖")
	var mellow := Helpers.at("jianjiao")
	mellow.personality = "mellow"
	eq(mellow.dirty_every(), Rules.DIRTY_EVERY[Rules.EASY] * 2, "悠闲的脏得慢一半")
	var good := Helpers.at("jianjiao")
	good.personality = "diligent"
	good.study("smart", 3)
	eq(good.smart, 4, "认真的上课多涨 1")
	var g := _game()
	g.pet.personality = "lively"
	g.pet.happy = 2
	var money := g.money
	g.act("game", {"won": true, "reward": 10})
	eq(g.money, money + 13, "活泼的赢了多拿三成")
	g.act("game", {"won": false, "reward": 4})
	eq(g.money, money + 17, "输了不多给")


func test_v8_is_saved() -> void:
	var g := _game()
	g.pet.personality = "mellow"
	g.pet.walk_until = g.pet.now + HOUR
	g.pet.pest_at = 0
	g.money = 200
	g.buy("jelly")
	check(g.save())
	var back := Game.load_saved()
	eq(back.pet.personality, "mellow")
	check(back.pet.walking(), "散步中也存下来了")
	eq(back.equip.buddy, "jelly")
