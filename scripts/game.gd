class_name Game
extends RefCounted
## 整个游戏: 现在这只魔物、图鉴、以前养过的每一只、调试快进。负责存档读档, 把魔物发生的事翻成中文消息。

var pet: Pet = null
var dex := {}               # 图鉴: 种类 -> 养出过几次
var history: Array = []     # 以前养过的: {species, reason, age, difficulty, ended_at}
var offset := 0             # 调试快进加了多少秒 (只在调试版能快进)
var difficulty := Rules.EASY   # 上次选的难度
var messages: Array = []    # 新消息 {text, rank} (画面拿去显示, 拿完清空; rank 大的更要紧)
var tz := 0                 # 本地时间比世界时间快多少秒
var use_system_tz := true   # 测试关掉, 用固定的 tz
var fixed_time := -1        # 测试用: 不看真的钟, 把「现在」钉在这个时间 (-1 = 看真的钟)
var last_result := ""       # 上一个动作的结果代号 (ok full asleep……), 画面用来决定冒什么小图标

# 第二版: 魔晶、背包、装扮 (跟着主人, 换一只魔物也还在)
var money := Items.START_MONEY
var items := {}             # 吃的: 代号 -> 几个
var owned: Array = []       # 买下来一直有的: 玩具、衣服配饰、房间布置
var equip := {}             # 装扮: 地方 (hat neck wall rug furniture decor) -> 代号
var toy_used := {}          # 玩具上次玩的时间 (Unix 秒)

# 第三版: 住的地方、出门
var places: Array = ["grass"]   # 解锁了的住的地方 (养大一只成年就开一个新的, 学 Paradise)
var outings: Array = Outings.START.duplicate()   # 解锁了的出门地点
var out_at := {}            # 每个地方上次有收获的时间
var stats := {}             # 解锁要数的东西: park 去公园几次, apples 吃了几个苹果
var trophies := {}          # 第四版: 奖杯 (级别 0–4 -> 拿过几个, 跟着主人)
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


## 现在几点 (Unix 秒, 加上调试快进的)
func clock() -> int:
	return (fixed_time if fixed_time >= 0 else int(Time.get_unix_time_from_system())) + offset


func _refresh_tz() -> void:
	if use_system_tz:
		tz = int(Time.get_time_zone_from_system().get("bias", 0)) * 60


func new_egg(diff: String, t := -1, place := "grass") -> void:
	_refresh_tz()
	difficulty = diff
	var at := clock() if t < 0 else t
	pet = Pet.create(at, diff, tz, at ^ 0x5eed + history.size())
	pet.place = place if place in places else "grass"
	messages.append({"text": "一颗魔物蛋出现了! 等一会儿就会孵出来。", "rank": 4})


## 算到现在 (t 不给就是真的现在)
func tick(t := -1) -> void:
	if pet == null:
		return
	_refresh_tz()
	pet.tz = tz
	pet.advance(clock() if t < 0 else t)
	_take_events()


func _take_events() -> void:
	for e in pet.events:
		match e.kind:
			"grow":
				dex[e.id] = int(dex.get(e.id, 0)) + 1
				if Species.DATA[e.id].stage == "adult":
					_unlock_places()
			"end":
				history.append({"species": pet.species, "reason": e.reason, "age": pet.age(),
					"difficulty": pet.difficulty, "ended_at": pet.ended_at, "rank": pet.rank})
		var text := describe(e)
		if text != "":
			messages.append({"text": text, "rank": RANK.get(e.kind, 1)})
	pet.events.clear()


## 同时发生好几件事, 画面只显示最要紧的一条
const RANK := {"end": 5, "grow": 4, "leave_ask": 4, "sit_end": 3, "hotel_end": 3, "sick": 3, "mistake": 3, "call": 2,
	"poop": 1, "sleep": 1, "wake": 1, "sit_start": 1, "hotel_start": 1}


