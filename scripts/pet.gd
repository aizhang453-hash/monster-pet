class_name Pet
extends RefCounted
## 一只魔物。规矩都在这里, 不管画面。照原版第一代拓麻歌子: 饿、开心、管教、体重、便便、生病、睡觉、照顾失误、长大、老死。
## 时间用 Unix 秒, 从外面传进来 (测试可以随便拨)。tz = 本地时间比世界时间快多少秒 (算几点睡觉用)。
## 用法: 先 advance(现在), 再做动作 (喂饭、关灯……)。advance 里发生的事放进 events, 画面拿去显示消息。
## advance 不是一分钟一分钟地算, 而是跳到下一件会发生的事 (心掉一颗、拉便便、该睡觉……), 离开好几天也算得很快。

var difficulty := Rules.EASY
var place := "grass"          # 住在哪 (第三版: grass 草原 / lake 湖泊 / sky 天空岛), 小孩长成少年时看这个
var species := "egg"
var stage := "egg"            # egg baby child teen adult; 结束了是 dead (死了) 或 gone (离开了)
var born_at := 0              # 蛋出现的时候
var hatched_at := 0           # 孵出来的时候 (从这时算岁数)
var stage_at := 0             # 这个阶段从什么时候开始
var now := 0                  # 已经算到哪一刻
var tz := 0

var hunger := 4               # 饿 (0–4 颗心, 0 = 很饿)
var happy := 4                # 开心 (0–4 颗心)
var tidy := 4                 # 干净 (0–4 格, 第六版: 洗澡)
var next_dirty := 0           # 下一次脏一格
var discipline := 0           # 管教 (0–4 格 = 0%–100%)
var weight := 0               # 体重 (克)

var poop := 0                 # 屏幕上有几坨便便
var poop_since := 0           # 有便便从什么时候开始 (0 = 没有)
var next_poop := 0
var next_hunger := 0
var next_happy := 0

var sick := false
var sick_since := 0
var medicine_left := 0        # 还要吃几次药 (1 或 2 次)
var sick_times := 0           # 这个阶段病了几次 (老了生的病不算)
var old_sick_age := -1        # 上一次「老了生病」是几岁的时候
var empty_since := 0          # 饿或不开心的心空了从什么时候开始 (算饿死)
var empty_mark := 0           # 同上, 但生过一次病就从头算 (算生病)

var asleep := false
var lights := true

var call := ""                # 正在叫你: hunger 饿 / happy 不开心 / lights 睡了没关灯 / discipline 闹脾气 / good 做了好事 (该夸了)
var call_at := 0
var recall_at := 0            # 失误以后, 这个时候之前不再叫
var next_tantrum := 0         # 下一次闹脾气

var mistakes := 0             # 这个阶段的照顾失误
var mistakes_life := 0        # 从出生到现在的照顾失误
var lifespan := 0             # 成年时定下: 活到几岁老死
var wants_leave := false      # 正在问你能不能放它走
var leave_ask_at := 0

var sit_since := 0            # 托人照看从什么时候开始 (0 = 没托)
var sit_used := 0             # sit_day 那天已经托了多少秒
var sit_day := -1             # 本地日期 (从 1970 年算第几天)
var hotel_until := 0          # 住旅馆约好什么时候来接 (0 = 没住旅馆; 第三版)

# 第四版: 训练和比赛 (本事长大了也留着)
var power := 0                # 练出来的力气 (不算天生的)
var speed := 0
var guard := 0
var rank := 0                 # 比赛赢到第几级了 (0 = 还没赢过, 5 = 冠军)
var trained_at := -Training.TRAIN_COOLDOWN
var matched_at := -Training.MATCH_COOLDOWN
var last_gain := 0            # 上一次训练涨了多少 (画面显示)

# 第五版: 上学和工作、夸它、摸摸它 (三样也是长大了留着)
var smart := 0                # 聪明 (数学课)
var style := 0                # 时尚 (美术课)
var kind := 0                 # 善良 (品德课; 夸它也加)
var job := ""                 # 做什么工作 (School.JOBS 的代号, 空 = 还没找)
var classes := 0              # 一共上了几节课
var class_at := -School.CLASS_COOLDOWN
var work_at := -School.WORK_COOLDOWN
var patted_at := -Rules.PAT_COOLDOWN
var next_good := 0            # 下一次做好事 (该夸它了)

# 第七版: 结婚和下一代 (学拓麻歌子 Connection 的媒人、m!x 的遗传、On / Meets 的爸妈家)
var gen := 1                  # 第几代
var hue := -1.0               # 遗传来的身上的颜色 (色相 0–1; -1 = 这一种原来的颜色)
var feature := ""             # 遗传来的头上的小特征 (Genes.FEATURES 的代号; 空 = 没有)
var match_at := 0             # 媒人什么时候来
var wants_match := false      # 媒人来了, 等你挑
var match_offers: Array = []  # 媒人介绍的对象 [{species, hue, feature}] (Game 填)
var partner := {}             # 结婚的对象
var sit_where := "sitter"     # 托给谁: sitter 照看的人 / parents 爸妈家
var parents_day := -1         # 哪天在爸妈家学过东西 (一天一次)

