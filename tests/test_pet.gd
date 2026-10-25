extends TestCase
## 照顾魔物的基本规矩 (原版第一代): 孵蛋、心掉、叫你、照顾失误、喂饭、零食、小游戏、睡觉关灯、便便、生病吃药、管教。

const T0 := Helpers.T0
const MIN := 60
const HOUR := 3600


func test_egg_hatches_after_five_minutes() -> void:
	var p := Helpers.pet()
	p.advance(T0 + 4 * MIN)
	eq(p.stage, "egg", "4 分钟还是蛋")
	eq(p.feed_meal(), "no", "蛋不能喂")
	p.advance(T0 + 5 * MIN)
	eq(p.stage, "baby")
	eq(p.species, "tuanzi")
	eq(p.hunger, 0, "刚孵出来是饿的")
	eq(p.call, "hunger", "一孵出来就叫你喂它")
	eq(p.hatched_at, T0 + 5 * MIN)
	eq(p.weight, 5)


func test_baby_becomes_child_after_an_hour() -> void:
	var p := Helpers.pet()
	Helpers.care(p, T0 + 5 * MIN + 59 * MIN)
	eq(p.stage, "baby")
	Helpers.care(p, T0 + 5 * MIN + 60 * MIN)
	eq(p.stage, "child")
	eq(p.species, "jianjiao")
	eq(p.weight, 10, "长大了体重换成这一阶段的基本体重")


func test_hearts_drop_and_easy_is_half_as_fast() -> void:
	var s := Helpers.at("jianjiao", Rules.STRICT)
	var e := Helpers.at("jianjiao", Rules.EASY)
	s.advance(T0 + 40 * MIN)
	e.advance(T0 + 40 * MIN)
	eq(s.hunger, 3, "原版严格: 小孩 40 分钟掉一颗")
	eq(e.hunger, 4, "放宽: 慢一半, 40 分钟还没掉")
	e.advance(T0 + 80 * MIN)
	eq(e.hunger, 3, "放宽: 80 分钟掉一颗")
	check(s.happy > s.hunger or s.happy == 4, "开心跟饿错开掉")


func test_empty_heart_calls_and_fifteen_minutes_is_a_mistake() -> void:
	var p := Helpers.at("jianjiao", Rules.STRICT)
	p.hunger = 1
	p.advance(T0 + 40 * MIN)
	eq(p.hunger, 0)
	eq(p.call, "hunger", "饿空了叫你")
	p.advance(T0 + 54 * MIN)
	eq(p.mistakes, 0, "14 分钟还不算失误")
	p.advance(T0 + 55 * MIN)
	eq(p.mistakes, 1, "15 分钟没理, 照顾失误一次")
	eq(p.call, "", "失误以后先不叫了")
	p.advance(T0 + 55 * MIN + 59 * MIN)
	eq(p.call, "", "一小时内不再叫")
	p.advance(T0 + 55 * MIN + 60 * MIN)
	eq(p.call, "hunger", "还饿着, 一小时后又叫")


func test_easy_waits_two_hours_before_a_mistake() -> void:
	var p := Helpers.at("jianjiao", Rules.EASY)
	p.hunger = 1
	p.advance(T0 + 80 * MIN)
	eq(p.call, "hunger")
	p.advance(T0 + 80 * MIN + 119 * MIN)
	eq(p.mistakes, 0, "放宽: 1 小时 59 分还不算")
	p.advance(T0 + 80 * MIN + 120 * MIN)
	eq(p.mistakes, 1, "放宽: 2 小时没理才算失误")


func test_feeding_answers_the_call() -> void:
	var p := Helpers.at("jianjiao", Rules.STRICT)
	p.hunger = 1
	p.advance(T0 + 40 * MIN)
	eq(p.call, "hunger")
	eq(p.feed_meal(), "ok")
	eq(p.hunger, 1)
	eq(p.call, "", "喂了就不叫了")
	eq(p.weight, 11, "正餐 +1 克")
	p.advance(T0 + 60 * MIN)
	eq(p.mistakes, 0, "及时喂了不算失误")


func test_full_refuses_meal_but_snack_always_works() -> void:
	var p := Helpers.at("jianjiao")
	eq(p.feed_meal(), "full", "吃饱了不吃")
	eq(p.weight, 10)
	p.happy = 2
	eq(p.feed_snack(), "ok")
	eq(p.happy, 3)
	eq(p.weight, 12, "零食 +2 克")
	p.happy = 4
	eq(p.feed_snack(), "ok", "开心满了也吃零食")
	eq(p.happy, 4)


func test_game_win_makes_happy_and_slims() -> void:
	var p := Helpers.at("jianjiao")
	p.happy = 1
	p.weight = 15
	eq(p.finish_game(3), "won")
	eq(p.happy, 2)
	eq(p.weight, 14, "玩一次 -1 克")
	eq(p.finish_game(2), "lost")
	eq(p.happy, 2, "输了不加开心")
	p.weight = 10
	p.finish_game(5)
	eq(p.weight, 10, "不会比基本体重轻")
	p.sick = true
	eq(p.can_play(), "sick", "生病了不想玩")


func test_sleep_needs_lights_off() -> void:
	var p := Helpers.at("jianjiao", Rules.STRICT)
	Helpers.care(p, T0 + 10 * HOUR - MIN)  # 晚上 7:59
	check(not p.asleep)
	p.advance(T0 + 10 * HOUR)  # 晚上 8 点
	check(p.asleep, "小孩晚上 8 点睡")
	eq(p.call, "lights", "睡着了没关灯, 叫你")
	var before := p.mistakes
	p.advance(T0 + 10 * HOUR + 15 * MIN)
	eq(p.mistakes, before + 1, "15 分钟没关灯算失误")
	eq(p.feed_meal(), "asleep", "睡着了不吃")


