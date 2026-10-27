extends TestCase
## 第七版: 结婚和下一代 (用户 2026-10-26 定的: 媒人上门介绍; 长成哪一种看照顾, 颜色和头上的特征遗传; 孩子出生后爸妈搬去爸妈家)。
## 还有老死留下一颗蛋。存档写到临时文件夹, 不碰真的存档。

const T0 := Helpers.T0


func before_each() -> void:
	SaveGame.dir = OS.get_temp_dir().path_join("monster_pet_test_family_%d" % OS.get_process_id())


func after_each() -> void:
	SaveGame.erase()
	DirAccess.remove_absolute(SaveGame.dir)


func _game(id := "huolong") -> Game:
	var g := Game.new()
	g.use_system_tz = false
	g.fixed_time = T0
	g.places = ["grass", "lake"]
	g.pet = Helpers.at(id)
	return g


## 拨钟到 seconds 以后 (勤快地照顾着), 再算一下
func _later(g: Game, seconds: int) -> void:
	Helpers.care(g.pet, g.pet.now + seconds, 30 * 60, true, true, false)
	g.fixed_time = g.pet.now
	g.tick()


func test_matchmaker_comes_a_day_after_growing_up() -> void:
	var g := _game()
	_later(g, Rules.MATCH_AFTER - 2 * Rules.HOUR)
	check(not g.pet.wants_match, "成年不到一天, 媒人还没来")
	_later(g, 16 * Rules.HOUR)
	check(g.pet.wants_match, "过了一天, 媒人来了")
	eq(g.pet.match_offers.size(), Genes.OFFERS, "介绍了三位")
	var seen := []
	for o in g.pet.match_offers:
		check(o.species != "huolong", "不会介绍跟自己同一种的")
		check(not o.species in seen, "三位不一样")
		seen.append(o.species)
		eq(Species.DATA[o.species].stage, "adult", "都是成年的")
		check(not Species.DATA[o.species].get("secret", false), "不介绍隐藏的")
		check(Species.place_of(o.species) in g.places, "只介绍打开了的地方的")
		check(Genes.FEATURES.has(o.feature), "头上有特征")
		check(o.hue >= 0.0 and o.hue < 1.0)


func test_matchmaker_waits_until_awake() -> void:
	var q := Helpers.at("huolong")
	var night: int = T0 + 12 * Rules.HOUR  # 晚上 10 点, 火焰龙 9 点就睡了
	Helpers.care(q, night - 2 * Rules.HOUR, 30 * 60, true, true, false)
	q.match_at = night
	q.advance(night + 60)
	check(q.asleep, "晚上睡着了")
	check(not q.wants_match, "睡着的时候媒人不来")
	q.advance(T0 + Rules.DAY + 60)
	check(not q.asleep, "早上醒了")
	check(q.wants_match, "醒了媒人就来了")


func test_decline_and_matchmaker_comes_again() -> void:
	var g := _game()
	_later(g, Rules.MATCH_AFTER + Rules.HOUR)
	check(g.pet.wants_match)
	has_text(g.act("match", -1), "过一天再来")
	check(not g.pet.wants_match)
	eq(g.pet.stage, "adult", "没结婚, 照样过日子")
	_later(g, Rules.MATCH_AGAIN + Rules.HOUR)
	check(g.pet.wants_match, "过一天媒人又来了")


