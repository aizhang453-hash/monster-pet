class_name School
extends RefCounted
## 上学和工作 (第五版, 学拓麻歌子 V4「人生」; 用户 2026-10-25 定的)。
## 小孩和少年上学 (出门 → 学校): 数学课练「聪明」、美术课练「时尚」、品德课练「善良」, 每节课是 5 道选择题。
## 成年以后找工作、上班 (出门 → 上班): 工作要够一定的本事, 上班玩那份工作的小游戏, 赚魔晶。
## 课和工作的数字、题目、工作的种类都是我们定的 (V4 原版有 15 种工作), 改这里就行。

const SUBJECTS := {
	"smart": {"name": "数学课", "stat": "聪明"},
	"style": {"name": "美术课", "stat": "时尚"},
	"kind": {"name": "品德课", "stat": "善良"},
}
const QUESTIONS := 5
const CLASS_COOLDOWN := 60 * 60     # 上完一节课, 歇多久才能再上
const WORK_COOLDOWN := 4 * 3600     # 上完一次班, 歇多久才能再上
const GOOD_CLASS := 4               # 答对几题算「很认真」, 可以夸它

## 工作: 名字、要的本事 (聪明 时尚 善良 力气 速度 防御)、上班玩哪个小游戏、做完给多少魔晶 (输了给一半)
const JOBS := {
	"helper": {"name": "杂工", "need": {}, "game": "guess", "pay": 15},
	"courier": {"name": "快递员", "need": {"speed": 30}, "game": "catch", "pay": 25},
	"cook": {"name": "厨师", "need": {"kind": 20, "style": 10}, "game": "catch", "pay": 25},
	"guard": {"name": "保镖", "need": {"power": 40, "guard": 40}, "game": "jump", "pay": 35},
	"designer": {"name": "设计师", "need": {"style": 40}, "game": "quiz_style", "pay": 35},
	"teacher": {"name": "老师", "need": {"smart": 40, "kind": 20}, "game": "quiz_smart", "pay": 35},
	"doctor": {"name": "医生", "need": {"smart": 60, "kind": 40}, "game": "quiz_smart", "pay": 50},
}
const JOB_ORDER := ["helper", "courier", "cook", "guard", "designer", "teacher", "doctor"]
const STAT_NAMES := {"smart": "聪明", "style": "时尚", "kind": "善良", "power": "力气", "speed": "速度", "guard": "防御"}

## 美术课: 认东西 (屏幕上一个小图, 是什么?) 和配颜色
const THINGS := {"apple": "苹果", "cake": "蛋糕", "icecream": "冰淇淋", "feast": "大餐", "crown": "王冠", "strawhat": "草帽",
	"wizardhat": "魔法帽", "bowtie": "领结", "scarf": "围巾", "plant": "盆栽", "bed": "小床", "painting": "挂画",
	"window": "窗户", "blocks": "积木", "pinwheel": "风车", "game": "皮球"}
const COLOR_MIX := [["红 + 黄", "橙色"], ["蓝 + 黄", "绿色"], ["红 + 蓝", "紫色"], ["红 + 白", "粉色"], ["黑 + 白", "灰色"]]
const COLOR_WORDS := ["橙色", "绿色", "紫色", "粉色", "灰色", "棕色", "蓝色"]

## 品德课: 碰到这种事, 哪个做法最好 (第一个是对的, 出题时打乱)
const KIND := [
	["朋友摔倒了", ["扶它起来", "假装没看见", "在旁边笑"]],
	["捡到别人的东西", ["还给它", "自己留着", "丢掉"]],
	["有魔物一个人在哭", ["问它怎么了", "走开", "叫它别哭了"]],
	["吃饭前", ["先洗手", "直接吃", "抢别人的"]],
	["不小心撞到别人", ["说对不起", "跑掉", "怪别人"]],
	["朋友的画画得不好", ["说出好的地方", "笑它", "撕掉"]],
	["新来了一只魔物", ["请它一起玩", "不理它", "吓唬它"]],
	["排队买东西", ["好好排队", "插队", "推前面的"]],
	["借了朋友的玩具", ["玩完还给它", "弄坏了不说", "不还了"]],
	["看到有人在搬重东西", ["帮它一起搬", "看热闹", "挡在路上"]],
	["比赛输了", ["恭喜赢的那个", "生气发脾气", "说它作弊"]],
	["朋友生病了", ["去看看它", "不管它", "笑它"]],
]


