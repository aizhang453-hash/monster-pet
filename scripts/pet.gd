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

var call := ""                # 正在叫你: hunger 饿 / happy 不开心 / lights 睡了没关灯 / discipline 闹脾气
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

var end_reason := ""          # neglect 没人照顾 / sick 病死 / old 老死 / left 离开了
var ended_at := 0

var rng := RandomNumberGenerator.new()
var events: Array = []        # 发生的事: {kind: grow / call / mistake / poop / sick / sleep / wake / leave_ask / end / sit_start / sit_end, ...}

const SAVE_KEYS := ["difficulty", "place", "species", "stage", "born_at", "hatched_at", "stage_at", "now", "tz",
	"hunger", "happy", "discipline", "weight", "poop", "poop_since", "next_poop", "next_hunger", "next_happy",
	"sick", "sick_since", "medicine_left", "sick_times", "old_sick_age", "empty_since", "empty_mark",
	"asleep", "lights", "call", "call_at", "recall_at", "next_tantrum", "mistakes", "mistakes_life",
	"lifespan", "wants_leave", "leave_ask_at", "end_reason", "ended_at", "sit_since", "sit_used", "sit_day", "hotel_until"]


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
		if not wants_leave:
			c.append(leave_ask_at)
		c.append(hatched_at + lifespan * Rules.DAY)
	if hatched_at > 0:
		c.append(hatched_at + (age() + 1) * Rules.DAY)
	if not asleep and stage != "egg":
		c.append(next_hunger)
		c.append(next_happy)
		c.append(next_poop)
		if stage != "baby":
			c.append(next_tantrum)
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
	_sleep_or_wake()
	if sitting() and now >= _sitter_end_time():
		end_sitter(true)
	if in_hotel():
		_hotel_update()
	if not away():  # 托人照看、住旅馆的时候, 有人管着, 下面这些都不会发生
		if not asleep and stage != "egg":
			_needs()
		_settle()
		_expire_call()
		_sickness()
		if is_over():
			return
		_deaths()
		if is_over():
			return
	if stage == "adult" and not wants_leave and now >= leave_ask_at:
		wants_leave = true
		events.append({"kind": "leave_ask"})


func _grow() -> void:
	if not Rules.STAGE_TIME.has(stage) or now < stage_at + Rules.STAGE_TIME[stage]:
		return
	if asleep:
		return  # 睡着的时候不长, 醒了再长
	if stage == "egg":
		hatched_at = now
	_become(Species.next_form(self))


func _become(id: String) -> void:
	var from := species
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
	if stage != "baby":
		next_tantrum = now + rng.randi_range(Rules.TANTRUM_GAP[0], Rules.TANTRUM_GAP[1])
	if stage == "adult":
		var life: int = Species.DATA[id].life + rng.randi_range(Rules.LIFESPAN_RANDOM[0], Rules.LIFESPAN_RANDOM[1])
		lifespan = maxi(Rules.LIFESPAN_MIN, life)
		leave_ask_at = now + Rules.LEAVE_ASK_AFTER
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
	if stage != "baby" and now >= next_tantrum:
		if call == "":
			call = "discipline"
			call_at = now
			events.append({"kind": "call", "what": "discipline"})
		next_tantrum = now + rng.randi_range(Rules.TANTRUM_GAP[0], Rules.TANTRUM_GAP[1])


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
	if not asleep and stage != "egg" and not is_over() and (call == "" or call == "discipline") and now >= recall_at:
		var want := "hunger" if hunger == 0 else ("happy" if happy == 0 else "")
		if want != "":
			call = want
			call_at = now
			events.append({"kind": "call", "what": want})


func _expire_call() -> void:
	if call == "" or now < call_at + Rules.CALL_WINDOW[difficulty]:
		return
	if call != "discipline":  # 闹脾气没管, 不算失误 (只是管教没涨)
		mistakes += 1
		mistakes_life += 1
		recall_at = now + Rules.RECALL_GAP[difficulty]
		events.append({"kind": "mistake", "what": call})
	call = ""


# ---------------------------------------------------------------- 生病、死、老

func _sickness() -> void:
	if sick or stage == "egg":
		return
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
	stage = "gone" if reason == "left" else "dead"
	end_reason = reason
	ended_at = now
	call = ""
	asleep = false
	wants_leave = false
	if sitting():
		sit_used += now - sit_since
		sit_since = 0
	hotel_until = 0
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


func clean() -> String:
	if not can_act():
		return "no"
	if poop == 0:
		return "nothing"
	poop = 0
	poop_since = 0
	return "ok"


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
func answer_leave(let_go: bool) -> void:
	if not wants_leave:
		return
	if let_go:
		_end("left")
	else:
		wants_leave = false
		leave_ask_at = now + Rules.LEAVE_ASK_AGAIN


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


func start_sitter() -> String:
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
	# 照看的人接手: 喂饱、哄开心、打扫、治病; 不叫你
	hunger = 4
	happy = 4
	poop = 0
	poop_since = 0
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


## 接回来 (auto = 今天的时间用完, 照看的人送回来)
func end_sitter(auto := false) -> String:
	if not sitting():
		return "no"
	sit_used += now - sit_since
	sit_since = 0
	hunger = 4  # 送回来之前喂饱了
	happy = 4
	var drop := Rules.heart_drop(stage, difficulty)
	next_hunger = now + drop
	next_happy = now + int(drop * 1.5)
	next_poop = now + Rules.POOP_EVERY[stage]
	next_tantrum = maxi(next_tantrum, now + Rules.HOUR)
	recall_at = now
	events.append({"kind": "sit_end", "auto": auto})
	_settle()
	return "ok"


# ---------------------------------------------------------------- 旅馆 (第三版, 照拓麻歌子 On / Meets)
# 花魔晶 (Game 收钱) 寄放几个小时: 不叫你、不算失误、不拉便便、不生病, 但旅馆不管饭 —
# 饿了或不开心就被送回家; 约好的时间没去接, 它自己回来, 很生气 (开心 -2)。

func in_hotel() -> bool:
	return hotel_until > 0


## 托人照看或住旅馆, 不在家
func away() -> bool:
	return sitting() or in_hotel()


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
	call = ""
	poop = 0  # 旅馆帮忙打扫
	poop_since = 0
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
