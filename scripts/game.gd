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


## 现在几点 (Unix 秒, 加上调试快进的)
func clock() -> int:
	return (fixed_time if fixed_time >= 0 else int(Time.get_unix_time_from_system())) + offset


func _refresh_tz() -> void:
	if use_system_tz:
		tz = int(Time.get_time_zone_from_system().get("bias", 0)) * 60


func new_egg(diff: String, t := -1) -> void:
	_refresh_tz()
	difficulty = diff
	var at := clock() if t < 0 else t
	pet = Pet.create(at, diff, tz, at ^ 0x5eed + history.size())
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
			"end":
				history.append({"species": pet.species, "reason": e.reason, "age": pet.age(),
					"difficulty": pet.difficulty, "ended_at": pet.ended_at})
		var text := describe(e)
		if text != "":
			messages.append({"text": text, "rank": RANK.get(e.kind, 1)})
	pet.events.clear()


## 同时发生好几件事, 画面只显示最要紧的一条
const RANK := {"end": 5, "grow": 4, "leave_ask": 4, "sit_end": 3, "sick": 3, "mistake": 3, "call": 2, "poop": 1,
	"sleep": 1, "wake": 1, "sit_start": 1}


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
		"sitter":
			if pet.sitting():
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
	return {"version": 2, "pet": pet.to_dict() if pet != null else null, "dex": dex, "history": history,
		"offset": offset, "difficulty": difficulty, "money": money, "items": items, "owned": owned, "equip": equip,
		"toy_used": toy_used}


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
	return g


func save() -> bool:
	return SaveGame.write(to_dict())


static func load_saved() -> Game:
	return from_dict(SaveGame.read())