func describe(e: Dictionary) -> String:
	match e.kind:
		"grow":
			if e.from == "egg":
				return "孵出来了! 是「%s」, 它饿了, 快喂它!" % Species.name_of(e.id)
			return "长大了! 变成了「%s」" % Species.name_of(e.id)
		"call":
			return {"hunger": "它饿了! 喂它吃饭吧", "happy": "它不开心, 陪它玩一玩、给点零食",
				"lights": "它睡着了, 记得关灯", "discipline": "它在无理取闹, 该管教一下了"}[e.what]
		"mistake":
			return "没及时照顾它…… (照顾失误 +1)"
		"poop":
			return "它拉便便了"
		"sick":
			return "它生病了! 快给它吃药"
		"sleep":
			return "它困了, 睡着了"
		"wake":
			return "早上好, 它醒了"
		"leave_ask":
			return "它长大了, 说想出去闯荡……"
		"sit_end":
			return "今天托人照看的时间到了, 它被送回来了" if e.get("auto", false) else ""
		"hotel_end":
			return {"hungry": "它饿了或不开心, 旅馆把它送回家了", "late": "约好的时间没去接, 它自己回来了, 很生气 (开心 -2)"}.get(e.reason, "")
		"end":
			return ending_text(e.reason)
	return ""


static func ending_text(reason: String) -> String:
	return {"neglect": "没人照顾, 它死掉了……", "sick": "病得太重, 它死掉了……",
		"old": "它老了, 安安静静地走了。", "left": "它出发去闯荡了! 一路顺风!"}.get(reason, "")


## 玩家做一个动作 (先算到现在再做), 回一句话给画面显示
func act(what: String, arg: Variant = null) -> String:
	if pet == null:
		return ""
	tick()
	var r := ""
	var text := ""
	match what:
		"meal":
			r = pet.feed_meal()
			text = {"ok": "吃了饭, 饱一点了", "full": "它吃饱了, 不想吃",
				"bland": "吃了, 不过一脸嫌弃 (长大了觉得白饭没味道)"}.get(r, "")
		"snack":
			r = pet.feed_snack()
			text = {"ok": "吃了零食, 好开心! (吃多了会胖哦)"}.get(r, "")
		"lights":
			r = pet.toggle_lights()
			text = {"on": "开灯了", "off": "关灯了"}.get(r, "")
		"game":
			# arg = {won: 赢了没有, reward: 给多少魔晶}
			r = pet.finish_game(bool(arg.won))
			if r == "won" or r == "lost":
				money += int(arg.reward)
				text = ("赢了! 它很开心" if r == "won" else "输了…… 它有点失望") + (", 得到魔晶 %d" % arg.reward if arg.reward > 0 else "")
		"food":
			if int(items.get(arg, 0)) <= 0:
				r = "none"
				text = "没有%s了" % Items.name_of(arg)
			else:
				r = pet.eat(Items.DATA[arg])
				if r == "ok":
					if arg == "apple":
						stats["apples"] = int(stats.get("apples", 0)) + 1
						_unlock_outing("lakeside", int(stats.apples) >= 5)
					items[arg] = int(items[arg]) - 1
					if items[arg] <= 0:
						items.erase(arg)
					text = "吃了%s, 好吃!" % Items.name_of(arg)
				else:
					text = {"full": "它吃饱了, 不想吃"}.get(r, "")
		"toy":
			var wait := toy_wait(arg)
			if wait > 0:
				r = "tired"
				text = "它刚玩过%s, 还不想玩 (%s以后)" % [Items.name_of(arg), sitter_text(wait)]
			else:
				r = pet.play_toy()
				if r == "ok":
					toy_used[arg] = clock()
					text = "陪它玩%s, 它很开心!" % Items.name_of(arg)
		"medicine":
			r = pet.give_medicine()
			text = {"healthy": "它没生病, 不用吃药", "more": "吃了药, 还要再吃一次", "cured": "病好了!"}.get(r, "")
		"clean":
			r = pet.clean()
			text = {"nothing": "没有便便要打扫", "ok": "打扫干净了"}.get(r, "")
		"scold":
			r = pet.scold()
			text = {"good": "管教了它, 它乖了一点", "sad": "它没闹, 被骂了很委屈 (不开心 -1)"}.get(r, "")
		"train":
			r = pet.train(arg)
			if r == "ok":
				text = "练%s, %s +%d!" % [Training.DRILLS[arg][0], Training.STATS[arg], pet.last_gain]
			else:
				text = {"small": "宝宝还太小, 长到小孩再练", "hungry": "饿着或不开心, 不想练", "tired": "刚练过, 歇一会儿吧 (%s以后)" %
					sitter_text(maxi(60, pet.trained_at + Training.TRAIN_COOLDOWN - pet.now))}.get(r, "")
		"sitter":
			if pet.in_hotel():
				r = pet.end_hotel("pickup")
				text = "从旅馆接回来了"
			elif pet.sitting():
				r = pet.end_sitter()
				text = "接回来了, 照看的人把它喂得饱饱的"
			else:
				r = pet.start_sitter()
				text = {"ok": "托给别人照看了 (今天还能托 %s)" % sitter_text(pet.sitter_left()),
					"used_up": "今天托人照看的时间用完了 (每天最多 %s)" % sitter_text(Rules.SITTER_PER_DAY)}.get(r, "")
		"leave":
			pet.answer_leave(bool(arg))
			r = "ok"
			text = "" if bool(arg) else "它决定留下来陪你。"
	last_result = r
	if text == "":
		var no := ""
		if pet.stage == "egg":
			no = "还在蛋里呢, 等它孵出来吧"
		elif pet.sitting():
			no = "它托给别人照看了, 先接回来"
		text = {"asleep": "它在睡觉, 别吵它", "sick": "它生病了, 不想玩", "no": no}.get(r, "")
	_take_events()
	return text