# 第八版: 自己出去散步、捣蛋精、性格
var walk_until := 0           # 自己出去散步, 什么时候回来 (0 = 在家)
var walk_from := 0            # 什么时候出去的
var next_walk := 0            # 下一次想出去散步
var pest_at := 0              # 捣蛋精什么时候来的 (0 = 没有)
var next_pest := 0            # 下一次捣蛋精来
var personality := ""         # 性格 (Personality.LIST 的代号; 空 = 还没定)

# 第九版: 混血和大奖、身上的遗传
var pair: Array = []          # 爸妈是哪两种 (第一代、老死留下的蛋是空的); 特别的一对生混血或大奖蛋 (Species.HYBRIDS / LINES)
var extra := ""               # 遗传来的身上的东西 (Genes.EXTRAS 的代号, 翅膀、尾巴; 空 = 没有; 少年起才长出来)
var morph_at := 0             # 小孩搬了家, 什么时候变成新地方的小孩 (0 = 不变)

# 第十版: 老年
var old := false              # 老了 (成年好几天还没结婚): 媒人不来了, 也不能再结婚, 不会再想出去闯荡
var old_at := 0               # 什么时候变老
var wants_retire := false     # 老了以后想去当媒人, 等你答应

var end_reason := ""          # neglect 没人照顾 / sick 病死 / old 老死 / left 离开了 / married 结婚了
var ended_at := 0

var rng := RandomNumberGenerator.new()
var events: Array = []        # 发生的事: {kind: grow / call / mistake / poop / sick / sleep / wake / leave_ask / end / sit_start / sit_end, ...}

const SAVE_KEYS := ["difficulty", "place", "species", "stage", "born_at", "hatched_at", "stage_at", "now", "tz",
	"hunger", "happy", "discipline", "weight", "poop", "poop_since", "next_poop", "next_hunger", "next_happy",
	"sick", "sick_since", "medicine_left", "sick_times", "old_sick_age", "empty_since", "empty_mark",
	"asleep", "lights", "call", "call_at", "recall_at", "next_tantrum", "mistakes", "mistakes_life",
	"lifespan", "wants_leave", "leave_ask_at", "end_reason", "ended_at", "sit_since", "sit_used", "sit_day", "hotel_until",
	"power", "speed", "guard", "rank", "trained_at", "matched_at",
	"smart", "style", "kind", "job", "classes", "class_at", "work_at", "patted_at", "next_good", "tidy", "next_dirty",
	"gen", "hue", "feature", "match_at", "wants_match", "match_offers", "partner", "sit_where", "parents_day",
	"walk_until", "walk_from", "next_walk", "pest_at", "next_pest", "personality", "pair", "extra", "morph_at", "old", "old_at", "wants_retire"]


static func create(t: int, diff: String, tz_offset := 0, rng_seed := 0) -> Pet:
	var p := Pet.new()
	p.difficulty = diff
	p.tz = tz_offset
	p.rng.seed = rng_seed if rng_seed != 0 else t
	p.born_at = t
	p.stage_at = t
	p.now = t
	return p


func is_over() -> bool:
	return stage == "dead" or stage == "gone"


func display_name() -> String:
	return Species.name_of(species)


## 几岁 (孵出来那天是 0 岁, 真实的一天长一岁, 照原版)
func age() -> int:
	if hatched_at == 0:
		return 0
	return floori(float((ended_at if is_over() else now) - hatched_at) / Rules.DAY)


func base_weight() -> int:
	return Species.DATA[species].weight


# ---------------------------------------------------------------- 时间往前走

func advance(t: int) -> void:
	var guard := 0
	while now < t and not is_over() and guard < 100000:
		guard += 1
		var nxt := mini(_next_due(), t)
		now = maxi(nxt, now + 1)
		_update()
	if now < t:
		now = t


## 下一件会发生的事在什么时候 (最多一小时后再看一次)
func _next_due() -> int:
	var c: Array[int] = []
	if Rules.STAGE_TIME.has(stage):
		c.append(stage_at + Rules.STAGE_TIME[stage])
	if stage == "adult":
		if not old and partner.is_empty():
			c.append(old_at)
		if not wants_leave:
			c.append(leave_ask_at)
		if not wants_match and partner.is_empty():
			c.append(match_at)
		c.append(hatched_at + lifespan * Rules.DAY)
	if hatched_at > 0:
		c.append(hatched_at + (age() + 1) * Rules.DAY)
	if not asleep and stage != "egg":
		c.append(next_hunger)
		c.append(next_happy)
		c.append(next_poop)
		c.append(next_dirty)
		if stage != "baby":
			c.append(next_tantrum)
			c.append(next_good)
			c.append(next_walk)
			c.append(next_pest)
	if pest_at > 0:
		c.append(pest_at + Rules.PEST_WINDOW[difficulty])
	if walking():
		c.append(walk_until)
	if _has_sleep():
		c.append(_next_sleep_change())
	if call != "":
		c.append(call_at + Rules.CALL_WINDOW[difficulty])
	c.append(recall_at)
	if poop_since > 0:
		c.append(poop_since + Rules.POOP_SICK[difficulty])
	if empty_mark > 0:
		c.append(empty_mark + Rules.EMPTY_SICK[difficulty])
	if empty_since > 0:
		c.append(empty_since + Rules.STARVE[difficulty])
	if sick:
		c.append(sick_since + Rules.SICK_DEATH[difficulty])
	if sitting():
		c.append(_sitter_end_time())
	if in_hotel():
		c.append(hotel_until)
	if morph_at > 0:
		c.append(morph_at)
	var best := now + Rules.HOUR
	for x in c:
		if x > now and x < best:
			best = x
	return best


