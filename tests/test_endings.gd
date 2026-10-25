extends TestCase
## 三种结局都有 (用户 2026-10-25 定的): 没照顾好会死、留下来的最后老死、放它走就离开。

const T0 := Helpers.T0
const MIN := 60
const HOUR := 3600
const DAY := 86400


func test_strict_adult_dies_after_five_mistakes() -> void:
	var p := Helpers.at("huolong", Rules.STRICT)
	p.mistakes = 4
	p.hunger = 0
	p._settle()
	eq(p.call, "hunger")
	p.advance(T0 + 15 * MIN)
	eq(p.stage, "dead", "原版严格: 成年后第 5 次失误就死")
	eq(p.end_reason, "neglect")


func test_easy_mistakes_never_kill() -> void:
	var p := Helpers.at("huolong", Rules.EASY)
	p.mistakes = 30
	Helpers.care(p, T0 + 2 * DAY)
	check(not p.is_over(), "放宽: 失误再多, 照顾着就不会死")


func test_easy_starves_after_a_whole_day() -> void:
	var p := Helpers.at("huolong", Rules.EASY)
	p.hunger = 0
	p.happy = 0
	p._settle()
	p.advance(T0 + DAY - MIN)
	check(not p.is_over(), "放宽: 心空了 23 小时 59 分还活着")
	p.advance(T0 + DAY)
	eq(p.end_reason, "neglect", "放宽: 心空了整整一天就死")


func test_strict_neglect_dies_much_sooner() -> void:
	var p := Helpers.at("huolong", Rules.STRICT)
	p.advance(T0 + 2 * DAY)
	eq(p.stage, "dead", "原版严格: 两天不管一定死了")
	check(p.ended_at - T0 < DAY, "而且不到一天 (实际 %.1f 小时)" % ((p.ended_at - T0) / 3600.0))


func test_asks_to_leave_and_letting_go_ends_happily() -> void:
	var p := Helpers.at("shuiling")
	Helpers.care(p, T0 + Rules.LEAVE_ASK_AFTER - HOUR)
	check(not p.wants_leave)
	p.advance(T0 + Rules.LEAVE_ASK_AFTER)
	check(p.wants_leave, "成年 3 天后说想离开")
	eq(p.events[-1].kind, "leave_ask")
	p.answer_leave(true)
	eq(p.stage, "gone")
	eq(p.end_reason, "left")
	check(p.is_over())


func test_keeping_it_asks_again_later() -> void:
	var p := Helpers.at("shuiling")
	Helpers.care(p, T0 + Rules.LEAVE_ASK_AFTER - 5 * MIN)
	p.advance(T0 + Rules.LEAVE_ASK_AFTER)
	check(p.wants_leave)
	p.answer_leave(false)
	check(not p.wants_leave)
	check(not p.is_over(), "留下来")
	Helpers.care(p, p.now + Rules.LEAVE_ASK_AGAIN - HOUR)
	check(not p.wants_leave, "留下的话这两天不再问 (勤快的主人每次都说留下)")
	p.advance(p.now + HOUR)
	check(p.wants_leave, "过两天再问一次")


func test_kept_pet_dies_of_old_age() -> void:
	var p := Helpers.at("mogu")
	p.hatched_at = T0 - 8 * DAY - HOUR  # 已经 8 岁
	p.lifespan = 9
	eq(p.age(), 8)
	Helpers.care(p, T0 + DAY - 2 * HOUR)
	check(not p.is_over(), "还没到 9 岁")
	Helpers.care(p, T0 + DAY)
	eq(p.end_reason, "old", "到了寿命就老死")
	eq(p.age(), 9)


func test_old_pets_get_sick_at_twelve() -> void:
	var p := Helpers.at("shixiang")
	p.hatched_at = T0 - 12 * DAY + HOUR  # 一小时后 12 岁
	p.lifespan = 20
	Helpers.care(p, T0 + HOUR - MIN, 5 * MIN, true, false)
	check(not p.sick)
	Helpers.care(p, T0 + HOUR, 5 * MIN, true, false)
	check(p.sick, "12 岁会生病 (照原版)")
	eq(p.sick_times, 0, "老了生的病不算次数")


func test_ending_stops_time() -> void:
	var p := Helpers.at("mogu")
	p.answer_leave(true)  # 还没问, 不会走
	check(not p.is_over())
	p.wants_leave = true
	p.answer_leave(true)
	var h := p.hunger
	p.advance(T0 + 5 * DAY)
	eq(p.hunger, h, "结束以后什么都不变")
	eq(p.age(), 0, "岁数停在结束那天")
	eq(p.feed_meal(), "no")
