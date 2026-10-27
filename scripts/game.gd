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
var last_gift := ""         # 第八版: 散步回来带的东西 (画面冒的小图标)

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
var letters: Array = []     # 第五版: 收到的信 {title, body, at, read}, 新的在后面
var pending_letters: Array = []   # 还没寄到的信 {at, title, body} (比如放走的魔物过一天寄回来)
# 第六版: 节日、纪念品 (跟着主人)
var celebrated := {}        # 哪年哪个节已经收过礼物 ("spring2026" -> true)
var souvenirs := {}         # 纪念品: 代号 -> 有几个
# 第七版: 结婚和下一代
var parents := {}           # 爸妈家住着谁: {a: 你养的那只的样子, b: 结婚的对象, gen: 它们是第几代}
var next_egg := {}          # 留下的蛋 (结婚生的、老死留下的): {gen, hue, feature}; 空 = 没有
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


## 现在几点 (Unix 秒, 加上调试快进的)
func clock() -> int:
	return (fixed_time if fixed_time >= 0 else int(Time.get_unix_time_from_system())) + offset


func _refresh_tz() -> void:
	if use_system_tz:
		tz = int(Time.get_time_zone_from_system().get("bias", 0)) * 60


## genes: 第七版, 孵留下的那颗蛋 ({gen, hue, feature}); 不给就是一颗全新的蛋 (留下的蛋就不要了)
func new_egg(diff: String, t := -1, place := "grass", genes := {}) -> void:
	_refresh_tz()
	difficulty = diff
	var at := clock() if t < 0 else t
	pet = Pet.create(at, diff, tz, at ^ 0x5eed + history.size())
	pet.place = place if place in places else "grass"
	pet.gen = int(genes.get("gen", 1))
	pet.hue = float(genes.get("hue", -1.0))
	pet.feature = str(genes.get("feature", ""))
	next_egg = {}
	if pet.gen > 1:
		messages.append({"text": "第 %d 代的蛋! 等一会儿就会孵出来。" % pet.gen, "rank": 4})
	else:
		messages.append({"text": "一颗魔物蛋出现了! 等一会儿就会孵出来。", "rank": 4})


## 算到现在 (t 不给就是真的现在)
func tick(t := -1) -> void:
	if pet == null:
		return
	_refresh_tz()
	pet.tz = tz
	pet.advance(clock() if t < 0 else t)
	_take_events()
	_deliver_letters()
	_celebrate(clock() if t < 0 else t)


func _take_events() -> void:
	for e in pet.events:
		match e.kind:
			"grow":
				dex[e.id] = int(dex.get(e.id, 0)) + 1
				if Species.DATA[e.id].stage == "adult":
					_unlock_places()
					_job_letter()
			"match_ask":
				pet.match_offers = Genes.offers(places, pet.species, rng)
			"walk_end":
				e.text = _walk_gift() if e.get("done", false) else ""
			"end":
				history.append({"species": pet.species, "reason": e.reason, "age": pet.age(),
					"difficulty": pet.difficulty, "ended_at": pet.ended_at, "rank": pet.rank, "gen": pet.gen,
					"partner": pet.partner.get("species", "")})
				if e.reason == "married":
					# 第七版: 生下一颗蛋, 两口子搬去爸妈家; 过一天寄信来 (信里的话是 Claude 暂定的)
					parents = {"a": Genes.look_of(pet), "b": pet.partner, "gen": pet.gen}
					next_egg = Genes.child(Genes.look_of(pet), pet.partner, pet.gen, rng)
					pending_letters.append({"at": pet.ended_at + Rules.DAY, "title": "爸妈家寄来的信",
						"body": "我们在爸妈家住得可舒服啦。\n忙的时候就把孩子送过来吧 (出门 → 爸妈家), 我们会好好照顾它, 还会教它一些东西。\n—— %s和%s" %
						[pet.display_name(), Species.name_of(pet.partner.species)]})
				elif e.reason == "old":
					next_egg = Genes.child(Genes.look_of(pet), {}, pet.gen, rng)  # 老死留下一颗蛋
				if e.reason == "left":
					# 放走的魔物过一天寄信回来 (第五版「收到信」; 信里的话是 Claude 暂定的, 用户想改随时改)
					pending_letters.append({"at": pet.ended_at + Rules.DAY, "title": "「%s」寄来的信" % pet.display_name(),
						"body": "我在外面过得超好的! 认识了好多新朋友, 每天都去没去过的地方。\n谢谢你把我养大!\n—— %s" % pet.display_name()})
		var text := describe(e)
		if text != "":
			messages.append({"text": text, "rank": RANK.get(e.kind, 1)})
	pet.events.clear()