func _update() -> void:
	_sleep_or_wake()
	_grow()
	if is_over():
		return
	_morph()
	_sleep_or_wake()
	if sitting() and now >= _sitter_end_time():
		end_sitter(true)
	if walking() and now >= walk_until:
		end_walk(true)
	if in_hotel():
		_hotel_update()
	if not away():  # 托人照看、住旅馆的时候, 有人管着, 下面这些都不会发生
		if not asleep and stage != "egg":
			_needs()
		_settle()
		_expire_call()
		_pest_update()
		_sickness()
		if is_over():
			return
		_deaths()
		if is_over():
			return
	# 第十版: 成年好几天还没结婚就老了 (学 Connection): 媒人不来了, 不能再结婚, 也不想出去闯荡了; 会问你能不能去当媒人
	if stage == "adult" and old_at == 0:
		old_at = maxi(stage_at + Rules.SENIOR_AFTER, now + Rules.DAY)  # 以前版本的存档没有这个, 多给一天
	if stage == "adult" and not old and partner.is_empty() and now >= old_at:
		old = true
		wants_match = false
		match_offers = []
		wants_leave = false
		wants_retire = true
		events.append({"kind": "old"})
	if stage == "adult" and not old and not wants_leave and now >= leave_ask_at:
		wants_leave = true
		events.append({"kind": "leave_ask"})
	# 第七版: 媒人上门 (醒着、在家的时候)
	if stage == "adult" and match_at == 0:
		match_at = now + Rules.HOUR  # 以前版本的存档没有这个
	if stage == "adult" and not old and partner.is_empty() and not wants_match and now >= match_at and not asleep and not away():
		wants_match = true
		events.append({"kind": "match_ask"})


func _grow() -> void:
	if not Rules.STAGE_TIME.has(stage) or now < stage_at + Rules.STAGE_TIME[stage]:
		return
	if asleep:
		return  # 睡着的时候不长, 醒了再长
	if stage == "egg":
		hatched_at = now
	_become(Species.next_form(self))


## 第九版: 搬家 (学乐园: 小孩搬到别的地方, 过一会儿变成那个地方的小孩; 少年以后搬家只换风景)
func set_place(p: String, t := -1) -> void:
	place = p
	morph_at = 0
	if stage == "child" and not Species.DATA[species].has("line") and species != Species.child_of(place):
		morph_at = (now if t < 0 else t) + Rules.MORPH_TIME


func _morph() -> void:
	if morph_at <= 0 or now < morph_at:
		return
	morph_at = 0
	var target := Species.child_of(place)
	if stage == "child" and not Species.DATA[species].has("line") and species != target:
		species = target  # 不算长大 (失误、体重这些都不变)
		events.append({"kind": "morph", "id": target})


func _become(id: String) -> void:
	var from := species
	morph_at = 0
	var was_egg := stage == "egg"
	species = id
	stage = Species.DATA[id].stage
	stage_at = now
	mistakes = 0
	sick_times = 0
	weight = base_weight()
	if was_egg:
		hunger = 0  # 刚孵出来是饿的、不开心的, 要马上照顾 (照原版)
		happy = 0
	var drop := Rules.heart_drop(stage, difficulty)
	next_hunger = now + drop
	next_happy = now + int(drop * 1.5)  # 跟饿错开一点
	next_poop = now + Rules.POOP_EVERY[stage]
	next_dirty = now + dirty_every()
	if stage != "baby":
		next_tantrum = now + rng.randi_range(Rules.TANTRUM_GAP[0], Rules.TANTRUM_GAP[1])
		next_walk = now + rng.randi_range(Rules.WALK_GAP[0], Rules.WALK_GAP[1])
		next_pest = now + rng.randi_range(Rules.PEST_GAP[0], Rules.PEST_GAP[1])
		next_good = now + rng.randi_range(Rules.GOOD_GAP[0], Rules.GOOD_GAP[1])
	if stage == "adult":
		var life: int = Species.DATA[id].life + rng.randi_range(Rules.LIFESPAN_RANDOM[0], Rules.LIFESPAN_RANDOM[1])
		lifespan = maxi(Rules.LIFESPAN_MIN, life)
		leave_ask_at = now + Rules.LEAVE_ASK_AFTER
		match_at = now + Rules.MATCH_AFTER
		old_at = now + Rules.SENIOR_AFTER
	events.append({"kind": "grow", "id": id, "from": from})


# ---------------------------------------------------------------- 睡觉

func _has_sleep() -> bool:
	return Species.DATA[species].has("bed")


func _local_minute(t: int) -> int:
	return posmod(floori(float(t + tz) / 60.0), 1440)


func is_sleep_time(t: int) -> bool:
	if not _has_sleep():
		return false
	var m := _local_minute(t)
	var bed: int = Species.DATA[species].bed
	var wake: int = Species.DATA[species].wake
	if bed > wake:
		return m >= bed or m < wake
	return m >= bed and m < wake


func _next_sleep_change() -> int:
	var m := _local_minute(now)
	var target: int = Species.DATA[species].wake if is_sleep_time(now) else Species.DATA[species].bed
	var delta := posmod(target - m, 1440)
	if delta == 0:
		delta = 1440
	return now - posmod(now + tz, 60) + delta * 60


