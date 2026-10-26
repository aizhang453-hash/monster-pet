class_name Training
extends RefCounted
## 训练和比赛 (第四版, 学《怪物农场》和万代的数码宝贝机器; 用户 2026-10-25 选的)。
## 三种本事: 力气 power、速度 speed、防御 guard。训练练本事, 比赛自动对打 (像数码宝贝机器, 不用自己操作)。
## 本事长大了也留着; 成年以后每种魔物有自己擅长的 (加一点)。比赛一共五个级别, 赢了升一级、拿奖杯和魔晶。
## 数字都是我们定的, 改这里就行。

const STATS := {"power": "力气", "speed": "速度", "guard": "防御"}
const DRILLS := {"power": ["举重", "dumbbell"], "speed": ["跑步", "shoe"], "guard": ["挡石头", "shield"]}
const GAIN := [3, 5]             # 练一次涨多少 (随机)
const DISCIPLINE_BONUS := 1      # 管教满了练得更好 (学《怪物农场》: 听话的练得好)
const MAX_STAT := 999
const TRAIN_COOLDOWN := 30 * 60  # 练一次要歇多久
const MATCH_COOLDOWN := 3 * 3600 # 比一场要歇多久

## 每个级别: 名字、对手的本事大概多少、赢了给多少魔晶
const RANKS := [
	{"name": "新手赛", "foe": 10, "prize": 20},
	{"name": "铜牌赛", "foe": 25, "prize": 40},
	{"name": "银牌赛", "foe": 45, "prize": 70},
	{"name": "金牌赛", "foe": 70, "prize": 110},
	{"name": "冠军赛", "foe": 100, "prize": 200},
]
const RANK_NAMES := ["新手", "铜牌", "银牌", "金牌", "冠军"]

## 成年魔物擅长什么 (加 15, 别的加 5); 隐藏的三样都加 15; 少年三样都加 5
const STRONG := {
	"huolong": "power", "shuiling": "speed", "linlu": "speed", "shixiang": "guard", "mogu": "guard", "xiaomo": "power",
	"hailong": "power", "zhenzhu": "guard", "qingwa": "speed", "shixie": "guard", "dumu": "speed", "shayu": "power",
	"fengying": "speed", "yunyang": "guard", "maotouying": "power", "shixianggui": "guard", "bianfu": "speed", "wuya": "power",
}


## 这种魔物天生多几点
static func bonus(species: String, stat: String) -> int:
	var d: Dictionary = Species.DATA[species]
	if d.stage == "teen":
		return 5
	if d.stage != "adult":
		return 0
	if d.get("secret", false):
		return 15
	return 15 if STRONG.get(species, "") == stat else 5


## 一场比赛: 两边自动对打, 回 {won 赢没赢, log 每一下: [{who 谁打的 (me / foe), dmg 打掉多少, dodge 躲开没有, hp_me, hp_foe}]}
static func fight(me: Dictionary, foe: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var hp := {"me": 30 + me.guard, "foe": 30 + foe.guard}
	var full := hp.duplicate()
	var stats := {"me": me, "foe": foe}
	var moves := []
	var turn := "me" if me.speed >= foe.speed else "foe"
	for i in 20:
		var other := "foe" if turn == "me" else "me"
		var atk: Dictionary = stats[turn]
		var def: Dictionary = stats[other]
		var dodge_chance := clampf((def.speed - atk.speed) * 0.01 + 0.1, 0.05, 0.4)
		var entry := {"who": turn, "dmg": 0, "dodge": false}
		if rng.randf() < dodge_chance:
			entry.dodge = true
		else:
			var dmg := maxi(2, roundi(atk.power * 0.5 - def.guard * 0.25) + rng.randi_range(0, 3))
			hp[other] = maxi(0, hp[other] - dmg)
			entry.dmg = dmg
		entry.hp_me = hp.me
		entry.hp_foe = hp.foe
		moves.append(entry)
		if hp[other] == 0:
			break
		turn = other
	var won: bool
	if hp.foe == 0:
		won = true
	elif hp.me == 0:
		won = false
	else:
		won = float(hp.me) / full.me >= float(hp.foe) / full.foe  # 打满 20 下还没分出来, 剩得多的赢
	return {"won": won, "log": moves, "full_me": full.me, "full_foe": full.foe}


## 做一个对手: 本事在这个级别上下浮动
static func make_foe(rank: int, rng: RandomNumberGenerator) -> Dictionary:
	var base: int = RANKS[rank].foe
	var foe := {}
	for s in STATS:
		foe[s] = maxi(1, roundi(base * rng.randf_range(0.8, 1.2)))
	return foe