func test_turning_off_lights_in_time_and_hearts_wait_overnight() -> void:
	var p := Helpers.at("jianjiao", Rules.STRICT)
	Helpers.care(p, T0 + 10 * HOUR + 5 * MIN)
	check(p.asleep)
	check(not p.lights, "勤快的主人关了灯")
	eq(p.mistakes, 0)
	var h := p.hunger
	p.advance(T0 + 22 * HOUR + 59 * MIN)  # 早上 8:59
	check(p.asleep)
	eq(p.hunger, h, "睡着的时候心不掉")
	eq(p.poop, 0, "睡着的时候不拉便便")
	p.advance(T0 + 23 * HOUR)  # 早上 9 点
	check(not p.asleep, "9 点醒")
	check(p.lights, "醒了自动开灯")


func test_poop_left_too_long_makes_sick() -> void:
	var p := Helpers.at("jianjiao", Rules.STRICT)
	Helpers.care(p, T0 + 90 * MIN, 5 * MIN, false, false)
	eq(p.poop, 1, "小孩 90 分钟拉一次")
	check(not p.sick)
	Helpers.care(p, T0 + 90 * MIN + 3 * HOUR, 5 * MIN, false, false)
	check(p.sick, "便便放 3 小时没打扫就生病 (原版严格)")
	eq(p.sick_times, 1)


func test_cleaning_keeps_it_healthy() -> void:
	var p := Helpers.at("jianjiao", Rules.STRICT)
	Helpers.care(p, T0 + 9 * HOUR)
	check(not p.sick, "勤快打扫就不生病")
	eq(p.poop, 0)
	eq(p.clean(), "nothing")


func test_medicine_cures_in_one_or_two_doses() -> void:
	var p := Helpers.at("jianjiao")
	eq(p.give_medicine(), "healthy", "没病不吃药")
	p._get_sick(false)
	check(p.medicine_left == 1 or p.medicine_left == 2)
	var doses := 0
	while p.sick:
		p.give_medicine()
		doses += 1
	check(doses >= 1 and doses <= 2, "一两次就好")


func test_sick_too_long_dies() -> void:
	var s := Helpers.at("jianjiao", Rules.STRICT)
	s._get_sick(false)
	Helpers.care(s, T0 + 12 * HOUR - MIN, 5 * MIN, true, false)
	check(not s.is_over(), "原版严格: 病 11 小时 59 分还活着")
	Helpers.care(s, T0 + 12 * HOUR, 5 * MIN, true, false)
	eq(s.end_reason, "sick", "原版严格: 病 12 小时没治就死")
	var e := Helpers.at("jianjiao", Rules.EASY)
	e._get_sick(false)
	Helpers.care(e, T0 + 23 * HOUR, 5 * MIN, true, false)
	check(not e.is_over(), "放宽: 病 23 小时还活着")
	Helpers.care(e, T0 + 24 * HOUR, 5 * MIN, true, false)
	eq(e.end_reason, "sick", "放宽: 病一整天没治才死")


func test_strict_third_sickness_in_one_stage_dies() -> void:
	var p := Helpers.at("jianjiao", Rules.STRICT)
	p._get_sick(false)
	p.give_medicine()
	p.give_medicine()
	p._get_sick(false)
	p.give_medicine()
	p.give_medicine()
	check(not p.is_over())
	p._get_sick(false)
	eq(p.end_reason, "sick", "原版严格: 同一阶段第 3 次生病就死")
	var e := Helpers.at("jianjiao", Rules.EASY)
	for i in 3:
		e._get_sick(false)
		e.give_medicine()
		e.give_medicine()
	check(not e.is_over(), "放宽: 病几次都不会因为次数死")


func test_scolding() -> void:
	var p := Helpers.at("jianjiao")
	p.call = "discipline"
	p.call_at = p.now
	eq(p.scold(), "good")
	eq(p.discipline, 1, "闹脾气的时候管教, 管教 +1")
	eq(p.call, "")
	eq(p.scold(), "sad", "没闹的时候骂它")
	eq(p.happy, 3, "没闹被骂, 不开心 -1")
	eq(p.discipline, 1)


func test_ignoring_a_tantrum_is_not_a_mistake() -> void:
	var p := Helpers.at("jianjiao", Rules.STRICT)
	p.call = "discipline"
	p.call_at = p.now
	p.advance(T0 + 20 * MIN)
	eq(p.call, "", "闹了 15 分钟就算了")
	eq(p.mistakes, 0, "不管闹脾气不算照顾失误")
	eq(p.discipline, 0, "但管教也没涨")


func test_tantrums_happen_while_awake() -> void:
	var p := Helpers.at("jianjiao")
	var seen := 0
	while p.now < T0 + 9 * HOUR:
		p.advance(p.now + 5 * MIN)
		for e in p.events:
			if e.kind == "call" and e.what == "discipline":
				seen += 1
		p.events.clear()
		p.hunger = 4
		p.happy = 4
		p.clean()
		if p.call == "discipline":
			p.scold()
	check(seen >= 1, "醒着 9 小时至少闹一次脾气 (闹了 %d 次)" % seen)
	eq(p.discipline, mini(seen, 4), "每次都管教了")
