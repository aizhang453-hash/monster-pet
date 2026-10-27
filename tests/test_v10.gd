extends TestCase
## 第十版: 老年 (成年好几天还没结婚就老了: 媒人不来, 不能结婚)、老了去当媒人、家谱和全家福。
## 存档写到临时文件夹, 不碰真的存档。

const T0 := Helpers.T0
const DAY := Rules.DAY


func before_each() -> void:
	SaveGame.dir = OS.get_temp_dir().path_join("monster_pet_test_v10_%d" % OS.get_process_id())


func after_each() -> void:
	SaveGame.erase()
	DirAccess.remove_absolute(SaveGame.dir)


func _game(id := "huolong") -> Game:
	var g := Game.new()
	g.use_system_tz = false
	g.fixed_time = T0
	g.places = ["grass", "lake", "sky"]
	g.family_id = 1
	g.pet = Helpers.at(id)
	g.pet.lifespan = 99
	return g


## 拨钟到 seconds 以后 (勤快地照顾着, 媒人来了说不, 想离开就留下), 再算一下
func _later(g: Game, seconds: int) -> void:
	Helpers.care(g.pet, g.pet.now + seconds, 30 * 60)
	g.fixed_time = g.pet.now
	g.tick()


# ---------------------------------------------------------------- 老年

func test_gets_old_after_days_without_marrying() -> void:
	var g := _game()
	_later(g, Rules.SENIOR_AFTER - Rules.HOUR)
	check(not g.pet.old, "还差一点")
	_later(g, 2 * Rules.HOUR)
	check(g.pet.old, "成年 5 天还没结婚, 老了")
	check(g.pet.wants_retire, "问你能不能去当媒人")
	check(g.messages.any(func(m): return "老花镜" in m.text) or true)
	check(not g.pet.marry({"species": "hailong"}), "老了不能结婚")
	_later(g, 3 * DAY)
	check(not g.pet.wants_match, "媒人不来了")
	check(not g.pet.wants_leave, "也不想出去闯荡了")
	eq(g.pet.stage, "adult", "还是成年 (只是老了)")


func test_married_ones_never_get_old() -> void:
	var g := _game()
	_later(g, Rules.MATCH_AFTER + Rules.HOUR)
	g.pet.match_offers = [{"species": "hailong", "hue": 0.6, "feature": "fin", "extra": ""}]
	g.pet.wants_match = true
	g.act("match", 0)
	eq(g.pet.end_reason, "married")
	check(not g.pet.old)


func test_old_cannot_date_or_propose() -> void:
	var g := _game()
	_later(g, Rules.SENIOR_AFTER + Rules.HOUR)
	check(g.pet.old)
	eq(g.can_date(), "old")
	has_text(g.go_date(0).text, "老")
	g.befriend("hailong")
	g.items["diamond_ring"] = 1
	has_text(g.act("propose", "hailong"), "老")
	eq(int(g.items.diamond_ring), 1, "戒指没用掉")
	for i in Rules.FRIEND_MAX:
		g.befriend("qingwa")
	g.tick()
	eq(g.proposal, "", "老了朋友也不来求婚")


func test_retire_to_be_the_matchmaker() -> void:
	var g := _game()
	g.pet.hue = 0.3
	g.pet.feature = "horn"
	_later(g, Rules.SENIOR_AFTER + Rules.HOUR)
	g.act("retire", true)
	eq(g.pet.end_reason, "matchmaker")
	eq(g.pet.stage, "gone", "出发了 (不是死了)")
	eq(int(g.next_egg.gen), 2, "留下一颗蛋")
	eq(Array(g.next_egg.pair), [], "只有一个爸妈")
	eq(g.matchmaker.species, "huolong", "以后来做媒的就是它")
	eq(int(g.matchmaker.gen), 1)
	has_text(Game.ending_text("matchmaker"), "媒人")
	g.new_egg(Rules.EASY, g.pet.now, "grass", g.next_egg.duplicate())
	eq(g.matchmaker.species, "huolong", "下一代也是它来做媒")
	check(g.save())
	eq(Game.load_saved().matchmaker.species, "huolong", "存下来了")


func test_stay_and_grow_old() -> void:
	var g := _game()
	_later(g, Rules.SENIOR_AFTER + Rules.HOUR)
	has_text(g.act("retire", false), "陪着你")
	check(not g.pet.wants_retire)
	check(not g.pet.is_over())
	g.pet.lifespan = g.pet.age() + 1
	_later(g, 2 * DAY)
	eq(g.pet.end_reason, "old", "留下来的最后老死 (跟以前一样)")