func _sleep_or_wake() -> void:
	var should := is_sleep_time(now)
	if should and not asleep:
		asleep = true
		pest_at = 0  # 睡着了捣蛋精也走了
		if call != "":
			call = ""  # 睡着了就不叫了 (没算失误)
		events.append({"kind": "sleep"})
		if away():
			lights = false  # 照看的人、旅馆会关灯
		if lights:
			call = "lights"
			call_at = now
			events.append({"kind": "call", "what": "lights"})
	elif not should and asleep:
		asleep = false
		lights = true
		if call == "lights":
			call = ""
		var drop := Rules.heart_drop(stage, difficulty)
		next_hunger = now + drop
		next_happy = now + int(drop * 1.5)  # 跟饿错开一点
		next_poop = now + Rules.POOP_EVERY[stage]
		next_dirty = now + dirty_every()
		next_tantrum = maxi(next_tantrum, now + Rules.HOUR)
		events.append({"kind": "wake"})


# ---------------------------------------------------------------- 饿、开心、便便、闹脾气、叫你

func _needs() -> void:
	var drop := Rules.heart_drop(stage, difficulty)
	if now >= next_hunger:
		hunger = maxi(0, hunger - 1)
		next_hunger = now + drop
	if now >= next_happy:
		happy = maxi(0, happy - 1)
		next_happy = now + drop
	if now >= next_poop:
		if poop < Rules.MAX_POOP:
			poop += 1
			events.append({"kind": "poop"})
		if poop_since == 0:
			poop_since = now
		next_poop = now + Rules.POOP_EVERY[stage]
	if next_dirty == 0:
		next_dirty = now + dirty_every()  # 以前版本的存档没有这个
	if now >= next_dirty:
		if tidy > 0:
			tidy -= 1
		else:
			happy = maxi(0, happy - 1)  # 脏兮兮的, 不舒服
		next_dirty = now + dirty_every()
	if stage != "baby" and now >= next_tantrum:
		if call == "" or call == "good":  # 闹脾气比「做了好事等你夸」要紧
			call = "discipline"
			call_at = now
			events.append({"kind": "call", "what": "discipline"})
		next_tantrum = now + rng.randi_range(Rules.TANTRUM_GAP[0], Rules.TANTRUM_GAP[1])
	if stage != "baby" and next_good == 0:
		next_good = now + rng.randi_range(Rules.GOOD_GAP[0], Rules.GOOD_GAP[1])  # 以前版本的存档没有这个
	# 第八版: 自己出去散步 (心情好、不饿、没生病、没叫你、家里没便便, 回来之前不会到睡觉的时候)。
	# 一开始没管便便, 量难度发现原版严格多了不少病死: 它在外面的时候便便还在计时, 主人又没法打扫

	if stage != "baby" and next_walk == 0:
		next_walk = now + rng.randi_range(Rules.WALK_GAP[0], Rules.WALK_GAP[1])  # 以前版本的存档没有这个
	if stage != "baby" and now >= next_walk:
		var length := rng.randi_range(Rules.WALK_TIME[0], Rules.WALK_TIME[1])
		if happy >= 3 and hunger >= 2 and not sick and call == "" and poop == 0 and not is_sleep_time(now + length):
			walk_until = now + length
			walk_from = now
			pest_at = 0
			events.append({"kind": "walk_start"})
			next_walk = now + rng.randi_range(Rules.WALK_GAP[0], Rules.WALK_GAP[1])
			return
		next_walk = now + Rules.HOUR  # 现在不想出去, 过一会儿再看
	# 第八版: 捣蛋精
	if stage != "baby" and next_pest == 0:
		next_pest = now + rng.randi_range(Rules.PEST_GAP[0], Rules.PEST_GAP[1])
	if stage != "baby" and now >= next_pest:
		if pest_at == 0:
			pest_at = now
			events.append({"kind": "pest"})
		next_pest = now + rng.randi_range(Rules.PEST_GAP[0], Rules.PEST_GAP[1])
	if stage != "baby" and now >= next_good:
		if call == "":
			call = "good"  # 做了一件好事 (第五版: 该夸它了)
			call_at = now
			events.append({"kind": "call", "what": "good"})
		next_good = now + rng.randi_range(Rules.GOOD_GAP[0], Rules.GOOD_GAP[1])


## 心空没空、叫你的事办好没有、要不要叫你 (做完动作也要跑一次)
func _settle() -> void:
	if hunger == 0 or happy == 0:
		if empty_since == 0:
			empty_since = now
			empty_mark = now
	else:
		empty_since = 0
		empty_mark = 0
	if call == "hunger" and hunger > 0:
		call = ""
	elif call == "happy" and happy > 0:
		call = ""
	elif call == "lights" and (not asleep or not lights):
		call = ""
	if not asleep and stage != "egg" and not is_over() and (call == "" or call == "discipline" or call == "good") and now >= recall_at:
		var want := "hunger" if hunger == 0 else ("happy" if happy == 0 else "")
		if want != "":
			call = want
			call_at = now
			events.append({"kind": "call", "what": want})