## 同时发生好几件事, 画面只显示最要紧的一条
const RANK := {"end": 5, "grow": 4, "leave_ask": 4, "match_ask": 4, "pest": 3, "pest_hit": 3, "walk_start": 2, "walk_end": 2, "sit_end": 3, "hotel_end": 3, "sick": 3, "mistake": 3, "call": 2,
	"poop": 1, "sleep": 1, "wake": 1, "sit_start": 1, "hotel_start": 1}


func describe(e: Dictionary) -> String:
	match e.kind:
		"grow":
			if e.from == "egg":
				return "孵出来啦! 是「%s」! 它肚子咕咕叫, 快喂它~" % Species.name_of(e.id)
			return "长大啦! 变成了「%s」" % Species.name_of(e.id)
		"call":
			return {"hunger": "它饿得咕噜咕噜叫, 喂它吃饭吧", "happy": "它闷闷不乐的, 陪它玩一玩、给点零食吧",
				"lights": "它睡着了, 帮它关个灯吧", "discipline": "它在耍小脾气! 该管教一下了",
				"good": "它做了件好事! 快夸夸它 (管教 → 夸它)"}[e.what]
		"mistake":
			return "没来得及照顾它…… (照顾失误 +1)"
		"poop":
			return "噗~ 它拉便便了"
		"sick":
			return "它生病了, 头上冒出小骷髅! 快给它吃药"
		"sleep":
			return "它打了个大哈欠, 睡着了"
		"wake":
			return "早上好! 它醒啦"
		"leave_ask":
			return "它长大了, 说想出去看看外面的世界……"
		"match_ask":
			return "叮咚~ 媒人上门啦!"
		"walk_start":
			return "它自己溜出去散步啦~ 一会儿就回来"
		"walk_end":
			return e.get("text", "")
		"pest":
			return "哎呀, 有只捣蛋精溜进来了! 快点它一下把它赶跑"
		"pest_hit":
			return "捣蛋精扮了个鬼脸, 把它吓了一大跳…… (开心 -1)"
		"sit_end":
			if not e.get("auto", false):
				return ""
			if e.get("where", "") == "parents":
				return "今天的时间到了, 爸妈把它送回来了" + ("。爸妈教了它一些东西 (聪明、时尚、善良 +1)" if e.get("taught", false) else "")
			return "今天托人照看的时间到了, 它被送回来啦"
		"hotel_end":
			return {"hungry": "它饿了闹着要回家, 旅馆把它送回来了", "late": "约好的时间没去接, 它自己气呼呼地回来了 (开心 -2)"}.get(e.reason, "")
		"end":
			return ending_text(e.reason)
	return ""


