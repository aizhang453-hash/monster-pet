extends TestCase
## 托人照看 (用户 2026-10-25 要的, 学现代拓麻歌子的暂停 / 照看模式): 两种难度都能用,
## 照看的时候不叫你、不算失误、不生病、不会死, 但照样长大; 每天最多 10 小时, 到时间自己送回来。

const T0 := Helpers.T0
const MIN := 60
const HOUR := 3600
const DAY := 86400


func test_sitter_takes_over_and_nothing_bad_happens() -> void:
	for diff in [Rules.STRICT, Rules.EASY]:
		var p := Helpers.at("jianjiao", diff)
		p.hunger = 0
		p.poop = 2
		p.poop_since = p.now
		p._get_sick(false)
		p.events.clear()
		eq(p.start_sitter(), "ok", diff)
		check(p.sitting())
		eq(p.hunger, 4, "照看的人先喂饱")
		check(not p.sick, "也治好了病")
		eq(p.poop, 0, "也打扫了")
		p.advance(T0 + 9 * HOUR)
		check(not p.is_over(), "%s: 托了 9 小时还好好的" % diff)
		eq(p.mistakes, 0, "%s: 照看的时候不算失误" % diff)
		eq(p.call, "", "不叫你")
		eq(p.hunger, 4)
		eq(p.poop, 0)
		check(not p.sick)
		eq(p.feed_meal(), "no", "托出去了不能喂")
		eq(p.toggle_lights(), "no")


func test_sitter_ends_after_ten_hours() -> void:
	var p := Helpers.at("jianjiao", Rules.STRICT)
	p.start_sitter()
	eq(p.sitter_left(), 10 * HOUR)
	p.advance(T0 + 10 * HOUR - MIN)
	check(p.sitting(), "9 小时 59 分还在照看")
	p.advance(T0 + 10 * HOUR)
	check(not p.sitting(), "10 小时到了自己送回来")
	var ended := false
	for e in p.events:
		if e.kind == "sit_end" and e.auto:
			ended = true
	check(ended, "有「送回来了」的消息")
	eq(p.hunger, 4, "送回来时是饱的")
	eq(p.start_sitter(), "used_up", "今天的 10 小时用完了")


func test_picking_up_early_saves_the_rest_for_later() -> void:
	var p := Helpers.at("jianjiao")
	p.start_sitter()
	p.advance(T0 + 3 * HOUR)
	eq(p.end_sitter(), "ok")
	check(not p.sitting())
	eq(p.sitter_left(), 7 * HOUR, "今天还剩 7 小时")
	eq(p.feed_snack(), "ok", "接回来就能照顾了")
	eq(p.start_sitter(), "ok", "还能再托")
	eq(p.sitter_left(), 7 * HOUR)


func test_new_day_new_ten_hours() -> void:
	var p := Helpers.at("jianjiao")
	p.start_sitter()
	Helpers.care(p, T0 + 10 * HOUR + MIN)
	eq(p.start_sitter(), "used_up")
	Helpers.care(p, T0 + DAY - HOUR)  # 第二天早上 9 点
	eq(p.sitter_left(), 10 * HOUR, "第二天又有 10 小时")
	eq(p.start_sitter(), "ok")


func test_still_grows_while_away() -> void:
	var p := Helpers.pet()
	p.advance(T0 + 6 * MIN)
	eq(p.stage, "baby")
	p.start_sitter()
	p.advance(T0 + 2 * HOUR)
	eq(p.stage, "child", "托出去也照样长大")
	eq(p.mistakes_life, 0)


func test_sitter_turns_off_the_light() -> void:
	var p := Helpers.at("jianjiao", Rules.STRICT)
	Helpers.care(p, T0 + 9 * HOUR)  # 晚上 7 点
	p.start_sitter()
	p.advance(T0 + 11 * HOUR)  # 晚上 9 点, 8 点就睡了
	check(p.asleep)
	check(not p.lights, "照看的人关了灯")
	eq(p.mistakes, 0)


func test_no_old_age_death_while_away() -> void:
	var p := Helpers.at("mogu")
	p.hatched_at = T0 - 8 * DAY - 22 * HOUR  # 两小时后 9 岁
	p.lifespan = 9
	p.start_sitter()
	p.advance(T0 + 5 * HOUR)
	check(not p.is_over(), "在别人那里不会老死 (接回来才走)")
	p.end_sitter()
	p.advance(p.now + 1)
	eq(p.end_reason, "old", "接回来以后老死")


func test_sitter_survives_save() -> void:
	var p := Helpers.at("jianjiao")
	p.start_sitter()
	p.advance(T0 + 2 * HOUR)
	var copy := Pet.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	check(copy.sitting())
	eq(copy.sitter_left(), p.sitter_left())


func test_cannot_send_an_egg_or_after_the_end() -> void:
	eq(Helpers.pet().start_sitter(), "no", "蛋不用托")
	var p := Helpers.at("jianjiao")
	p._end("neglect")
	eq(p.start_sitter(), "no")
	var q := Helpers.at("mogu")
	q.start_sitter()
	q.wants_leave = true
	q.answer_leave(true)
	check(not q.sitting(), "放它走了, 照看也结束了")