## 捣蛋精来了太久没赶走: 把它吓一跳 (开心 -1; 不算失误)
func _pest_update() -> void:
	if pest_at > 0 and now >= pest_at + Rules.PEST_WINDOW[difficulty]:
		pest_at = 0
		happy = maxi(0, happy - 1)
		events.append({"kind": "pest_hit"})
		_settle()


func _expire_call() -> void:
	if call == "" or now < call_at + Rules.CALL_WINDOW[difficulty]:
		return
	if call != "discipline" and call != "good":  # 闹脾气没管、做好事没夸, 不算失误
		mistakes += 1
		mistakes_life += 1
		recall_at = now + Rules.RECALL_GAP[difficulty]
		events.append({"kind": "mistake", "what": call})
	call = ""


# ---------------------------------------------------------------- 生病、死、老

func _sickness() -> void:
	if sick or stage == "egg" or walking():
		return  # 第十版修: 散步的时候时间像停着, 不会在外面生病 (以前同一刻出门又老了生病, 在外面没法吃药)
	if poop_since > 0 and now >= poop_since + Rules.POOP_SICK[difficulty]:
		poop_since = now
		_get_sick(false)
	elif empty_mark > 0 and now >= empty_mark + Rules.EMPTY_SICK[difficulty]:
		empty_mark = now
		_get_sick(false)
	elif stage == "adult" and age() >= Rules.OLD_SICK_FROM and old_sick_age != age() \
			and (age() - Rules.OLD_SICK_FROM) % Rules.OLD_SICK_EVERY == 0:
		old_sick_age = age()
		_get_sick(true)


func _get_sick(old: bool) -> void:
	sick = true
	sick_since = now
	medicine_left = rng.randi_range(1, 2)
	events.append({"kind": "sick"})
	if not old:
		sick_times += 1
		if difficulty == Rules.STRICT and sick_times >= Rules.SICK_TIMES_DEATH:
			_end("sick")


func _deaths() -> void:
	if sick and now >= sick_since + Rules.SICK_DEATH[difficulty]:
		_end("sick")
	elif empty_since > 0 and now >= empty_since + Rules.STARVE[difficulty]:
		_end("neglect")
	elif difficulty == Rules.STRICT and stage == "adult" and mistakes >= Rules.ADULT_MISTAKES_DEATH:
		_end("neglect")
	elif stage == "adult" and age() >= lifespan:
		_end("old")


func _end(reason: String) -> void:
	stage = "dead" if reason in ["neglect", "sick", "old"] else "gone"  # 离开了、结婚了是 gone
	end_reason = reason
	ended_at = now
	call = ""
	asleep = false
	wants_leave = false
	wants_retire = false
	wants_match = false
	if sitting():
		sit_used += now - sit_since
		sit_since = 0
	hotel_until = 0
	walk_until = 0
	pest_at = 0
	events.append({"kind": "end", "reason": reason})


# ---------------------------------------------------------------- 玩家的动作 (先 advance 到现在再做)

func can_act() -> bool:
	return not is_over() and stage != "egg" and not away()


func feed_meal() -> String:
	if not can_act():
		return "no"
	if asleep:
		return "asleep"
	if hunger >= 4:
		return "full"
	hunger += 1
	weight += Rules.MEAL_WEIGHT
	_settle()
	# 照 On / Meets: 成年以后觉得免费的白饭没味道, 会一脸嫌弃 (但照样吃, 不影响开心和健康)
	return "bland" if stage == "adult" else "ok"


## 吃商店买的东西 (food 是 Items.DATA 里的一条)
func eat(food: Dictionary) -> String:
	if not can_act():
		return "no"
	if asleep:
		return "asleep"
	if food.hunger > 0 and food.happy == 0 and hunger >= 4:
		return "full"
	hunger = mini(4, hunger + food.hunger)
	happy = mini(4, happy + food.happy)
	weight += food.weight
	_settle()
	return "ok"


## 陪它玩玩具: 开心 +1, 不会胖 (玩具多久能玩一次由 Game 管)
func play_toy() -> String:
	if can_play() != "ok":
		return can_play()
	happy = mini(4, happy + 1)
	_settle()
	return "ok"


func feed_snack() -> String:
	if not can_act():
		return "no"
	if asleep:
		return "asleep"
	happy = mini(4, happy + 1)
	if personality != "spoiled":  # 爱撒娇的吃零食不会胖
		weight += Rules.SNACK_WEIGHT
	_settle()
	return "ok"


func toggle_lights() -> String:
	if is_over() or away():
		return "no"
	lights = not lights
	_settle()
	return "on" if lights else "off"


func can_play() -> String:
	if not can_act():
		return "no"
	if asleep:
		return "asleep"
	if sick:
		return "sick"
	return "ok"


## 小游戏玩完了: 赢了没有 (每种小游戏怎么算赢在 MiniGames 里)
func finish_game(won: bool) -> String:
	if can_play() != "ok":
		return can_play()
	weight = maxi(base_weight(), weight - Rules.GAME_WEIGHT)
	if won:
		happy = mini(4, happy + 1)
	_settle()
	return "won" if won else "lost"


func give_medicine() -> String:
	if not can_act():
		return "no"
	if asleep:
		return "asleep"
	if not sick:
		return "healthy"
	medicine_left -= 1
	if medicine_left > 0:
		return "more"
	sick = false
	sick_since = 0
	return "cured"