static func ending_text(reason: String) -> String:
	return {"neglect": "没人照顾它…… 它变成了小幽灵。", "sick": "病得太重…… 它变成了小幽灵。",
		"old": "它老了, 安安静静地走了, 留下了一颗蛋。", "left": "它背上小包出发啦! 一路顺风~",
		"married": "结婚了! 生下一颗蛋, 两口子搬去爸妈家住了。"}.get(reason, "")


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
			text = {"ok": "吃了饭, 肚子饱一点啦", "full": "吃饱饱了, 它把头扭过去不想吃",
				"bland": "吃是吃了, 一脸嫌弃: 白饭好没味道哦……"}.get(r, "")
		"snack":
			r = pet.feed_snack()
			text = {"ok": "零食好好吃! 开心~ (吃多了会胖哦)"}.get(r, "")
		"lights":
			r = pet.toggle_lights()
			text = {"on": "啪, 开灯啦", "off": "关灯了, 晚安~"}.get(r, "")
		"game":
			# arg = {won: 赢了没有, reward: 给多少魔晶}
			r = pet.finish_game(bool(arg.won))
			if r == "won" or r == "lost":
				if r == "won" and pet.personality == "lively":
					arg.reward = ceili(int(arg.reward) * 1.3)  # 第八版: 活泼的赢了多拿三成
				money += int(arg.reward)
				text = ("赢啦! 它乐得转圈圈" if r == "won" else "输了…… 它有点小失落") + (", 拿到魔晶 %d" % arg.reward if arg.reward > 0 else "")
		"food":
			if int(items.get(arg, 0)) <= 0:
				r = "none"
				text = "%s已经吃光啦" % Items.name_of(arg)
			else:
				r = pet.eat(Items.DATA[arg])
				if r == "ok":
					if arg == "apple":
						stats["apples"] = int(stats.get("apples", 0)) + 1
						_unlock_outing("lakeside", int(stats.apples) >= 5)
					items[arg] = int(items[arg]) - 1
					if items[arg] <= 0:
						items.erase(arg)
					text = "%s好好吃! 吃得一干二净~" % Items.name_of(arg)
				else:
					text = {"full": "吃饱饱了, 它把头扭过去不想吃"}.get(r, "")
		"toy":
			var wait := toy_wait(arg)
			if wait > 0:
				r = "tired"
				text = "刚玩过%s, 它说先歇会儿 (%s以后再玩)" % [Items.name_of(arg), sitter_text(wait)]
			else:
				r = pet.play_toy()
				if r == "ok":
					toy_used[arg] = clock()
					text = "陪它玩%s, 玩得好开心!" % Items.name_of(arg)
		"medicine":
			r = pet.give_medicine()
			text = {"healthy": "它好好的, 不用吃药啦", "more": "咕嘟, 吃了药! 还要再吃一次哦", "cured": "病好啦! 又活蹦乱跳了"}.get(r, "")
		"clean":
			r = pet.clean()
			text = {"nothing": "很干净啦, 不用打扫", "ok": "便便扫干净啦" + (", 它身上也有点脏, 再按一次给它洗个澡吧" if pet.tidy < 4 else ""),
				"bath": "洗了个澡, 香喷喷的!"}.get(r, "")
		"scold":
			r = pet.scold()
			text = {"good": "说了它几句, 它乖乖不闹了", "sad": "它明明没闹, 被骂得好委屈…… (开心 -1)"}.get(r, "")
		"train":
			r = pet.train(arg)
			if r == "ok":
				text = "嘿咻嘿咻, 练了%s! %s +%d" % [Training.DRILLS[arg][0], Training.STATS[arg], pet.last_gain]
			else:
				text = {"small": "宝宝还太小啦, 长到小孩再练", "hungry": "肚子饿或者不开心, 它不想练", "tired": "刚练完, 让它喘口气吧 (%s以后)" %
					sitter_text(maxi(60, pet.trained_at + Training.TRAIN_COOLDOWN - pet.now))}.get(r, "")
		"praise":
			r = pet.praise()
			text = {"good": "夸了它! 它不好意思地笑了 (善良 +2)", "puzzled": "它歪着头: 我做了什么吗?"}.get(r, "")
		"pat":
			r = pet.pat()
			text = {"ok": "摸摸头~ 它舒服得眯起了眼睛", "again": "它蹭了蹭你的手指"}.get(r, "")
		"study":
			# arg = {subject 哪门课, correct 答对几题}
			r = pet.study(arg.subject, int(arg.correct))
			if r == "ok":
				text = "%s答对了 %d 题! %s +%d" % [School.SUBJECTS[arg.subject].name, arg.correct, School.SUBJECTS[arg.subject].stat, pet.last_gain]
				if pet.classes % 5 == 0:
					_report_letter()
			else:
				text = {"small": "宝宝还太小啦", "grown": "已经是大人啦, 该去上班了", "tired": "刚下课, 让它玩一会儿吧"}.get(r, "")
		"work":
			# arg = 赢了没有
			var pay := pet.work_done(bool(arg))
			if pay >= 0:
				money += pay
				r = "won" if bool(arg) else "lost"
				text = "下班啦! %s拿到魔晶 %d" % ["今天干得不错, " if bool(arg) else "今天有点手忙脚乱, ", pay]
			else:
				r = pet.can_work()
				text = {"tired": "刚下班, 让它歇会儿吧", "hungry": "肚子饿或者不开心, 上不了班", "nojob": "还没有工作呢"}.get(r, "")
		"sitter":
			if pet.walking():
				r = pet.end_walk(false)
				text = "把它叫回来了, 它还有点意犹未尽"
			elif pet.in_hotel():
				r = pet.end_hotel("pickup")
				text = "从旅馆接回来啦"
				if rng.randf() < SOUVENIR_CHANCE:
					add_souvenir("key")
					text += ", 还带回了纪念品「%s」!" % Items.SOUVENIRS.key.name
			elif pet.sitting():
				var at_parents := pet.sit_where == "parents"
				r = pet.end_sitter()
				if at_parents:
					text = "从爸妈家接回来啦" + (", 爸妈教了它一些东西 (聪明、时尚、善良 +1)" if r == "taught" else "")
				else:
					text = "接回来啦, 被照顾得饱饱的"
			else:
				r = pet.start_sitter()
				text = {"ok": "托给别人照看啦 (今天还能托 %s)" % sitter_text(pet.sitter_left()),
					"used_up": "今天托人照看的时间用完啦 (每天最多 %s)" % sitter_text(Rules.SITTER_PER_DAY)}.get(r, "")
		"shoo":
			r = pet.shoo()
			text = "啪! 把捣蛋精赶跑啦" if r == "ok" else ""
		"personality":
			r = pet.set_personality(str(arg))
			text = "原来它是%s的性格呀~" % Personality.name_of(str(arg)) if r == "ok" else ""
		"parents":
			if not can_visit_parents():
				r = "no"
				text = "还没有爸妈家"
			else:
				r = pet.start_sitter("parents")
				text = {"ok": "送到爸妈家了, 爸妈会照顾它",
					"used_up": "今天托人照看的时间用完了, 爸妈家也是 (每天最多 %s)" % sitter_text(Rules.SITTER_PER_DAY)}.get(r, "")
		"match":
			# arg = 挑第几个 (-1 = 现在还不想结婚)
			pet.answer_match(int(arg))
			r = "married" if pet.end_reason == "married" else "later"
			text = "" if r == "married" else "现在还不想结婚。媒人说: 那我过一天再来~"
		"leave":
			pet.answer_leave(bool(arg))
			r = "ok"
			text = "" if bool(arg) else "它决定留下来, 继续陪着你~"
	last_result = r
	if text == "":
		var no := ""
		if pet.stage == "egg":
			no = "还在蛋里呢, 再等等吧"
		elif pet.sitting():
			no = "它不在家, 先接回来吧"
		text = {"asleep": "嘘, 它在睡觉呢", "sick": "它生病了, 没力气玩", "no": no}.get(r, "")
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
			messages.append({"text": "新的地方「%s」打开啦! 下一颗蛋可以在那里养, 会长成那里的魔物哦" % Species.PLACES[place].name, "rank": 5})


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
		messages.append({"text": "新的地方「%s」可以去啦!" % Outings.info(id).name, "rank": 5})