# ---------------------------------------------------------------- 第三版: 住的地方

## 养大一只成年就打开下一个地方 (学 Paradise「照顾着就解锁」; 具体几只是我们定的)
func _unlock_places() -> void:
	var adults := 0
	for id in dex:
		if Species.DATA.has(id) and Species.DATA[id].stage == "adult":
			adults += int(dex[id])
	for i in Species.PLACE_ORDER.size():
		var place: String = Species.PLACE_ORDER[i]
		if adults >= i and not place in places:
			places.append(place)
			messages.append({"text": "新的地方「%s」打开了! 下一颗蛋可以在那里养, 会长成那里的魔物" % Species.PLACES[place].name, "rank": 5})


## 搬家: 小孩长成少年时住在哪, 就长成哪里的魔物; 长大以后搬家只换风景
func move(place: String) -> String:
	if pet == null or pet.is_over() or not place in places:
		return "no"
	pet.place = place
	return "ok" if pet.stage in ["egg", "baby", "child"] else "grown"


# ---------------------------------------------------------------- 第三版: 出门

func _unlock_outing(id: String, ok: bool) -> void:
	if ok and not id in outings:
		outings.append(id)
		messages.append({"text": "新的地方「%s」可以去了!" % Outings.info(id).name, "rank": 5})


## 现在能不能出门: ok / no / small 太小 / asleep / sick / away
func can_go_out() -> String:
	if pet == null or pet.is_over() or pet.stage == "egg":
		return "no"
	if pet.stage == "baby":
		return "small"  # 照 On / Meets: 长到小孩才能出门
	if pet.away():
		return "away"
	if pet.asleep:
		return "asleep"
	if pet.sick:
		return "sick"
	return "ok"