## 打扫: 有便便先清便便 (ok); 没有便便、身上脏了就洗澡 (bath, 睡着了不洗); 都干净就 nothing
func clean() -> String:
	if not can_act():
		return "no"
	if poop > 0:
		poop = 0
		poop_since = 0
		return "ok"
	if tidy >= 4:
		return "nothing"
	if asleep:
		return "asleep"
	tidy = 4
	next_dirty = now + dirty_every()
	return "bath"


## 弄脏一格 (练完、比完、上完班、出门)
func soil() -> void:
	tidy = maxi(0, tidy - 1)


func scold() -> String:
	if not can_act():
		return "no"
	if asleep:
		return "asleep"
	if call == "discipline":
		discipline = mini(4, discipline + 1)
		call = ""
		return "good"
	happy = maxi(0, happy - 1)  # 没闹脾气被骂, 不开心 (我们定的)
	_settle()
	return "sad"


## 它说想离开: 放它走 (true) 还是留下来 (false)
## 第十版: 老了以后想去当媒人 (学 Connection: 没结婚的老了自己变成媒人)。答应就出发 (留下一颗蛋, 以后来你家做媒); 不答应就留下来陪你到老
func answer_retire(yes: bool) -> void:
	if not wants_retire:
		return
	wants_retire = false
	if yes:
		_end("matchmaker")


func answer_leave(let_go: bool) -> void:
	if not wants_leave:
		return
	if let_go:
		_end("left")
	else:
		wants_leave = false
		leave_ask_at = now + Rules.LEAVE_ASK_AGAIN


## 媒人介绍的对象挑哪一个 (i 是第几个; -1 = 现在还不想结婚, 媒人过一天再来)。挑了就结婚: 生下一颗蛋, 两口子搬去爸妈家
func answer_match(i: int) -> void:
	if not wants_match:
		return
	wants_match = false
	if i < 0 or i >= match_offers.size():
		match_at = now + Rules.MATCH_AGAIN
		match_offers = []
		return
	_wed(match_offers[i])


## 第九版: 跟这一位结婚 (约会广场约会成功的、朋友); 只有在家、醒着的成年才行。回结婚了没有
func marry(look: Dictionary) -> bool:
	if stage != "adult" or old or asleep or away() or not partner.is_empty():
		return false
	_wed(look)
	return true


func _wed(look: Dictionary) -> void:
	partner = look.duplicate()
	partner.erase("guest")
	wants_match = false
	match_offers = []
	_end("married")


# ---------------------------------------------------------------- 托人照看

func sitting() -> bool:
	return sit_since > 0


func _local_day(t: int) -> int:
	return floori(float(t + tz) / Rules.DAY)


## 这次照看到什么时候结束 (今天的额度用完就送回来)
func _sitter_end_time() -> int:
	return sit_since + Rules.SITTER_PER_DAY - sit_used


## 今天还能托多久 (秒)
func sitter_left() -> int:
	if sitting():
		return maxi(0, _sitter_end_time() - now)
	if sit_day != _local_day(now):
		return Rules.SITTER_PER_DAY
	return maxi(0, Rules.SITTER_PER_DAY - sit_used)


## where: sitter 托给照看的人 / parents 送去爸妈家 (第七版; 一样的照顾, 共用每天的时间)
func start_sitter(where := "sitter") -> String:
	if is_over() or stage == "egg":
		return "no"
	if away():
		return "already"
	if sit_day != _local_day(now):
		sit_day = _local_day(now)
		sit_used = 0
	if sit_used >= Rules.SITTER_PER_DAY:
		return "used_up"
	sit_since = now
	sit_where = where
	pest_at = 0
	# 照看的人接手: 喂饱、哄开心、打扫、治病; 不叫你
	hunger = 4
	happy = 4
	poop = 0
	poop_since = 0
	tidy = 4
	sick = false
	sick_since = 0
	medicine_left = 0
	call = ""
	empty_since = 0
	empty_mark = 0
	if asleep:
		lights = false
	events.append({"kind": "sit_start"})
	return "ok"


## 接回来 (auto = 今天的时间用完, 照看的人送回来)。回 ok, 或者 taught (在爸妈家待够了, 爸妈教了它: 聪明、时尚、善良各 +1)
func end_sitter(auto := false) -> String:
	if not sitting():
		return "no"
	var stayed := now - sit_since
	sit_used += stayed
	sit_since = 0
	var taught := false
	if sit_where == "parents" and stayed >= Rules.PARENTS_TEACH and parents_day != _local_day(now):
		parents_day = _local_day(now)
		for s in ["smart", "style", "kind"]:
			set(s, mini(Training.MAX_STAT, int(get(s)) + 1))
		taught = true
	hunger = 4  # 送回来之前喂饱了
	happy = 4
	var drop := Rules.heart_drop(stage, difficulty)
	next_hunger = now + drop
	next_happy = now + int(drop * 1.5)
	next_poop = now + Rules.POOP_EVERY[stage]
	next_dirty = now + dirty_every()
	next_tantrum = maxi(next_tantrum, now + Rules.HOUR)
	recall_at = now
	events.append({"kind": "sit_end", "auto": auto, "where": sit_where, "taught": taught})
	_settle()
	return "taught" if taught else "ok"


# ---------------------------------------------------------------- 旅馆 (第三版, 照拓麻歌子 On / Meets)
# 花魔晶 (Game 收钱) 寄放几个小时: 不叫你、不算失误、不拉便便、不生病, 但旅馆不管饭 —
# 饿了或不开心就被送回家; 约好的时间没去接, 它自己回来, 很生气 (开心 -2)。