## 第八版: 自己散步回来带的东西 (魔晶、苹果, 或者认识了新朋友); 回一句话
func _walk_gift() -> String:
	var roll := rng.randf()
	if roll < 0.45:
		var m := rng.randi_range(3, 8)
		money += m
		last_gift = "coin"
		return "它散步回来啦, 嘴里叼着魔晶 %d!" % m
	if roll < 0.75 and int(items.get("apple", 0)) < Items.MAX_STACK:
		items["apple"] = int(items.get("apple", 0)) + 1
		last_gift = "apple"
		return "它散步回来啦, 还捡了一个苹果!"
	pet.happy = mini(4, pet.happy + 1)
	last_gift = "heart"
	return "它散步回来啦, 说在路上交了个新朋友, 开心 +1"


## 第八版: 带它去美食街的店吃东西: 回 {text, ok, icon}
func eat_out(shop: String) -> Dictionary:
	tick()
	var r := can_go_out()
	if r != "ok":
		return {"text": {"small": "还太小了, 长到小孩才能出门", "asleep": "它在睡觉, 别吵它", "sick": "它生病了, 先治好吧",
			"away": "它不在家"}.get(r, ""), "ok": false}
	var d: Dictionary = Outings.SHOPS[shop]
	if money < int(d.price):
		return {"text": "魔晶不够啦, 去玩几局小游戏再来吧", "ok": false}
	r = pet.eat(d)
	if r != "ok":
		return {"text": "它肚子圆滚滚的, 吃不下啦", "ok": false}
	money -= int(d.price)
	last_result = "ok"
	_take_events()
	return {"text": "在%s吃了%s, 好好吃!" % [d.name, d.food], "ok": true, "icon": d.icon}


