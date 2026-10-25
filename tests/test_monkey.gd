extends TestCase
## 电脑乱玩: 养几千只魔物, 隔一阵随便按一个按钮 (有的勤快、有的很懒), 每一步检查状态没坏。
## 最后打印各种结局有多少只 (改了数字以后看难度用)。

const T0 := Helpers.T0
const PETS := 2000
const ACTIONS := ["meal", "snack", "lights", "game", "medicine", "clean", "scold", "leave_yes", "leave_no", "sit", "unsit",
	"food", "toy", "hotel", "unhotel", "move", "nothing"]

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
			p.eat(Items.DATA[Items.of_kinds(["food"])[rng.randi() % 4]])
		"toy":
			p.play_toy()
		"hotel":
			p.start_hotel(p.now + rng.randi_range(1, 8) * 3600)
		"unhotel":
			p.end_hotel("pickup")
		"move":
			p.place = Species.PLACE_ORDER[rng.randi() % 3]
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
	check(p.mistakes >= 0 and p.mistakes_life >= p.mistakes, "%s 失误 %d/%d" % [where, p.mistakes, p.mistakes_life])
	check(p.medicine_left >= 0 and p.medicine_left <= 2, "%s 药 %d" % [where, p.medicine_left])
	check(Species.DATA.has(p.species), "%s 种类认识" % where)
	check(p.stage in ["egg", "baby", "child", "teen", "adult", "dead", "gone"], "%s 阶段 %s" % [where, p.stage])
	check(p.call in ["", "hunger", "happy", "lights", "discipline"], "%s 叫 %s" % [where, p.call])
	check(p.age() >= 0, "%s 岁数" % where)
	if p.stage != "egg" and not p.is_over():
		check(p.weight >= p.base_weight(), "%s 体重 %d 不比基本体重轻" % [where, p.weight])
		check(Species.DATA[p.species].stage == p.stage, "%s 种类和阶段对得上" % where)
	if p.stage == "adult":
		check(p.lifespan >= Rules.LIFESPAN_MIN, "%s 寿命 %d" % [where, p.lifespan])
	if p.is_over():
		check(p.end_reason in ["neglect", "sick", "old", "left"], "%s 结局 %s" % [where, p.end_reason])
		check(p.call == "" and not p.wants_leave, "%s 结束了就不叫了" % where)
	if p.away():
		check(p.call == "" and not p.is_over(), "%s 托人照看、住旅馆的时候不叫你" % where)
		check(not (p.sitting() and p.in_hotel()), "%s 不会又托人又住旅馆" % where)
	if p.in_hotel():
		check(p.hunger > 0 and p.happy > 0, "%s 住旅馆饿了就送回家" % where)
	if p.stage in ["teen", "adult"]:
		check(Species.place_of(p.species) != "", "%s 少年和成年属于一个地方" % where)
		check(p.sitter_left() <= Rules.SITTER_PER_DAY, "%s 照看最多 10 小时" % where)
	check(p.sit_used >= 0 and p.sit_used <= Rules.SITTER_PER_DAY, "%s 今天托了 %d 秒" % [where, p.sit_used])
	if p.asleep:
		check(p.is_sleep_time(p.now), "%s 只在该睡的时候睡" % where)
		check(p.call == "" or p.call == "lights", "%s 睡着时只会因为没关灯叫你" % where)
	for e in p.events:
		check(e.kind in ["grow", "call", "mistake", "poop", "sick", "sleep", "wake", "leave_ask", "end", "sit_start", "sit_end",
				"hotel_start", "hotel_end"],
			"%s 事件 %s" % [where, e.kind])
	p.events.clear()
