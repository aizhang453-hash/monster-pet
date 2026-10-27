extends TestCase
## 电脑乱玩: 养几千只魔物, 隔一阵随便按一个按钮 (有的勤快、有的很懒), 每一步检查状态没坏。
## 最后打印各种结局有多少只 (改了数字以后看难度用)。

const T0 := Helpers.T0
const PETS := 2000
const ACTIONS := ["meal", "snack", "lights", "game", "medicine", "clean", "scold", "leave_yes", "leave_no", "sit", "unsit",
	"food", "toy", "hotel", "unhotel", "move", "praise", "pat", "study", "job", "work", "train", "soil", "match_yes", "match_no", "parents", "shoo", "callback", "personality", "nothing"]

var rng := RandomNumberGenerator.new()
var endings := {}
var adults := {}


func before_each() -> void:
	rng.seed = 20261025


func test_random_play_never_breaks() -> void:
	var started := Time.get_ticks_msec()
	for n in PETS:
		var diff := Rules.STRICT if n % 2 == 0 else Rules.EASY
		var p := Pet.create(T0 + rng.randi_range(0, 86400), diff, rng.randi_range(-12, 14) * 3600, n + 1)
		# 每只魔物的主人隔多久看一次: 有的几分钟, 有的好几个小时
		var gap := rng.randi_range(2 * 60, 6 * 3600)
		var last_now := p.now
		var steps := 0
		while not p.is_over() and steps < 3000:
			steps += 1
			p.advance(p.now + rng.randi_range(60, gap))
			_do(p, ACTIONS[rng.randi() % ACTIONS.size()])
			if rng.randf() < 0.5:
				_do(p, "meal")
			_check(p, last_now)
			last_now = p.now
			if failures.size() > 20:
				return
		var key := "%s/%s" % [diff, p.end_reason if p.is_over() else "还活着"]
		endings[key] = int(endings.get(key, 0)) + 1
		if p.stage == "adult" or Species.DATA[p.species].stage == "adult":
			adults[p.species] = int(adults.get(p.species, 0)) + 1
		p.events.clear()
	print("  乱玩 %d 只, 用了 %.1f 秒。结局: %s" % [PETS, (Time.get_ticks_msec() - started) / 1000.0, endings])
	print("  长到成年的: %s" % adults)


func _do(p: Pet, what: String) -> void:
	match what:
		"meal":
			p.feed_meal()
		"snack":
			p.feed_snack()
		"lights":
			p.toggle_lights()
		"game":
			p.finish_game(rng.randf() < 0.5)
		"food":
			var foods := Items.of_kinds(["food"])
			p.eat(Items.DATA[foods[rng.randi() % foods.size()]])
		"toy":
			p.play_toy()
		"hotel":
			p.start_hotel(p.now + rng.randi_range(1, 8) * 3600)
		"unhotel":
			p.end_hotel("pickup")
		"move":
			p.place = Species.PLACE_ORDER[rng.randi() % 3]
		"praise":
			p.praise()
		"pat":
			p.pat()
		"study":
			p.study(School.SUBJECTS.keys()[rng.randi() % 3], rng.randi_range(0, 5))
		"job":
			p.take_job(School.JOB_ORDER[rng.randi() % School.JOB_ORDER.size()])
		"work":
			p.work_done(rng.randf() < 0.5)
		"train":
			p.train(Training.STATS.keys()[rng.randi() % 3])
		"soil":
			p.soil()
		"match_yes":
			p.match_offers = [{"species": "hailong", "hue": rng.randf(), "feature": "fin"}]
			p.answer_match(0)
		"match_no":
			p.answer_match(-1)
		"parents":
			p.start_sitter("parents")
		"shoo":
			p.shoo()
		"callback":
			p.end_walk()
		"personality":
			p.set_personality(Personality.ORDER[rng.randi() % Personality.ORDER.size()])
		"medicine":
			p.give_medicine()
		"clean":
			p.clean()
		"scold":
			p.scold()
		"leave_yes":
			p.answer_leave(true)
		"leave_no":
			p.answer_leave(false)
		"sit":
			p.start_sitter()
		"unsit":
			p.end_sitter()


