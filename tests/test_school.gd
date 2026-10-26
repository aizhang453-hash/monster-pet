extends TestCase
## 第五版: 上学和工作 (学拓麻歌子 V4), 夸它, 摸摸它, 收到信。

const T0 := Helpers.T0
const HOUR := 3600
const DAY := 86400


func test_questions_are_well_formed() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for kind in School.SUBJECTS:
		for n in 30:
			for q in School.make_questions(kind, rng, n % 2 == 0):
				eq(q.options.size(), 3, "%s: 三个选项" % kind)
				check(q.answer >= 0 and q.answer < 3, "%s: 对的答案在里面 (%s)" % [kind, q])
				var seen := {}
				for o in q.options:
					check(not seen.has(o), "%s: 选项不重复 %s" % [kind, q])
					seen[o] = true
				if q.icon != "":
					check(Art.has(q.icon), "图 %s 画了" % q.icon)


func test_math_answers_are_right() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	for n in 50:
		for q in School.make_questions("smart", rng, true):
			var parts: PackedStringArray = q.text.trim_suffix(" = ?").split(" ")
			var a := int(parts[0])
			var b := int(parts[2])
			var right: int = {"+": a + b, "-": a - b, "×": a * b}[parts[1]]
			eq(int(q.options[q.answer]), right, q.text)
			check(right >= 0, "没有负数")


func test_study_raises_the_subject() -> void:
	var p := Helpers.at("jianjiao")
	eq(p.study("smart", 4), "ok")
	eq(p.smart, 4)
	eq(p.classes, 1)
	eq(p.call, "good", "答对 4 题以上很认真, 该夸了")
	eq(p.study("style", 3), "tired", "上完一节要歇一小时")
	p.advance(T0 + HOUR)
	p.discipline = 4
	p.call = ""
	eq(p.study("style", 2), "ok")
	eq(p.style, 3, "管教满了多 1")
	check(p.call != "good", "答对 2 题不算很认真")


func test_who_goes_to_school() -> void:
	eq(Helpers.at("tuanzi").can_study(), "small")
	eq(Helpers.at("yishou").can_study(), "ok", "少年也上学")
	eq(Helpers.at("huolong").can_study(), "grown", "成年不上学了")


func test_praise_only_when_it_did_something_good() -> void:
	var p := Helpers.at("jianjiao")
	p.happy = 2
	eq(p.praise(), "puzzled", "没做好事夸它, 它不明白")
	eq(p.happy, 2)
	p.call = "good"
	p.call_at = p.now
	eq(p.praise(), "good")
	eq(p.happy, 3)
	eq(p.kind, 2, "夸了善良 +2")
	eq(p.call, "")


func test_good_deeds_happen_and_missing_one_is_not_a_mistake() -> void:
	var p := Helpers.at("jianjiao", Rules.STRICT)
	var seen := 0
	while p.now < T0 + 2 * DAY:
		p.advance(p.now + 5 * 60)
		for e in p.events:
			if e.kind == "call" and e.what == "good":
				seen += 1
		p.events.clear()
		p.hunger = 4
		p.happy = 4
		p.clean()
		if p.asleep and p.lights:
			p.toggle_lights()
		if p.call == "discipline":
			p.scold()
	check(seen >= 2, "两天里做了几次好事 (做了 %d 次)" % seen)
	eq(p.mistakes, 0, "没夸不算照顾失误")


func test_petting() -> void:
	var p := Helpers.at("jianjiao")
	p.happy = 1
	eq(p.pat(), "ok")
	eq(p.happy, 2)
	eq(p.pat(), "again", "两小时内再摸, 只是蹭蹭")
	eq(p.happy, 2)
	p.advance(T0 + 2 * HOUR)
	p.happy = 1
	eq(p.pat(), "ok")
	eq(p.happy, 2)


func test_jobs_need_abilities() -> void:
	var p := Helpers.at("huolong")
	eq(p.take_job("doctor"), "cannot", "医生要聪明 60、善良 40")
	eq(p.take_job("helper"), "ok", "杂工谁都能做")
	p.smart = 60
	p.kind = 40
	eq(p.take_job("doctor"), "ok")
	eq(Helpers.at("jianjiao").take_job("helper"), "no", "小孩不能工作")
	p.power = 30
	p.guard = 35
	check(School.can_take(p, "guard"), "保镖要力气 40、防御 40: 火焰龙天生力气 +15、防御 +5, 练一练就够")


func test_working_pays_and_tires() -> void:
	var p := Helpers.at("huolong")
	eq(p.can_work(), "nojob")
	p.take_job("helper")
	eq(p.work_done(true), 15, "赢了全给")
	eq(p.hunger, 3, "上班会累")
	eq(p.work_done(true), -1, "要歇 4 小时")
	p.advance(T0 + 4 * HOUR)
	p.hunger = 4
	p.happy = 4
	eq(p.work_done(false), 7, "输了给一半")


func test_every_job_is_reachable_and_uses_a_real_game() -> void:
	for id in School.JOBS:
		var game_id: String = School.JOBS[id].game
		check(MiniGames.info(game_id) != {} or game_id.begins_with("quiz_"), "%s 的小游戏 %s 存在" % [id, game_id])
		var g := MiniGames.make(game_id, 1)
		check(g != null and g.buttons().size() > 0)


func test_letters() -> void:
	var g := Game.new()
	g.use_system_tz = false
	g.fixed_time = T0
	g.pet = Helpers.at("yishou")
	Helpers.care(g.pet, T0 + 2 * DAY + HOUR)
	g._take_events()
	eq(g.pet.stage, "adult")
	eq(g.unread(), 1, "长大了收到工作介绍所的信")
	has_text(g.letters[0].title, "工作")
	has_text(g.letters[0].body, "杂工")
	for i in 5:
		g.pet.class_at = -999999
		g.pet.stage = "teen"
		g.act("study", {"subject": "kind", "correct": 1})
	has_text(g.letters[-1].title, "成绩单", "上了 5 节课寄来成绩单")
	g.pet.stage = "adult"
	g.pet.wants_leave = true
	g.pet.answer_leave(true)
	g._take_events()
	eq(g.pending_letters.size(), 1, "放走的魔物要寄信回来")
	var before := g.letters.size()
	g.fixed_time = T0 + 4 * DAY
	g.tick()
	eq(g.letters.size(), before + 1, "过一天信到了")
	has_text(g.letters[-1].body, "谢谢你把我养大")
	var g2 := Game.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	eq(g2.letters.size(), g.letters.size(), "信存档")
	eq(g2.unread(), g.unread())


func test_school_and_job_survive_save() -> void:
	var p := Helpers.at("huolong")
	p.smart = 12
	p.style = 7
	p.kind = 9
	p.take_job("helper")
	var copy := Pet.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	eq([copy.smart, copy.style, copy.kind, copy.job], [12, 7, 9, "helper"])