## 第七版: 能不能送去爸妈家 (爸妈是上一代的时候)
func can_visit_parents() -> bool:
	return pet != null and not pet.is_over() and not parents.is_empty() and pet.gen == int(parents.gen) + 1


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
		return {"text": {"small": "还太小了, 长到小孩才能出门哦", "asleep": "嘘, 它在睡觉呢", "sick": "它生病了, 先把病治好吧",
			"away": "它不在家"}.get(r, ""), "npc": "", "item": ""}
	if not id in outings:
		return {"text": "还没解锁: " + Outings.info(id).unlock, "npc": "", "item": ""}
	var now := clock()
	var local_hour := posmod(floori(float(now + tz) / 3600.0), 24)
	_unlock_outing("night", local_hour >= 19 and local_hour < 21)
	var fresh := now - int(out_at.get(id, -Outings.COOLDOWN)) >= Outings.COOLDOWN
	var out := {"text": "", "npc": "", "item": "", "ok": true, "souvenir": ""}
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
				out.text = "在公园碰到了「%s」, 一起疯玩了一会儿! 开心 +1" % Species.name_of(out.npc)
			else:
				out.text = "在公园碰到了「%s」, 互相打了个招呼" % Species.name_of(out.npc)
		"forest":
			if not fresh:
				out.text = "在森林里转了一圈, 这次空手回来啦"
			elif rng.randf() < 0.6 and int(items.get("apple", 0)) < Items.MAX_STACK:
				items["apple"] = int(items.get("apple", 0)) + 1
				out.item = "apple"
				out.text = "在森林里捡到一个红苹果!"
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
				out.text = "在湖边钓鱼…… 钓上来一小袋魔晶 %d!" % m
			else:
				out.text = "在湖边钓了半天, 鱼都不上钩……"
		"night":
			if fresh:
				var food: String = ["cake", "icecream"][rng.randi() % 2]
				if int(items.get(food, 0)) < Items.MAX_STACK:
					items[food] = int(items.get(food, 0)) + 1
				out.item = food
				out.text = "逛夜市啦! 小摊老板送了一个%s~" % Items.name_of(food)
			else:
				out.text = "逛了逛夜市, 好热闹呀"
	if fresh and id != "hotel":
		out_at[id] = now
		# 第六版: 偶尔带回那个地方的纪念品
		if rng.randf() < SOUVENIR_CHANCE:
			var s: String = Items.OUTING_SOUVENIR[id]
			add_souvenir(s)
			out.souvenir = s
			out.text += " 还带回了纪念品「%s」!" % Items.SOUVENIRS[s].name
	pet.soil()  # 出门玩脏了
	pet._settle()
	_take_events()
	last_result = "ok"
	return out


# ---------------------------------------------------------------- 第六版: 节日、纪念品

## 出门有收获的时候, 带回纪念品的机会 (我们定的)
const SOUVENIR_CHANCE := 0.3


## 今天是什么节 (本地日期; 不是节日回空)
func festival() -> String:
	_refresh_tz()
	return Festivals.today(clock(), tz)


## 过节: 这个节今年第一次打开游戏, 送礼物和一件纪念品
func _celebrate(t: int) -> void:
	var id := Festivals.today(t, tz)
	if id == "":
		return
	var year: int = Time.get_datetime_dict_from_unix_time(t + tz).year
	var key := "%s%d" % [id, year]
	if celebrated.has(key):
		return
	celebrated[key] = true
	var gift: Dictionary = Festivals.GIFTS[id]
	money += int(gift.get("money", 0))
	var food: Dictionary = gift.get("items", {})
	for f in food:
		items[f] = mini(Items.MAX_STACK, int(items.get(f, 0)) + int(food[f]))
	var text: String = gift.text
	if gift.get("toy", false):
		for toy in Items.of_kinds(["toy"]):
			if not toy in owned:
				owned.append(toy)
				text += ": %s" % Items.name_of(toy)
				break
	var s: String = Festivals.LIST[id].souvenir
	add_souvenir(s)
	messages.append({"text": "%s。还得到纪念品「%s」!" % [text, Items.SOUVENIRS[s].name], "rank": 5})


func add_souvenir(id: String) -> void:
	souvenirs[id] = int(souvenirs.get(id, 0)) + 1


# ---------------------------------------------------------------- 第五版: 信

func add_letter(title: String, body: String) -> void:
	letters.append({"title": title, "body": body, "at": clock(), "read": false})
	messages.append({"text": "收到一封信: %s (在「更多」→ 信箱)" % title, "rank": 4})