func _check(p: Pet, last_now: int) -> void:
	var where := "第 %s 只 (%s, %s)" % [p.rng.seed, p.species, p.difficulty]
	check(p.now >= last_now, "%s 时间不倒退" % where)
	check(p.hunger >= 0 and p.hunger <= 4, "%s 饿 %d" % [where, p.hunger])
	check(p.happy >= 0 and p.happy <= 4, "%s 开心 %d" % [where, p.happy])
	check(p.discipline >= 0 and p.discipline <= 4, "%s 管教 %d" % [where, p.discipline])
	check(p.poop >= 0 and p.poop <= Rules.MAX_POOP, "%s 便便 %d" % [where, p.poop])
	check(p.tidy >= 0 and p.tidy <= 4, "%s 干净 %d" % [where, p.tidy])
	check([p.sitting(), p.in_hotel(), p.walking()].count(true) <= 1, "%s 托人、旅馆、散步只会有一样" % where)
	check(p.pest_at == 0 or not p.asleep, "%s 睡着的时候没有捣蛋精" % where)
	check(p.personality == "" or Personality.LIST.has(p.personality), "%s 性格 %s" % [where, p.personality])
	check(p.gen >= 1 and p.hue >= -1.0 and p.hue < 1.0, "%s 第 %d 代, 颜色 %.2f" % [where, p.gen, p.hue])
	check(not p.wants_match or (p.stage == "adult" and p.partner.is_empty()), "%s 只有没结婚的成年才有媒人" % where)
	if p.end_reason == "married":
		check(p.stage == "gone" and not p.partner.is_empty(), "%s 结婚了就离开, 有对象" % where)
	check(p.mistakes >= 0 and p.mistakes_life >= p.mistakes, "%s 失误 %d/%d" % [where, p.mistakes, p.mistakes_life])
	check(p.medicine_left >= 0 and p.medicine_left <= 2, "%s 药 %d" % [where, p.medicine_left])
	check(Species.DATA.has(p.species), "%s 种类认识" % where)
	check(p.stage in ["egg", "baby", "child", "teen", "adult", "dead", "gone"], "%s 阶段 %s" % [where, p.stage])
	check(p.call in ["", "hunger", "happy", "lights", "discipline", "good"], "%s 叫 %s" % [where, p.call])
	check(p.age() >= 0, "%s 岁数" % where)
	if p.stage != "egg" and not p.is_over():
		check(p.weight >= p.base_weight(), "%s 体重 %d 不比基本体重轻" % [where, p.weight])
		check(Species.DATA[p.species].stage == p.stage, "%s 种类和阶段对得上" % where)
	if p.stage == "adult":
		check(p.lifespan >= Rules.LIFESPAN_MIN, "%s 寿命 %d" % [where, p.lifespan])
	if p.is_over():
		check(p.end_reason in ["neglect", "sick", "old", "left", "married"], "%s 结局 %s" % [where, p.end_reason])
		check(p.call == "" and not p.wants_leave, "%s 结束了就不叫了" % where)
	if p.away():
		check(p.call == "" and not p.is_over(), "%s 托人照看、住旅馆的时候不叫你" % where)
		check(not (p.sitting() and p.in_hotel()), "%s 不会又托人又住旅馆" % where)
	if p.in_hotel():
		check(p.hunger > 0 and p.happy > 0, "%s 住旅馆饿了就送回家" % where)
	check(p.smart >= 0 and p.style >= 0 and p.kind >= 0, "%s 聪明时尚善良不是负数" % where)
	if p.job != "":
		check(p.stage == "adult" or p.is_over(), "%s 成年才有工作" % where)
	if p.stage in ["teen", "adult"]:
		check(Species.place_of(p.species) != "", "%s 少年和成年属于一个地方" % where)
		check(p.sitter_left() <= Rules.SITTER_PER_DAY, "%s 照看最多 10 小时" % where)
	check(p.sit_used >= 0 and p.sit_used <= Rules.SITTER_PER_DAY, "%s 今天托了 %d 秒" % [where, p.sit_used])
	if p.asleep:
		check(p.is_sleep_time(p.now), "%s 只在该睡的时候睡" % where)
		check(p.call == "" or p.call == "lights", "%s 睡着时只会因为没关灯叫你" % where)
	for e in p.events:
		check(e.kind in ["grow", "call", "mistake", "poop", "sick", "sleep", "wake", "leave_ask", "end", "sit_start", "sit_end",
				"hotel_start", "hotel_end", "match_ask", "walk_start", "walk_end", "pest", "pest_hit"],
			"%s 事件 %s" % [where, e.kind])
	p.events.clear()
