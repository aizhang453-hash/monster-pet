extends TestCase
## 第三版: 旅馆 (照拓麻歌子 On / Meets): 花魔晶寄放, 不叫你、不算失误; 不管饭, 饿了或不开心就送回家; 约好的时间没去接, 回来很生气。

const T0 := Helpers.T0
const HOUR := 3600


func _game() -> Game:
	var g := Game.new()
	g.use_system_tz = false
	g.fixed_time = T0
	g.pet = Helpers.at("huolong", Rules.STRICT)
	return g


func test_hotel_costs_money() -> void:
	var g := _game()
	g.money = 100
	eq(g.hotel(4), "ok")
	eq(g.money, 100 - 4 * Outings.HOTEL_PRICE)
	check(g.pet.in_hotel())
	eq(g.pet.hotel_until, T0 + 4 * HOUR)
	var g2 := _game()
	g2.money = 5
	eq(g2.hotel(4), "poor", "钱不够")
	check(not g2.pet.in_hotel())


func test_no_calls_or_mistakes_at_the_hotel() -> void:
	var p := Helpers.at("huolong", Rules.STRICT)
	p.poop = 2
	eq(p.start_hotel(T0 + 4 * HOUR), "ok")
	eq(p.poop, 0, "旅馆帮忙打扫")
	p.advance(T0 + 4 * HOUR - 60)
	check(p.in_hotel(), "满了才回来, 心还没空")
	eq(p.mistakes, 0)
	eq(p.call, "")
	eq(p.poop, 0, "住旅馆不拉便便")
	eq(p.feed_meal(), "no", "不在家, 喂不了")


func test_hungry_guests_are_sent_home() -> void:
	var p := Helpers.at("huolong", Rules.STRICT)
	p.hunger = 1
	p.start_hotel(T0 + 8 * HOUR)
	p.advance(T0 + 80 * 60)  # 原版严格的成年 75 分钟掉一颗心
	check(not p.in_hotel(), "旅馆不管饭, 饿了就送回家")
	eq(p.call, "hunger", "回家就叫你喂它")
	var sent := false
	for e in p.events:
		if e.kind == "hotel_end" and e.reason == "hungry":
			sent = true
	check(sent)


func test_late_pickup_makes_it_angry() -> void:
	var p := Helpers.at("huolong", Rules.EASY)
	p.start_hotel(T0 + 2 * HOUR)
	p.advance(T0 + 2 * HOUR)
	check(not p.in_hotel(), "到时间自己回来")
	eq(p.happy, 2, "没去接, 很生气 (开心 4 - 2; 放宽的成年 2 小时还没掉心)")


func test_hungry_pets_are_turned_away() -> void:
	var p := Helpers.at("huolong")
	p.hunger = 0
	eq(p.start_hotel(T0 + HOUR), "hungry", "饿着的旅馆不收")
	check(not p.in_hotel())


func test_pick_up_in_time() -> void:
	var g := _game()
	g.money = 100
	g.hotel(4)
	g.fixed_time = T0 + HOUR
	has_text(g.act("sitter"), "旅馆")
	check(not g.pet.in_hotel(), "按「接回来」从旅馆接回来")
	eq(g.pet.happy, 4, "按时接回来不生气")


func test_hotel_survives_save() -> void:
	var p := Helpers.at("huolong")
	p.start_hotel(T0 + 3 * HOUR)
	var copy := Pet.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	check(copy.in_hotel())
	eq(copy.hotel_until, T0 + 3 * HOUR)


func test_cannot_stack_with_the_sitter() -> void:
	var p := Helpers.at("huolong")
	p.start_sitter()
	eq(p.start_hotel(T0 + HOUR), "already")
	p.end_sitter()
	p.start_hotel(T0 + HOUR)
	eq(p.start_sitter(), "already")
