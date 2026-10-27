extends TestCase
## 第二版: 魔晶、商店、背包、玩具、装扮 (用户 2026-10-25 定的: 钱叫魔晶; 照拓麻歌子, 饭零食药免费、好吃的要买; 装扮只是好看)。
## 存档写到临时文件夹, 不碰真的存档。

const T0 := Helpers.T0


func before_each() -> void:
	SaveGame.dir = OS.get_temp_dir().path_join("monster_pet_test_shop_%d" % OS.get_process_id())


func after_each() -> void:
	SaveGame.erase()
	DirAccess.remove_absolute(SaveGame.dir)


func _game(id := "jianjiao") -> Game:
	var g := Game.new()
	g.use_system_tz = false
	g.fixed_time = T0
	g.pet = Helpers.at(id)
	return g


func test_start_with_a_little_money() -> void:
	eq(Game.new().money, Items.START_MONEY, "一开始送 %d 魔晶" % Items.START_MONEY)


func test_buying_food() -> void:
	var g := _game()
	g.money = 100
	eq(g.buy("apple"), "ok")
	eq(g.money, 92)
	eq(g.items.apple, 1)
	g.money = 5
	eq(g.buy("apple"), "poor", "钱不够")
	eq(g.items.apple, 1)
	g.money = 1000
	for i in 8:
		g.buy("apple")
	eq(g.items.apple, Items.MAX_STACK)
	eq(g.buy("apple"), "full", "同一种吃的最多存 9 个")


func test_buying_things_you_keep() -> void:
	var g := _game()
	g.money = 1000
	eq(g.buy("strawhat"), "ok")
	check("strawhat" in g.owned)
	eq(g.equip.hat, "strawhat", "第一次买帽子直接戴上")
	eq(g.buy("strawhat"), "have", "买过了")
	g.buy("crown")
	eq(g.equip.hat, "strawhat", "再买一顶不会自动换")
	g.set_equip("hat", "crown")
	eq(g.equip.hat, "crown")
	g.set_equip("hat", "bowtie")
	eq(g.equip.hat, "crown", "领结不能当帽子")
	g.set_equip("neck", "scarf")
	check(not g.equip.has("neck"), "没买的不能戴")
	g.set_equip("hat", "")
	check(not g.equip.has("hat"), "摘下来")
	g.buy("ball")
	check(not g.equip.has("toy"), "玩具不用装扮")


func test_eating_from_the_bag() -> void:
	var g := _game()
	g.pet.happy = 1
	eq(g.act("food", "cake"), "蛋糕已经吃光啦")
	g.items["cake"] = 1
	has_text(g.act("food", "cake"), "蛋糕")
	eq(g.pet.happy, 3)
	check(not g.items.has("cake"), "吃完了")


func test_games_pay_money() -> void:
	var g := _game()
	var m := g.money
	has_text(g.act("game", {"won": true, "reward": 20}), "魔晶 20")
	eq(g.money, m + 20)
	g.act("game", {"won": false, "reward": 3})
	eq(g.money, m + 23, "输了也给一点")
	g.pet.asleep = true
	g.act("game", {"won": true, "reward": 20})
	eq(g.money, m + 23, "睡着了玩不了, 没钱")


func test_toys_need_a_rest_between_plays() -> void:
	var g := _game()
	g.owned.append("ball")
	g.pet.happy = 1
	has_text(g.act("toy", "ball"), "皮球")
	eq(g.pet.happy, 2)
	has_text(g.act("toy", "ball"), "先歇会儿")
	eq(g.pet.happy, 2)
	g.fixed_time = T0 + Items.TOY_COOLDOWN
	g.tick()
	g.pet.happy = 2
	g.act("toy", "ball")
	eq(g.pet.happy, 3, "过 3 小时又能玩")


func test_adult_rice_message() -> void:
	var g := _game("huolong")
	g.pet.hunger = 1
	has_text(g.act("meal"), "嫌弃")


func test_shop_things_survive_save() -> void:
	var g := _game()
	g.money = 500
	g.buy("crown")
	g.buy("wall_pink")
	g.buy("apple")
	g.owned.append("ball")
	g.toy_used["ball"] = T0
	g.save()
	var g2 := Game.load_saved()
	eq(g2.money, g.money)
	eq(g2.items, {"apple": 1})
	eq(g2.owned, g.owned)
	eq(g2.equip, g.equip)
	eq(g2.toy_used, {"ball": T0})


func test_first_version_save_still_loads() -> void:
	var g := _game()
	var d := g.to_dict()
	for k in ["money", "items", "owned", "equip", "toy_used"]:
		d.erase(k)
	d.version = 1
	var g2 := Game.from_dict(JSON.parse_string(JSON.stringify(d)))
	eq(g2.money, Items.START_MONEY, "第一版的存档: 送一开始的魔晶")
	check(g2.items.is_empty() and g2.owned.is_empty() and g2.equip.is_empty())
	eq(g2.pet.species, "jianjiao", "魔物还在")


func test_every_item_has_a_picture_and_price() -> void:
	for id in Items.DATA:
		var d: Dictionary = Items.DATA[id]
		check(d.price > 0, "%s 有价钱" % id)
		check(Items.ICON.has(id) or d.has("color"), "%s 有图或颜色" % id)
		if Items.ICON.has(id):
			check(Art.has(Items.ICON[id]), "%s 的图 %s 画了" % [id, Items.ICON[id]])
		var in_shop := false
		for c in Items.SHOP:
			if d.kind in c[1]:
				in_shop = true
		check(in_shop, "%s 在商店里" % id)
	for id in Species.DATA:
		if id != "egg":
			check(Species.DATA[id].has("hat") and Species.DATA[id].has("neck"), "%s 知道帽子戴在哪" % id)