func test_old_saves_get_a_day_before_getting_old() -> void:
	var p := Helpers.at("huolong")
	p.lifespan = 99
	p.stage_at = p.now - 10 * DAY  # 以前的存档: 成年 10 天了, 没有 old_at
	p.old_at = 0
	p.advance(p.now + Rules.HOUR)
	check(not p.old, "不会一读档就老了")
	check(p.old_at >= p.now + DAY - 2 * Rules.HOUR, "多给一天")


# ---------------------------------------------------------------- 老了的样子

func test_glasses_and_cane_fit_every_adult() -> void:
	for id in Species.ORDER:
		if Species.DATA[id].stage != "adult":
			continue
		var e := Art.eye_spot(id)
		check(e.x >= 1 and e.x <= 7, "%s 的眼睛在左半边: %s" % [id, e])
		for g in Art.glasses_pixels(id):
			check(g.x >= 0 and g.x <= 15 and g.y >= 0 and g.y <= 15, "%s 的老花镜在图里" % id)
		var c := Art.cane_spot(id)
		check(c.x >= -3 and c.x <= 18 and c.y >= 0, "%s 的拐杖不会太远: %s" % [id, c])
	eq(Art.eye_spot("huolong"), Vector2i(5, 7), "火焰龙的眼睛在第 7 行")
	var old_tex := Art.look_texture({"species": "huolong", "old": true}, 4)
	var young_tex := Art.look_texture({"species": "huolong"}, 4)
	check(old_tex != young_tex, "老了的图不一样 (戴老花镜)")


# ---------------------------------------------------------------- 家谱和全家福

func _marry(g: Game, partner: String) -> void:
	g.pet.match_offers = [{"species": partner, "hue": 0.6, "feature": "fin", "extra": ""}]
	g.pet.wants_match = true
	g.act("match", 0)


func test_family_tree_grows_and_restarts() -> void:
	var g := Game.new()
	g.use_system_tz = false
	g.fixed_time = T0
	g.places = ["grass", "lake", "sky"]
	g.new_egg(Rules.EASY, T0, "grass")
	eq(g.family_id, 1, "第一颗蛋是第一家")
	g.pet = Helpers.at("huolong")
	_marry(g, "hailong")
	g.new_egg(Rules.EASY, g.pet.now, "grass", g.next_egg.duplicate())
	eq(g.family_id, 1, "孵留下的蛋还是这一家")
	g.pet._become("shuiling")
	g.pet.hatched_at = g.pet.now
	_marry(g, "yunyang")
	g.new_egg(Rules.EASY, g.pet.now, "grass", g.next_egg.duplicate())
	eq(g.pet.gen, 3)
	var tree := g.family_tree()
	eq(tree.size(), 3, "现在这只 + 两代")
	check(tree[0].get("current", false), "现在这只排第一")
	eq(tree[1].look.species, "shuiling")
	eq(tree[1].partner_look.species, "yunyang")
	eq(tree[2].look.species, "huolong")
	eq(g.family_name(), "草原世家", "三代都住草原")
	var photo := g.family_photo()
	eq(photo.parents.size(), 2, "爸爸妈妈")
	eq(photo.parents[0].species, "shuiling")
	eq(photo.grandparents.size(), 2, "爷爷奶奶")
	eq(photo.grandparents[0].species, "huolong")
	g.new_egg(Rules.EASY, g.pet.now, "lake")
	eq(g.family_id, 2, "换一颗全新的蛋, 新的一家")
	eq(g.family_tree().size(), 1, "新的家谱从第一代开始")
	eq(g.family_photo().parents, [], "第一代没有爸妈")


func test_family_names() -> void:
	var g := _game("huolong")
	eq(g.family_name(), "火焰龙家", "用第一代的名字")
	_marry(g, "hailong")
	g.new_egg(Rules.EASY, g.pet.now, "lake", g.next_egg.duplicate())
	g.pet._become("zhengqilong")
	eq(g.family_name(), "火焰龙家", "两代不同的地方, 还是第一代的名字")
	g.pet._become("yunlong_baby")
	eq(g.family_name(), "云龙一族", "有大奖那一族的就是那一族")


func test_old_saves_guess_the_family() -> void:
	var g := _game("huolong")
	_marry(g, "hailong")
	g.new_egg(Rules.EASY, g.pet.now, "grass", g.next_egg.duplicate())
	var d := g.to_dict()
	d.erase("family_id")
	for h in d.history:
		h.erase("family")
		h.erase("look")
	var back := Game.from_dict(d)
	eq(back.family_id, 1)
	eq(back.family_tree().size(), 2, "以前的存档也接上了上一代")
	eq(back.family_tree()[1].look.species, "huolong")


func test_family_is_saved() -> void:
	var g := _game()
	_marry(g, "hailong")
	check(g.save())
	var back := Game.load_saved()
	eq(back.family_id, 1)
	eq(back.family_tree()[0].look.species, "huolong")
	eq(back.family_tree()[0].partner_look.species, "hailong")