func unread() -> int:
	var n := 0
	for l in letters:
		if not l.read:
			n += 1
	return n


func _deliver_letters() -> void:
	var now := clock()
	for l in pending_letters.duplicate():
		if now >= int(l.at):
			pending_letters.erase(l)
			add_letter(l.title, l.body)


## 长成成年: 工作介绍所寄来介绍信, 写着现在能做哪些工作
func _job_letter() -> void:
	var can := []
	for id in School.JOB_ORDER:
		if School.can_take(pet, id):
			can.append(School.JOBS[id].name)
	add_letter("工作介绍所的信", "恭喜「%s」长大啦! 现在可以找工作了 (出门 → 上班)。\n照它现在的本事, 能做: %s。\n多上课、多训练, 能做的工作会越来越多哦。" %
		[pet.display_name(), "、".join(can)])


## 每上 5 节课, 学校寄来成绩单
func _report_letter() -> void:
	add_letter("学校寄来的成绩单", "「%s」一共上了 %d 节课啦。\n聪明 %d、时尚 %d、善良 %d。\n继续加油哦!" %
		[pet.display_name(), pet.classes, pet.smart, pet.style, pet.kind])


## 找工作: ok / cannot 本事不够 / no
func take_job(id: String) -> String:
	tick()
	return pet.take_job(id)


## 比一场 (第四版): 回 Training.fight 的结果 + foe_species 对手是谁 + prize 给的魔晶 + text 说什么; 不能比就只有 error 和 text
func compete(level: int) -> Dictionary:
	tick()
	var res := pet.compete(level)
	if res.has("error"):
		res.text = {"small": "长到少年才能比赛哦", "asleep": "嘘, 它在睡觉呢", "sick": "它生病了, 先把病治好吧", "hungry": "肚子饿或者不开心, 比不了",
			"tired": "刚比完, 让它歇会儿吧 (%s以后)" % sitter_text(maxi(60, pet.matched_at + Training.MATCH_COOLDOWN - pet.now)),
			"locked": "先赢了下面一级再来吧"}.get(res.error, "现在比不了")
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
		res.text = "%s赢了「%s」! 拿到魔晶 %d" % [info.name, Species.name_of(res.foe_species), res.prize]
		if res.rank_up:
			res.text += ", 还拿到了%s奖杯!" % Training.RANK_NAMES[level]
	else:
		res.text = "%s输给了「%s」…… 下次加油! 拿到魔晶 %d" % [info.name, Species.name_of(res.foe_species), res.prize]
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
	return {"version": 7, "pet": pet.to_dict() if pet != null else null, "dex": dex, "history": history,
		"offset": offset, "difficulty": difficulty, "money": money, "items": items, "owned": owned, "equip": equip,
		"toy_used": toy_used, "places": places, "outings": outings, "out_at": out_at, "stats": stats, "trophies": trophies,
		"letters": letters, "pending_letters": pending_letters, "celebrated": celebrated, "souvenirs": souvenirs,
		"parents": parents, "next_egg": next_egg}


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
	for l in d.get("letters", []):
		if l is Dictionary:
			g.letters.append({"title": str(l.get("title", "")), "body": str(l.get("body", "")), "at": int(l.get("at", 0)),
				"read": bool(l.get("read", false))})
	for l in d.get("pending_letters", []):
		if l is Dictionary:
			g.pending_letters.append({"at": int(l.get("at", 0)), "title": str(l.get("title", "")), "body": str(l.get("body", ""))})
	# 第六版加的
	for k in d.get("celebrated", {}):
		g.celebrated[str(k)] = true
	for k in d.get("souvenirs", {}):
		if Items.SOUVENIRS.has(k):
			g.souvenirs[str(k)] = int(d.souvenirs[k])
	# 第七版加的
	if d.get("parents") is Dictionary and not d.parents.is_empty():
		g.parents = d.parents
		g.parents.gen = int(g.parents.get("gen", 1))
	if d.get("next_egg") is Dictionary and not d.next_egg.is_empty():
		g.next_egg = d.next_egg
		g.next_egg.gen = int(g.next_egg.get("gen", 2))
	g._unlock_places()  # 以前版本养大过成年的, 直接打开新地方
	g.messages.clear()
	return g


func save() -> bool:
	return SaveGame.write(to_dict())


static func load_saved() -> Game:
	return from_dict(SaveGame.read())