## 出门逛一趟 (马上回来): 回 {text 说什么, npc 碰到的魔物, item 带回来的东西}
func go_out(id: String) -> Dictionary:
	tick()
	var r := can_go_out()
	if r != "ok":
		return {"text": {"small": "还太小了, 长到小孩才能出门", "asleep": "它在睡觉, 别吵它", "sick": "它生病了, 先治好吧",
			"away": "它不在家"}.get(r, ""), "npc": "", "item": ""}
	if not id in outings:
		return {"text": "还没解锁: " + Outings.info(id).unlock, "npc": "", "item": ""}
	var now := clock()
	var local_hour := posmod(floori(float(now + tz) / 3600.0), 24)
	_unlock_outing("night", local_hour >= 19 and local_hour < 21)
	var fresh := now - int(out_at.get(id, -Outings.COOLDOWN)) >= Outings.COOLDOWN
	var out := {"text": "", "npc": "", "item": "", "ok": true}
	match id:
		"park":
			stats["park"] = int(stats.get("park", 0)) + 1
			_unlock_outing("forest", int(stats.park) >= 5)
			var others := []
			for place in places:
				for k in ["teen_good", "teen_bad", "best", "good", "mid", "low", "bad1", "bad2"]:
					var sp: String = Species.PLACES[place][k]
					if sp != pet.species:
						others.append(sp)
			out.npc = others[rng.randi() % others.size()]
			if fresh:
				pet.happy = mini(4, pet.happy + 1)
				out.text = "公园里碰到「%s」, 一起玩, 开心 +1" % Species.name_of(out.npc)
			else:
				out.text = "公园里碰到「%s」, 打了个招呼" % Species.name_of(out.npc)
		"forest":
			if not fresh:
				out.text = "在森林里转了一圈, 这次没捡到东西"
			elif rng.randf() < 0.6 and int(items.get("apple", 0)) < Items.MAX_STACK:
				items["apple"] = int(items.get("apple", 0)) + 1
				out.item = "apple"
				out.text = "在森林里捡到一个苹果!"
			else:
				var m := rng.randi_range(5, 10)
				money += m
				out.item = "coin"
				out.text = "在森林里捡到魔晶 %d!" % m
		"lakeside":
			if fresh:
				var m := rng.randi_range(8, 15)
				money += m
				out.item = "coin"
				out.text = "在湖边钓鱼, 钓到魔晶 %d!" % m
			else:
				out.text = "在湖边钓了一会儿鱼, 这次什么都没钓到"
		"night":
			if fresh:
				var food: String = ["cake", "icecream"][rng.randi() % 2]
				if int(items.get(food, 0)) < Items.MAX_STACK:
					items[food] = int(items.get(food, 0)) + 1
				out.item = food
				out.text = "逛夜市, 小摊送了一个%s!" % Items.name_of(food)
			else:
				out.text = "逛了逛夜市, 好热闹"
	if fresh and id != "hotel":
		out_at[id] = now
	pet._settle()
	_take_events()
	last_result = "ok"
	return out


## 比一场 (第四版): 回 Training.fight 的结果 + foe_species 对手是谁 + prize 给的魔晶 + text 说什么; 不能比就只有 error 和 text
func compete(level: int) -> Dictionary:
	tick()
	var res := pet.compete(level)
	if res.has("error"):
		res.text = {"small": "长到少年才能比赛", "asleep": "它在睡觉", "sick": "它生病了, 先治好吧", "hungry": "饿着或不开心, 比不了",
			"tired": "刚比过, 歇一会儿吧 (%s以后)" % sitter_text(maxi(60, pet.matched_at + Training.MATCH_COOLDOWN - pet.now)),
			"locked": "先赢了下面一级再来"}.get(res.error, "现在比不了")
		return res
	var foes := []
	for place in places:
		for k in ["best", "good", "mid", "low", "bad1", "bad2"]:
			var sp: String = Species.PLACES[place][k]
			if sp != pet.species:
				foes.append(sp)
	res.foe_species = foes[rng.randi() % foes.size()]
	var info: Dictionary = Training.RANKS[level]
	res.prize = info.prize if res.won else int(info.prize / 4.0)
	money += res.prize
	if res.rank_up:
		trophies[level] = int(trophies.get(level, 0)) + 1
	if res.won:
		res.text = "%s赢了「%s」! 得到魔晶 %d" % [info.name, Species.name_of(res.foe_species), res.prize]
		if res.rank_up:
			res.text += ", 拿到%s奖杯!" % Training.RANK_NAMES[level]
	else:
		res.text = "%s输给了「%s」…… 得到魔晶 %d" % [info.name, Species.name_of(res.foe_species), res.prize]
	_take_events()
	return res


## 住旅馆几个小时: ok / poor 钱不够 / 别的 (不能出门的原因)
func hotel(hours: int) -> String:
	tick()
	var r := can_go_out()
	if r != "ok" and r != "asleep":
		return r
	var price := hours * Outings.HOTEL_PRICE
	if money < price:
		return "poor"
	r = pet.start_hotel(clock() + hours * Rules.HOUR)
	if r == "ok":
		money -= price
	_take_events()
	return r