func in_hotel() -> bool:
	return hotel_until > 0


## 托人照看、住旅馆、自己出去散步, 不在家
func away() -> bool:
	return sitting() or in_hotel() or walking()


# ---------------------------------------------------------------- 第八版: 自己出去散步、捣蛋精、性格

func walking() -> bool:
	return walk_until > 0


## 散步回来 (done = 逛完了自己回来; false = 你叫它回来的, 没逛完)。
## 散步的时候它的时间像停着一样: 什么时候饿、拉便便、变脏……都往后挪出去的那么久。
## (一开始是回来一分钟就拉便便, 快睡觉时回来的话便便放一整晚会生病, 量难度时查出来的)
## 闹脾气、做好事不挪 (到时间了回来就闹), 不然管教的机会变少, 长成好的那几种的变少 (也是量出来的)
func end_walk(done := false) -> String:
	if not walking():
		return "no"
	walk_until = 0
	var gone := maxi(0, now - walk_from)
	for k in ["next_hunger", "next_happy", "next_poop", "next_dirty", "next_pest"]:
		set(k, int(get(k)) + gone)
	recall_at = now
	events.append({"kind": "walk_end", "done": done})
	_settle()
	return "ok"


## 赶走捣蛋精
func shoo() -> String:
	if pest_at == 0:
		return "none"
	pest_at = 0
	return "ok"


## 多久脏一格 (悠闲的脏得慢一半)
func dirty_every() -> int:
	return Rules.DIRTY_EVERY[difficulty] * (2 if personality == "mellow" else 1)


## 选性格 (长成小孩以后才能选, 选了就不改)
func set_personality(id: String) -> String:
	if not Personality.LIST.has(id) or personality != "" or stage in ["egg", "baby"] or is_over():
		return "no"
	personality = id
	return "ok"


func start_hotel(until: int) -> String:
	if is_over() or stage == "egg":
		return "no"
	if away():
		return "already"
	if until <= now:
		return "no"
	if hunger == 0 or happy == 0:
		return "hungry"  # 旅馆不管饭: 先喂饱、哄开心再去 (On / Meets 也是这样)
	hotel_until = until
	pest_at = 0
	call = ""
	poop = 0  # 旅馆帮忙打扫, 还给它洗澡
	poop_since = 0
	tidy = 4
	if asleep:
		lights = false
	events.append({"kind": "hotel_start"})
	return "ok"


## 接回来 / 被送回来: reason = pickup 你去接 / hungry 饿了或不开心被送回来 / late 约好的时间没去接
func end_hotel(reason := "pickup") -> String:
	if not in_hotel():
		return "no"
	hotel_until = 0
	if reason == "late":
		happy = maxi(0, happy - 2)
	next_poop = now + Rules.POOP_EVERY[stage]
	next_dirty = now + dirty_every()
	next_tantrum = maxi(next_tantrum, now + Rules.HOUR)
	next_hunger = maxi(next_hunger, now + 60)
	next_happy = maxi(next_happy, now + 60)
	recall_at = now
	events.append({"kind": "hotel_end", "reason": reason})
	_settle()
	return "ok"


## 住旅馆时: 心照样掉 (旅馆不管饭), 空了就送回家; 到时间没接就自己回来
func _hotel_update() -> void:
	if not asleep:
		var drop := Rules.heart_drop(stage, difficulty)
		if now >= next_hunger:
			hunger = maxi(0, hunger - 1)
			next_hunger = now + drop
		if now >= next_happy:
			happy = maxi(0, happy - 1)
			next_happy = now + drop
	if hunger == 0 or happy == 0:
		end_hotel("hungry")
	elif now >= hotel_until:
		end_hotel("late")


# ---------------------------------------------------------------- 训练和比赛 (第四版)

## 本事 = 练出来的 + 天生的 (成年后看种类)
func stat(s: String) -> int:
	return int(get(s)) + Training.bonus(species, s)


func stats() -> Dictionary:
	return {"power": stat("power"), "speed": stat("speed"), "guard": stat("guard")}


## 能不能训练: ok / no / small 太小 (宝宝) / asleep / sick / hungry 饿着或不开心 / tired 刚练过
func can_train() -> String:
	if not can_act():
		return "no"
	if stage == "baby":
		return "small"
	if asleep:
		return "asleep"
	if sick:
		return "sick"
	if hunger == 0 or happy == 0:
		return "hungry"
	if now - trained_at < Training.TRAIN_COOLDOWN:
		return "tired"
	return "ok"


## 练一样本事: 涨 3–5 (管教满了多 1); 练完饿一点、累一点、脏一点 (饿 -1, 开心 -1, 体重 -1, 干净 -1)
func train(s: String) -> String:
	var r := can_train()
	if r != "ok":
		return r
	last_gain = rng.randi_range(Training.GAIN[0], Training.GAIN[1]) + (Training.DISCIPLINE_BONUS if discipline >= 4 else 0)
	set(s, mini(Training.MAX_STAT, int(get(s)) + last_gain))
	_tire()
	trained_at = now
	return "ok"


func _tire() -> void:
	hunger = maxi(0, hunger - 1)
	happy = maxi(0, happy - 1)
	weight = maxi(base_weight(), weight - 1)
	soil()
	_settle()