func test_marry_leaves_an_egg_and_parents_move_out() -> void:
	var g := _game()
	g.pet.hue = 0.95
	_later(g, Rules.MATCH_AFTER + Rules.HOUR)
	var offer: Dictionary = g.pet.match_offers[1]
	offer.hue = 0.05
	g.act("match", 1)
	eq(g.pet.stage, "gone", "结婚了")
	eq(g.pet.end_reason, "married")
	check(g.pet.is_over())
	eq(g.pet.partner.species, offer.species)
	eq(g.history.back().reason, "married", "记进以前养过的")
	eq(g.history.back().partner, offer.species)
	eq(g.parents.a.species, "huolong", "爸妈家住着它")
	eq(g.parents.b.species, offer.species, "和结婚的对象")
	eq(g.parents.gen, 1)
	eq(int(g.next_egg.gen), 2, "留下第 2 代的蛋")
	var h: float = g.next_egg.hue
	check(h > 0.9 or h < 0.1, "颜色是 0.95 和 0.05 的中间 (在 0 附近), 实际 %.2f" % h)
	check(g.next_egg.feature in [Genes.feature_of(g.parents.a), Genes.feature_of(offer)], "头上的特征从爸妈之一来")
	eq(g.pending_letters.size(), 1, "过一天爸妈家寄信来")
	has_text(Game.ending_text("married"), "爸妈家")


func test_child_species_still_depends_on_care() -> void:
	var g := _game()
	_later(g, Rules.MATCH_AFTER + Rules.HOUR)
	g.act("match", 0)
	var genes := g.next_egg.duplicate()
	g.new_egg(Rules.EASY, g.pet.now, "grass", genes)
	eq(g.pet.gen, 2, "第 2 代")
	eq(g.pet.hue, float(genes.hue), "颜色遗传")
	eq(g.pet.feature, str(genes.feature), "头上的特征遗传")
	eq(g.next_egg, {}, "留下的蛋孵了")
	# 照顾得好: 跟第一代一样长成好的那几种 (长成哪种不看爸妈)
	Helpers.care(g.pet, g.pet.now + 4 * Rules.DAY, 15 * 60, true, true, false)
	eq(g.pet.stage, "adult")
	check(g.pet.species in ["huolong", "shuiling", "linlu"], "勤快地照顾, 长成好的那几种: %s" % g.pet.species)
	eq(g.pet.gen, 2, "长大了还是第 2 代")
	eq(g.pet.feature, str(genes.feature))


func test_old_age_leaves_an_egg() -> void:
	var g := _game()
	g.pet.lifespan = 1
	_later(g, Rules.DAY + Rules.HOUR)
	eq(g.pet.end_reason, "old")
	eq(int(g.next_egg.gen), 2, "老死留下一颗蛋")
	var h: float = g.next_egg.hue
	var own := Art.main_hue("huolong")
	check(absf(fposmod(h - own + 0.5, 1.0) - 0.5) <= Genes.MUTATION + 0.001, "颜色跟它差不多")
	eq(g.next_egg.feature, "leaf", "第一代草原的魔物传下去的是叶芽")
	eq(g.parents, {}, "没有爸妈家 (它不在了)")


func test_leaving_or_dying_young_leaves_no_egg() -> void:
	var g := _game()
	g.pet.wants_leave = true
	g.act("leave", true)
	eq(g.pet.end_reason, "left")
	eq(g.next_egg, {}, "放走的没有留下蛋")
	var d := _game()
	d.pet._end("neglect")
	d._take_events()
	eq(d.next_egg, {}, "没照顾好死掉的没有蛋")


func test_fresh_egg_drops_the_family_egg() -> void:
	var g := _game()
	g.pet.lifespan = 1
	_later(g, Rules.DAY + Rules.HOUR)
	check(not g.next_egg.is_empty())
	g.new_egg(Rules.EASY)
	eq(g.pet.gen, 1, "换一颗新蛋是第 1 代")
	eq(g.pet.hue, -1.0)
	eq(g.next_egg, {}, "留下的那颗就不要了")


