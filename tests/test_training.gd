extends TestCase
## 第四版: 训练和比赛 (学《怪物农场》和数码宝贝机器)。

const T0 := Helpers.T0
const MIN := 60
const HOUR := 3600
const DAY := 86400


func test_training_raises_a_stat_and_tires() -> void:
	var p := Helpers.at("jianjiao")
	eq(p.train("speed"), "ok")
	check(p.speed >= 3 and p.speed <= 5, "练一次涨 3–5 (涨了 %d)" % p.speed)
	eq(p.last_gain, p.speed)
	eq(p.hunger, 3, "练完饿一点")
	eq(p.happy, 3, "累一点")
	eq(p.train("speed"), "tired", "刚练过要歇")
	p.advance(T0 + 30 * MIN)
	eq(p.train("power"), "ok", "歇 30 分钟就能再练")
	check(p.power >= 3)


func test_who_can_train() -> void:
	eq(Helpers.at("tuanzi").train("power"), "small", "宝宝太小")
	var p := Helpers.at("jianjiao")
	p.hunger = 0
	eq(p.train("power"), "hungry", "饿着不练")
	p.hunger = 4
	p.sick = true
	eq(p.train("power"), "sick")
	p.sick = false
	p.start_sitter()
	eq(p.train("power"), "no", "托出去了练不了")


func test_well_disciplined_trains_better() -> void:
	var total_good := 0
	var total := 0
	for i in 40:
		var a := Helpers.at("jianjiao", Rules.EASY, T0, i + 1)
		a.discipline = 4
		a.train("guard")
		total_good += a.guard
		var b := Helpers.at("jianjiao", Rules.EASY, T0, i + 1)
		b.train("guard")
		total += b.guard
	eq(total_good, total + 40, "管教满了每次多 1")


func test_stats_stay_when_growing_up_and_adults_get_a_bonus() -> void:
	var p := Helpers.at("yishou")
	p.power = 20
	eq(p.stat("power"), 25, "少年天生每样 +5")
	p.hatched_at = p.now
	p._become("huolong")
	eq(p.power, 20, "长大了练的还在")
	eq(p.stat("power"), 35, "火焰龙擅长力气 +15")
	eq(p.stat("speed"), 5, "别的 +5")
	p._become("xingguang")
	eq(p.stat("guard"), 15, "隐藏的三样都 +15")


func test_every_adult_has_a_strength() -> void:
	for id in Species.DATA:
		var d: Dictionary = Species.DATA[id]
		if d.stage == "adult" and not d.get("secret", false):
			check(Training.STRONG.has(id), "%s 有擅长的本事" % id)


func test_fights_are_fair_and_stronger_usually_wins() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var strong_wins := 0
	var even_wins := 0
	for i in 400:
		var foe := {"power": 30, "speed": 30, "guard": 30}
		if Training.fight({"power": 45, "speed": 40, "guard": 40}, foe, rng).won:
			strong_wins += 1
		if Training.fight({"power": 30, "speed": 30, "guard": 30}, foe, rng).won:
			even_wins += 1
	check(strong_wins > 340, "强的大多赢 (%d/400)" % strong_wins)
	check(even_wins > 120 and even_wins < 280, "一样强差不多一半一半 (%d/400)" % even_wins)


func test_fight_log_adds_up() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var res := Training.fight({"power": 20, "speed": 20, "guard": 10}, {"power": 10, "speed": 10, "guard": 10}, rng)
	check(res.log.size() > 0 and res.log.size() <= 20)
	var last: Dictionary = res.log[-1]
	if res.won:
		check(last.hp_foe == 0 or last.hp_me > 0)
	for e in res.log:
		check(e.who in ["me", "foe"])
		check(e.dodge == (e.dmg == 0), "躲开了就没掉血")


func test_tournament_ranks_up() -> void:
	var p := Helpers.at("huolong")
	eq(p.compete(1)["error"], "locked", "先赢新手赛")
	p.power = 60
	p.speed = 60
	p.guard = 60
	var res := p.compete(0)
	check(res.won, "练得很强, 新手赛赢了")
	check(res.rank_up)
	eq(p.rank, 1)
	eq(p.compete(1)["error"], "tired", "比完要歇")
	p.advance(T0 + 3 * HOUR)
	p.hunger = 4
	p.happy = 4
	res = p.compete(0)
	check(not res.get("rank_up", true), "再赢新手赛不升级")
	eq(p.rank, 1)


func test_child_cannot_compete() -> void:
	eq(Helpers.at("jianjiao").can_match(), "small", "少年起才能比赛")
	eq(Helpers.at("yishou").can_match(), "ok")


func test_game_pays_prizes_and_trophies() -> void:
	var g := Game.new()
	g.use_system_tz = false
	g.fixed_time = T0
	g.rng.seed = 1
	g.pet = Helpers.at("huolong")
	g.pet.power = 80
	g.pet.speed = 80
	g.pet.guard = 80
	var m := g.money
	var res := g.compete(0)
	check(res.won)
	eq(g.money, m + Training.RANKS[0].prize)
	eq(g.trophies, {0: 1}, "拿到新手奖杯")
	has_text(res.text, "奖杯")
	check(Species.DATA.has(res.foe_species), "对手是一只魔物")
	var g2 := Game.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	eq(g2.trophies, {0: 1}, "奖杯存档")
	eq(g2.pet.rank, 1)
	eq(g2.pet.power, 80)


func test_loser_gets_a_little() -> void:
	var g := Game.new()
	g.use_system_tz = false
	g.fixed_time = T0
	g.pet = Helpers.at("yishou")
	var m := g.money
	var res := g.compete(0)
	if not res.won:
		eq(g.money, m + int(Training.RANKS[0].prize / 4.0), "输了也给四分之一")
		has_text(res.text, "输给了")


func test_champion_is_reachable_for_a_dedicated_trainer() -> void:
	# 一个勤快的主人: 每 30 分钟练一次 (醒着的时候), 从小孩练到成年后 6 天, 再去比赛
	var p := Helpers.at("jianjiao", Rules.EASY)
	var order := ["power", "speed", "guard"]
	var i := 0
	while p.now < T0 + 9 * DAY and not p.is_over():
		Helpers.care(p, p.now + 30 * MIN, 30 * MIN)
		if p.wants_leave:
			p.answer_leave(false)
		if p.train(order[i % 3]) == "ok":
			i += 1
		p.hunger = 4
		p.happy = 4
		p._settle()
	check(p.stage == "adult" and not p.is_over(), "活着长到成年")
	var st := p.stats()
	check(st.power >= 100 and st.speed >= 100 and st.guard >= 100, "勤快的练得到冠军赛那么强: %s" % [st])