## 能不能比赛 (match 是 GDScript 的关键字, 所以叫 compete): 跟训练一样, 再加上 少年起才能比 (small)、刚比过 (tired)
func can_match() -> String:
	if not can_act():
		return "no"
	if stage == "baby" or stage == "child":
		return "small"
	if asleep:
		return "asleep"
	if sick:
		return "sick"
	if hunger == 0 or happy == 0:
		return "hungry"
	if now - matched_at < Training.MATCH_COOLDOWN:
		return "tired"
	return "ok"


## 比一场: level = 第几级 (只能比赢过的和下一级)。回 Training.fight 的结果, 再加 rank_up (这场赢了升级没有)
func compete(level: int) -> Dictionary:
	var r := can_match()
	if r != "ok":
		return {"error": r}
	if level > rank or level >= Training.RANKS.size():
		return {"error": "locked"}
	var foe := Training.make_foe(level, rng)
	var res := Training.fight(stats(), foe, rng)
	res.foe = foe
	res.rank_up = res.won and level == rank
	if res.rank_up:
		rank += 1
	_tire()
	matched_at = now
	return res


# ---------------------------------------------------------------- 上学、工作、夸它、摸摸它 (第五版)

## 本事: 聪明 时尚 善良 (上学练的) 或者 力气 速度 防御 (训练练的, 带天生的)
func ability(s: String) -> int:
	if s in ["smart", "style", "kind"]:
		return int(get(s))
	return stat(s)


## 能不能上学: 小孩和少年才上学 (照 V4)
func can_study() -> String:
	if not can_act():
		return "no"
	if stage == "baby":
		return "small"
	if stage == "adult":
		return "grown"
	if asleep:
		return "asleep"
	if sick:
		return "sick"
	if now - class_at < School.CLASS_COOLDOWN:
		return "tired"
	return "ok"


## 上完一节课: 答对几题就涨几 (管教满了多 1); 很认真的话它做了好事, 可以夸它
func study(subject: String, correct: int) -> String:
	var r := can_study()
	if r != "ok":
		return r
	last_gain = correct + (Training.DISCIPLINE_BONUS if discipline >= 4 and correct > 0 else 0)
	if personality == "diligent" and correct > 0:
		last_gain += 1  # 认真的上课多涨 1
	set(subject, mini(Training.MAX_STAT, int(get(subject)) + last_gain))
	classes += 1
	class_at = now
	if correct >= School.GOOD_CLASS and call == "":
		call = "good"
		call_at = now
		events.append({"kind": "call", "what": "good"})
	return "ok"


func take_job(id: String) -> String:
	if stage != "adult" or is_over():
		return "no"
	if not School.can_take(self, id):
		return "cannot"
	job = id
	return "ok"


## 能不能上班: 成年、有工作、歇够了, 还有不饿不累
func can_work() -> String:
	if not can_act():
		return "no"
	if stage != "adult":
		return "small"
	if job == "":
		return "nojob"
	if asleep:
		return "asleep"
	if sick:
		return "sick"
	if hunger == 0 or happy == 0:
		return "hungry"
	if now - work_at < School.WORK_COOLDOWN:
		return "tired"
	return "ok"


## 上完一次班 (小游戏玩完了): 回给多少魔晶 (赢了全给, 输了一半; -1 = 上不了班)
func work_done(won: bool) -> int:
	if can_work() != "ok":
		return -1
	var pay: int = School.JOBS[job].pay
	work_at = now
	_tire()
	return pay if won else int(pay / 2.0)


## 夸它: 它做了好事 (呼叫灯亮着) 的时候夸, 开心 +1、善良 +2; 别的时候夸, 它不明白 (学天使和《怪物农场》)
func praise() -> String:
	if not can_act():
		return "no"
	if asleep:
		return "asleep"
	if call != "good":
		return "puzzled"
	call = ""
	happy = mini(4, happy + 1)
	kind = mini(Training.MAX_STAT, kind + 2)
	_settle()
	return "good"


## 摸摸它 (学 Smart 手表的触摸屏): 隔两小时摸一次开心 +1, 摸得太勤它只是蹭蹭你
func pat() -> String:
	if not can_act():
		return "no"
	if asleep:
		return "asleep"
	if now - patted_at < Rules.PAT_COOLDOWN / (2 if personality == "shy" else 1):
		return "again"
	patted_at = now
	happy = mini(4, happy + 1)
	_settle()
	return "ok"


# ---------------------------------------------------------------- 存档

func to_dict() -> Dictionary:
	var d := {}
	for k in SAVE_KEYS:
		d[k] = get(k)
	d["rng_seed"] = str(rng.seed)
	d["rng_state"] = str(rng.state)
	return d


static func from_dict(d: Dictionary) -> Pet:
	var p := Pet.new()
	for k in SAVE_KEYS:
		if not d.has(k):
			continue
		var v: Variant = d[k]
		match typeof(p.get(k)):
			TYPE_INT:
				v = int(v)
			TYPE_BOOL:
				v = bool(v)
			TYPE_STRING:
				v = str(v)
		p.set(k, v)
	if d.has("rng_seed"):
		p.rng.seed = str(d.rng_seed).to_int()
		p.rng.state = str(d.rng_state).to_int()
	return p