## 出 5 道题: [{text 题目, icon 屏幕上的图 (可以空), options 三个选项, answer 对的是第几个}]
static func make_questions(kind: String, rng: RandomNumberGenerator, hard := false) -> Array:
	var out := []
	var used := {}
	while out.size() < QUESTIONS:
		var q: Dictionary
		match kind:
			"smart":
				q = _math(rng, hard)
			"style":
				q = _art(rng)
			"kind":
				q = _kind(rng)
		if used.has(q.text + str(q.get("icon", ""))):
			continue
		used[q.text + str(q.get("icon", ""))] = true
		out.append(q)
	return out


static func _math(rng: RandomNumberGenerator, hard: bool) -> Dictionary:
	var a := rng.randi_range(1, 9 if not hard else 12)
	var b := rng.randi_range(1, 9 if not hard else 12)
	var text: String
	var right: int
	match rng.randi() % (3 if hard else 2):
		0:
			text = "%d + %d = ?" % [a, b]
			right = a + b
		1:
			if a < b:
				var c := a
				a = b
				b = c
			text = "%d - %d = ?" % [a, b]
			right = a - b
		_:
			text = "%d × %d = ?" % [a, b]
			right = a * b
	var choices := [right]
	while choices.size() < 3:
		var wrong := right + rng.randi_range(-3, 3)
		if wrong >= 0 and not wrong in choices:
			choices.append(wrong)
	return _shuffle(text, "", choices.map(func(x): return str(x)), rng)


static func _art(rng: RandomNumberGenerator) -> Dictionary:
	if rng.randf() < 0.6:
		var keys := THINGS.keys()
		var icon: String = keys[rng.randi() % keys.size()]
		var choices := [THINGS[icon]]
		while choices.size() < 3:
			var other: String = THINGS[keys[rng.randi() % keys.size()]]
			if not other in choices:
				choices.append(other)
		return _shuffle("这是什么?", icon, choices, rng)
	var mix: Array = COLOR_MIX[rng.randi() % COLOR_MIX.size()]
	var choices2 := [mix[1]]
	while choices2.size() < 3:
		var w: String = COLOR_WORDS[rng.randi() % COLOR_WORDS.size()]
		if not w in choices2:
			choices2.append(w)
	return _shuffle("%s 是什么颜色?" % mix[0], "", choices2, rng)


static func _kind(rng: RandomNumberGenerator) -> Dictionary:
	var item: Array = KIND[rng.randi() % KIND.size()]
	return _shuffle(item[0] + ", 怎么做?", "", item[1].duplicate(), rng)


## choices 的第一个是对的; 打乱以后记下对的在第几个
static func _shuffle(text: String, icon: String, choices: Array, rng: RandomNumberGenerator) -> Dictionary:
	var right: String = choices[0]
	for i in range(choices.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var c: Variant = choices[i]
		choices[i] = choices[j]
		choices[j] = c
	return {"text": text, "icon": icon, "options": choices, "answer": choices.find(right)}


## 这只魔物能不能做这份工作 (本事够不够)
static func can_take(pet: Pet, job: String) -> bool:
	var need: Dictionary = JOBS[job].need
	for s in need:
		if pet.ability(s) < int(need[s]):
			return false
	return true


## 「力气 40、防御 40」这样的字
static func need_text(job: String) -> String:
	var need: Dictionary = JOBS[job].need
	if need.is_empty():
		return "谁都能做"
	var parts := []
	for s in need:
		parts.append("%s %d" % [STAT_NAMES[s], need[s]])
	return "、".join(parts)