## 玩具还要多久才能再玩 (秒, 0 = 现在就能玩)
func toy_wait(id: String) -> int:
	if not toy_used.has(id):
		return 0
	return maxi(0, int(toy_used[id]) + Items.TOY_COOLDOWN - clock())


## 买东西: ok / poor 钱不够 / have 已经有了 / full 吃的放不下了
func buy(id: String) -> String:
	var d: Dictionary = Items.DATA[id]
	if d.kind == "food":
		if int(items.get(id, 0)) >= Items.MAX_STACK:
			return "full"
	elif id in owned:
		return "have"
	if money < d.price:
		return "poor"
	money -= d.price
	if d.kind == "food":
		items[id] = int(items.get(id, 0)) + 1
	else:
		owned.append(id)
		if not equip.has(d.kind) and d.kind != "toy":
			equip[d.kind] = id  # 第一次买这一类的, 直接穿上 / 摆上
	return "ok"


## 换装扮: id 空 = 拿下来
func set_equip(slot: String, id: String) -> void:
	if id == "":
		equip.erase(slot)
	elif id in owned and Items.kind_of(id) == slot:
		equip[slot] = id


## 几小时几分 (托人照看还剩多久)
static func sitter_text(seconds: int) -> String:
	var m := ceili(seconds / 60.0)
	if m >= 60:
		return "%d 小时 %d 分" % [floori(m / 60.0), m % 60] if m % 60 != 0 else "%d 小时" % floori(m / 60.0)
	return "%d 分钟" % m


## 调试用: 快进几秒 (调试版的「更多」里有按钮)
func fast_forward(seconds: int) -> void:
	offset += seconds
	tick()


func take_messages() -> Array:
	var m := messages.duplicate()
	messages.clear()
	return m


# ---------------------------------------------------------------- 存档

func to_dict() -> Dictionary:
	return {"version": 4, "pet": pet.to_dict() if pet != null else null, "dex": dex, "history": history,
		"offset": offset, "difficulty": difficulty, "money": money, "items": items, "owned": owned, "equip": equip,
		"toy_used": toy_used, "places": places, "outings": outings, "out_at": out_at, "stats": stats, "trophies": trophies}


static func from_dict(d: Dictionary) -> Game:
	var g := Game.new()
	if d.get("pet") is Dictionary:
		g.pet = Pet.from_dict(d.pet)
	for k in d.get("dex", {}):
		g.dex[k] = int(d.dex[k])
	for h in d.get("history", []):
		if h is Dictionary:
			h.age = int(h.get("age", 0))
			h.ended_at = int(h.get("ended_at", 0))
			g.history.append(h)
	g.offset = int(d.get("offset", 0))
	g.difficulty = str(d.get("difficulty", Rules.EASY))
	# 第二版加的 (第一版的存档没有这些, 就用一开始的)
	g.money = int(d.get("money", Items.START_MONEY))
	for k in d.get("items", {}):
		if Items.DATA.has(k):
			g.items[k] = int(d.items[k])
	for k in d.get("owned", []):
		if Items.DATA.has(k) and not k in g.owned:
			g.owned.append(str(k))
	for k in d.get("equip", {}):
		if str(d.equip[k]) in g.owned:
			g.equip[k] = str(d.equip[k])
	for k in d.get("toy_used", {}):
		g.toy_used[k] = int(d.toy_used[k])
	# 第三版加的
	for k in d.get("places", []):
		if Species.PLACES.has(k) and not k in g.places:
			g.places.append(str(k))
	for k in d.get("outings", []):
		if not Outings.info(str(k)).is_empty() and not k in g.outings:
			g.outings.append(str(k))
	for k in d.get("out_at", {}):
		g.out_at[k] = int(d.out_at[k])
	for k in d.get("stats", {}):
		g.stats[k] = int(d.stats[k])
	for k in d.get("trophies", {}):
		g.trophies[int(k)] = int(d.trophies[k])
	g._unlock_places()  # 以前版本养大过成年的, 直接打开新地方
	g.messages.clear()
	return g


func save() -> bool:
	return SaveGame.write(to_dict())


static func load_saved() -> Game:
	return from_dict(SaveGame.read())