func test_parents_house() -> void:
	var g := _game()
	_later(g, Rules.MATCH_AFTER + Rules.HOUR)
	g.act("match", 0)
	check(not g.can_visit_parents(), "还是蛋 (结束了) 的时候不能去")
	g.new_egg(Rules.EASY, g.pet.now, "grass", g.next_egg.duplicate())
	_later(g, 2 * Rules.HOUR)
	check(g.can_visit_parents(), "第 2 代能去爸妈家")
	has_text(g.act("parents"), "爸妈家")
	check(g.pet.sitting(), "跟托人照看一样: 不在家")
	eq(g.pet.sit_where, "parents")
	g.fixed_time += 2 * Rules.HOUR
	g.tick()
	var before := g.pet.smart
	has_text(g.act("sitter"), "爸妈教了它")
	eq(g.pet.smart, before + 1, "待够 1 小时, 聪明 +1")
	eq(g.pet.sitter_left(), Rules.SITTER_PER_DAY - 2 * Rules.HOUR, "跟托人照看共用每天的时间")
	g.act("parents")
	g.fixed_time += 2 * Rules.HOUR
	g.tick()
	var text := g.act("sitter")
	check(not text.contains("教了"), "一天只教一次: %s" % text)
	eq(g.pet.smart, before + 1)
	# 换一颗新蛋 (第 1 代) 就没有爸妈家了
	g.new_egg(Rules.EASY)
	check(not g.can_visit_parents(), "新蛋没有爸妈家")


func test_genes_mix_on_a_circle() -> void:
	check(absf(Genes.mix(0.2, 0.4) - 0.3) < 0.001)
	var m := Genes.mix(0.95, 0.05)
	check(m < 0.001 or m > 0.999, "0.95 和 0.05 的中间是 0, 实际 %.3f" % m)
	eq(Genes.feature_of({"species": "hailong", "feature": ""}), "fin", "湖泊的传小鳍")
	eq(Genes.feature_of({"species": "fengying", "feature": ""}), "feather", "天空岛的传羽毛")
	eq(Genes.feature_of({"species": "huolong", "feature": "flower"}), "flower", "有遗传的传遗传的")


func test_recolor_keeps_outline() -> void:
	check(absf(Art.main_hue("huolong") - Color("e8483a").h) < 0.001, "火焰龙主要是红色")
	eq(Art.recolor(Art.COLORS.k, 0.3), Art.COLORS.k, "描边不换颜色")
	eq(Art.recolor(Art.COLORS.w, 0.3), Art.COLORS.w, "白色不换")
	var c := Art.recolor(Art.COLORS.r, Art.shift_for("huolong", 0.6))
	check(absf(c.h - 0.6) < 0.01, "红色换成了色相 0.6 (蓝色)")
	eq(Art.shift_for("huolong", -1.0), 0.0, "没有遗传就不换")
	for f in Genes.FEATURES:
		check(Art.has("feature_" + f), "%s 有图" % f)
	var tex := Art.look_texture({"species": "huolong", "hue": 0.6, "feature": "horn"}, 4)
	eq(tex.get_size(), Vector2(64, 64))


func test_family_is_saved() -> void:
	var g := _game()
	_later(g, Rules.MATCH_AFTER + Rules.HOUR)
	g.act("match", 2)
	check(g.save())
	var back := Game.load_saved()
	eq(back.parents.b.species, g.parents.b.species)
	eq(int(back.parents.gen), 1)
	eq(int(back.next_egg.gen), 2)
	back.new_egg(Rules.EASY, -1, "grass", back.next_egg.duplicate())
	back.pet.hatched_at = back.pet.now
	check(back.save())
	var again := Game.load_saved()
	eq(again.pet.gen, 2)
	check(absf(again.pet.hue - float(g.next_egg.hue)) < 0.0001, "颜色存下来了")
	eq(again.pet.feature, str(g.next_egg.feature))


func test_matchmaker_offers_are_saved() -> void:
	var g := _game()
	_later(g, Rules.MATCH_AFTER + Rules.HOUR)
	check(g.save())
	var back := Game.load_saved()
	check(back.pet.wants_match, "读档以后媒人还在")
	eq(back.pet.match_offers.size(), Genes.OFFERS)
	eq(back.pet.match_offers[0].species, g.pet.match_offers[0].species)
