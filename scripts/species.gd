class_name Species
extends RefCounted
## 魔物的种类和怎么长大。照原版第一代的长法: 蛋 → 宝宝 → 小孩 → 少年 (两种) → 成年 (六种, 外加一种隐藏的)。
## 长成哪一种看照顾失误几次、管教得怎么样 (照原版的思路; 具体分界是我们定的)。
## 名字都是暂定的 (2026-10-25 Claude 起的), 用户想改随时改。

## bed / wake: 几点睡、几点醒 (从 0 点算起的分钟); life: 平均活到几岁; weight: 基本体重 (克)
## hat: 帽子的下沿放在图的第几行; neck: 领结、围巾的上沿放在第几行 (嘴巴下面; 第二版的装扮用)
const DATA := {
	"egg": {"name": "魔物蛋", "stage": "egg", "weight": 0},
	"tuanzi": {"hat": 6, "neck": 12, "name": "小团子", "stage": "baby", "weight": 5},
	"jianjiao": {"hat": 5, "neck": 12, "name": "小尖角", "stage": "child", "weight": 10, "bed": 20 * 60, "wake": 9 * 60},
	# 第九版: 每个地方的小孩长得不一样 (学乐园, 用户 2026-10-26 选的); 小尖角是草原的
	"shuizhu": {"hat": 2, "neck": 11, "name": "小水珠", "stage": "child", "weight": 10, "bed": 20 * 60, "wake": 9 * 60},
	"rongqiu": {"hat": 5, "neck": 11, "name": "小绒球", "stage": "child", "weight": 10, "bed": 20 * 60, "wake": 9 * 60},
	"yishou": {"hat": 4, "neck": 10, "name": "小翼兽", "stage": "teen", "weight": 20, "bed": 21 * 60, "wake": 9 * 60},
	"nigui": {"hat": 4, "neck": 11, "name": "小泥怪", "stage": "teen", "weight": 20, "bed": 21 * 60, "wake": 9 * 60},
	"huolong": {"hat": 4, "neck": 11, "name": "火焰龙", "stage": "adult", "weight": 35, "bed": 21 * 60, "wake": 8 * 60, "life": 14},
	"shuiling": {"hat": 5, "neck": 11, "name": "水灵", "stage": "adult", "weight": 25, "bed": 22 * 60, "wake": 9 * 60, "life": 13},
	"linlu": {"hat": 4, "neck": 10, "name": "林鹿", "stage": "adult", "weight": 30, "bed": 20 * 60, "wake": 8 * 60, "life": 12},
	"shixiang": {"hat": 2, "neck": 7, "name": "石头魔像", "stage": "adult", "weight": 50, "bed": 22 * 60, "wake": 9 * 60, "life": 16},
	"mogu": {"hat": 2, "neck": 13, "name": "毒蘑菇", "stage": "adult", "weight": 20, "bed": 21 * 60, "wake": 9 * 60, "life": 10},
	"xiaomo": {"hat": 4, "neck": 10, "name": "小恶魔", "stage": "adult", "weight": 25, "bed": 23 * 60, "wake": 10 * 60, "life": 9},
	"xingguang": {"hat": 4, "neck": 11, "name": "星光龙", "stage": "adult", "weight": 30, "bed": 21 * 60, "wake": 8 * 60, "life": 18, "secret": true},
	# ---- 第三版: 湖泊 ----
	"paopao": {"hat": 5, "neck": 11, "name": "小泡泡鱼", "stage": "teen", "weight": 20, "bed": 21 * 60, "wake": 9 * 60},
	"shuimu": {"hat": 4, "neck": 9, "name": "小水母", "stage": "teen", "weight": 15, "bed": 21 * 60, "wake": 9 * 60},
	"yuejing": {"hat": 3, "neck": 11, "name": "月光鲸", "stage": "adult", "weight": 60, "bed": 22 * 60, "wake": 8 * 60, "life": 18, "secret": true},
	"hailong": {"hat": 4, "neck": 11, "name": "海龙", "stage": "adult", "weight": 35, "bed": 21 * 60, "wake": 8 * 60, "life": 14},
	"zhenzhu": {"hat": 2, "neck": 13, "name": "珍珠贝", "stage": "adult", "weight": 25, "bed": 21 * 60, "wake": 9 * 60, "life": 13},
	"qingwa": {"hat": 5, "neck": 10, "name": "大青蛙", "stage": "adult", "weight": 30, "bed": 22 * 60, "wake": 9 * 60, "life": 12},
	"shixie": {"hat": 7, "neck": 11, "name": "石蟹", "stage": "adult", "weight": 45, "bed": 21 * 60, "wake": 8 * 60, "life": 16},
	"dumu": {"hat": 3, "neck": 9, "name": "毒水母", "stage": "adult", "weight": 20, "bed": 22 * 60, "wake": 9 * 60, "life": 10},
	"shayu": {"hat": 4, "neck": 12, "name": "鲨鱼怪", "stage": "adult", "weight": 40, "bed": 23 * 60, "wake": 10 * 60, "life": 9},
	# ---- 第三版: 天空岛 ----
	"yunduo": {"hat": 4, "neck": 10, "name": "小云朵", "stage": "teen", "weight": 15, "bed": 21 * 60, "wake": 9 * 60},
	"leiqiu": {"hat": 4, "neck": 10, "name": "小雷球", "stage": "teen", "weight": 20, "bed": 21 * 60, "wake": 9 * 60},
	"fenghuang": {"hat": 3, "neck": 10, "name": "彩虹凤凰", "stage": "adult", "weight": 30, "bed": 21 * 60, "wake": 7 * 60, "life": 18, "secret": true},
	"fengying": {"hat": 2, "neck": 9, "name": "风之鹰", "stage": "adult", "weight": 30, "bed": 21 * 60, "wake": 7 * 60, "life": 14},
	"yunyang": {"hat": 3, "neck": 10, "name": "云羊", "stage": "adult", "weight": 30, "bed": 20 * 60, "wake": 8 * 60, "life": 13},
	"maotouying": {"hat": 4, "neck": 10, "name": "猫头鹰", "stage": "adult", "weight": 25, "bed": 23 * 60, "wake": 10 * 60, "life": 12},
	"shixianggui": {"hat": 4, "neck": 8, "name": "石像鬼", "stage": "adult", "weight": 50, "bed": 22 * 60, "wake": 9 * 60, "life": 16},
	"bianfu": {"hat": 4, "neck": 10, "name": "蝙蝠怪", "stage": "adult", "weight": 20, "bed": 23 * 60, "wake": 10 * 60, "life": 10},
	"wuya": {"hat": 2, "neck": 9, "name": "乌鸦魔", "stage": "adult", "weight": 25, "bed": 23 * 60, "wake": 10 * 60, "life": 9},
	# ---- 第九版: 混血 (特定的一对生的孩子, 照顾得好才长成; 见下面 HYBRIDS) ----
	"zhengqilong": {"hat": 4, "neck": 11, "name": "蒸汽龙", "stage": "adult", "weight": 35, "bed": 21 * 60, "wake": 8 * 60, "life": 15, "hybrid": true},
	"moguwa": {"hat": 1, "neck": 10, "name": "蘑菇蛙", "stage": "adult", "weight": 25, "bed": 22 * 60, "wake": 9 * 60, "life": 13, "hybrid": true},
	"yuyunjing": {"hat": 3, "neck": 10, "name": "雨云精", "stage": "adult", "weight": 15, "bed": 21 * 60, "wake": 8 * 60, "life": 14, "hybrid": true},
	"feilu": {"hat": 4, "neck": 10, "name": "飞鹿", "stage": "adult", "weight": 30, "bed": 20 * 60, "wake": 7 * 60, "life": 15, "hybrid": true},
	"feisha": {"hat": 4, "neck": 11, "name": "飞鲨", "stage": "adult", "weight": 35, "bed": 23 * 60, "wake": 10 * 60, "life": 12, "hybrid": true},
	"yanjiagui": {"hat": 2, "neck": 5, "name": "岩甲龟", "stage": "adult", "weight": 55, "bed": 21 * 60, "wake": 9 * 60, "life": 18, "hybrid": true},
	# ---- 第九版: 大奖, 云龙一族 (宝宝和小孩是同一个样子; 见下面 LINES) ----
	"yunlong_baby": {"hat": 6, "neck": 12, "name": "小云龙", "stage": "baby", "weight": 6, "line": "yunlong"},
	"yunlong_child": {"hat": 6, "neck": 12, "name": "小云龙", "stage": "child", "weight": 10, "bed": 20 * 60, "wake": 9 * 60, "line": "yunlong"},
	"yunlong_teen": {"hat": 4, "neck": 11, "name": "云龙", "stage": "teen", "weight": 20, "bed": 21 * 60, "wake": 9 * 60, "line": "yunlong"},
	"yunlong_good": {"hat": 3, "neck": 9, "name": "苍穹龙", "stage": "adult", "weight": 35, "bed": 21 * 60, "wake": 7 * 60, "life": 18, "line": "yunlong", "grand": true},
	"yunlong_mid": {"hat": 3, "neck": 9, "name": "雾龙", "stage": "adult", "weight": 30, "bed": 22 * 60, "wake": 9 * 60, "life": 14, "line": "yunlong"},
	"yunlong_bad": {"hat": 2, "neck": 9, "name": "雷暴龙", "stage": "adult", "weight": 40, "bed": 23 * 60, "wake": 10 * 60, "life": 11, "line": "yunlong"},
	# ---- 第九版: 大奖, 独角兽一族 ----
	"dujiao_baby": {"hat": 6, "neck": 12, "name": "小独角", "stage": "baby", "weight": 5, "line": "dujiao"},
	"dujiao_child": {"hat": 6, "neck": 12, "name": "小独角", "stage": "child", "weight": 10, "bed": 20 * 60, "wake": 9 * 60, "line": "dujiao"},
	"dujiao_teen": {"hat": 3, "neck": 10, "name": "独角驹", "stage": "teen", "weight": 20, "bed": 21 * 60, "wake": 9 * 60, "line": "dujiao"},
	"dujiao_good": {"hat": 3, "neck": 9, "name": "彩虹独角兽", "stage": "adult", "weight": 30, "bed": 21 * 60, "wake": 7 * 60, "life": 18, "line": "dujiao", "grand": true},
	"dujiao_mid": {"hat": 3, "neck": 9, "name": "银角兽", "stage": "adult", "weight": 30, "bed": 22 * 60, "wake": 9 * 60, "life": 14, "line": "dujiao"},
	"dujiao_bad": {"hat": 3, "neck": 9, "name": "黑角兽", "stage": "adult", "weight": 35, "bed": 23 * 60, "wake": 10 * 60, "life": 11, "line": "dujiao"},
}

## 第九版: 混血 (用户 2026-10-26 定的「藏起来的混血种」): 爸妈是下面这一对 (谁是你养的、谁是对象都行),
## 孩子又照顾得好 (走好的少年那条路, 少年时失误不超过 1 次), 长大就变成这一种; 照顾不好还是长成普通的。
## 配哪几对、名字都是 Claude 暂定的, 用户想改随时改。
const HYBRIDS := {
	"zhengqilong": ["huolong", "hailong"],
	"moguwa": ["mogu", "qingwa"],
	"yuyunjing": ["shuiling", "yunyang"],
	"feilu": ["linlu", "fengying"],
	"feisha": ["shayu", "bianfu"],
	"yanjiagui": ["shixiang", "shixie"],
}

## 第九版: 大奖 (用户 2026-10-26 定的): 混血魔物再跟特定的一位结婚, 生下一颗不一样的蛋, 走自己的一条路:
## 宝宝 (小孩时也是这个样子) → 少年 → 成年 3 种 (照顾得好 / 普通 / 差)。也是 Claude 暂定的。
const LINES := {
	"yunlong": {"name": "云龙一族", "pair": ["zhengqilong", "fengying"], "baby": "yunlong_baby", "child": "yunlong_child",
		"teen": "yunlong_teen", "good": "yunlong_good", "mid": "yunlong_mid", "bad": "yunlong_bad"},
	"dujiao": {"name": "独角兽一族", "pair": ["feilu", "zhenzhu"], "baby": "dujiao_baby", "child": "dujiao_child",
		"teen": "dujiao_teen", "good": "dujiao_good", "mid": "dujiao_mid", "bad": "dujiao_bad"},
}
const LINE_ORDER := ["yunlong", "dujiao"]

## 住的地方 (第三版, 学拓麻歌子 Paradise 的「陆地 / 水里 / 天上」, 用户 2026-10-25 选了「每个地方一整套」)。
## 小孩长成少年的时候住在哪, 就长成那个地方的魔物; 宝宝和小孩大家一样。名字都是暂定的。
## 每一套: 好的少年、调皮的少年, 成年 6 种 (best good mid low 好的少年长; low bad1 bad2 调皮的少年长), 外加一种隐藏的 (只有原版严格)
## 第九版: 还有那个地方的小孩 (child); 宝宝长成小孩时住在哪就是哪里的小孩, 小孩搬家一小时后变成新地方的小孩
const PLACES := {
	"grass": {"name": "草原", "child": "jianjiao", "teen_good": "yishou", "teen_bad": "nigui", "secret": "xingguang", "best": "huolong",
		"good": "shuiling", "mid": "linlu", "low": "shixiang", "bad1": "mogu", "bad2": "xiaomo"},
	"lake": {"name": "湖泊", "child": "shuizhu", "teen_good": "paopao", "teen_bad": "shuimu", "secret": "yuejing", "best": "hailong",
		"good": "zhenzhu", "mid": "qingwa", "low": "shixie", "bad1": "dumu", "bad2": "shayu"},
	"sky": {"name": "天空岛", "child": "rongqiu", "teen_good": "yunduo", "teen_bad": "leiqiu", "secret": "fenghuang", "best": "fengying",
		"good": "yunyang", "mid": "maotouying", "low": "shixianggui", "bad1": "bianfu", "bad2": "wuya"},
}
const PLACE_ORDER := ["grass", "lake", "sky"]
## 每个地方的小屏幕: 底色和地面的颜色
const PLACE_LOOK := {"grass": ["dfe9d3", "8cc06a"], "lake": ["d6ecf2", "6fb6d8"], "sky": ["e9e6f8", "ffffff"]}

## 图鉴里的顺序 (蛋不算): 宝宝、小孩, 然后一个地方一套
const ORDER := ["tuanzi", "jianjiao", "shuizhu", "rongqiu",
	"yishou", "nigui", "huolong", "shuiling", "linlu", "shixiang", "mogu", "xiaomo", "xingguang",
	"paopao", "shuimu", "hailong", "zhenzhu", "qingwa", "shixie", "dumu", "shayu", "yuejing",
	"yunduo", "leiqiu", "fengying", "yunyang", "maotouying", "shixianggui", "bianfu", "wuya", "fenghuang",
	"zhengqilong", "moguwa", "yuyunjing", "feilu", "feisha", "yanjiagui",
	"yunlong_baby", "yunlong_teen", "yunlong_good", "yunlong_mid", "yunlong_bad",
	"dujiao_baby", "dujiao_teen", "dujiao_good", "dujiao_mid", "dujiao_bad"]

const STAGE_NAMES := {"egg": "蛋", "baby": "宝宝", "child": "小孩", "teen": "少年", "adult": "成年"}


static func name_of(id: String) -> String:
	return DATA[id].name


## 这个种类是哪个地方的 (宝宝、小孩、蛋不属于哪里, 回空)
static func place_of(id: String) -> String:
	for place in PLACES:
		if id in PLACES[place].values():
			return place
	return ""


## 第九版: 两种是不是同一对 (谁先谁后都行)
static func same_pair(a: Array, b: Array) -> bool:
	return a.size() == 2 and b.size() == 2 and ((a[0] == b[0] and a[1] == b[1]) or (a[0] == b[1] and a[1] == b[0]))


## 第九版: 爸妈这一对会生出哪种混血 (没有就回空)
static func hybrid_of(pair: Array) -> String:
	for id in HYBRIDS:
		if same_pair(HYBRIDS[id], pair):
			return id
	return ""


## 第九版: 爸妈这一对会生出哪一族的大奖蛋 (没有就回空)
static func line_of(pair: Array) -> String:
	for id in LINES:
		if same_pair(LINES[id].pair, pair):
			return id
	return ""


## 第九版: 跟这一种结婚能生出特别孩子的对象 (混血或大奖)
static func special_partners(id: String) -> Array:
	var out := []
	for h in HYBRIDS:
		if id in HYBRIDS[h]:
			out.append(HYBRIDS[h][1] if HYBRIDS[h][0] == id else HYBRIDS[h][0])
	for l in LINES:
		var pair: Array = LINES[l].pair
		if id in pair:
			out.append(pair[1] if pair[0] == id else pair[0])
	return out


## 第九版: 这个地方的小孩
static func child_of(place: String) -> String:
	return PLACES.get(place, PLACES.grass).child


## 到时候该长成哪一种
static func next_form(p: Pet) -> String:
	var line: String = DATA[p.species].get("line", "")
	if line != "":
		# 第九版: 大奖那一族自己的路 (成年看少年时失误几次)
		var l: Dictionary = LINES[line]
		match DATA[p.species].stage:
			"baby":
				return l.child
			"child":
				return l.teen
			"teen":
				if p.mistakes <= 1:
					return l.good
				return l.mid if p.mistakes <= 4 else l.bad
		return p.species
	match p.species:
		"egg":
			var from_pair := line_of(p.pair)
			return LINES[from_pair].baby if from_pair != "" else "tuanzi"
		"tuanzi":
			return child_of(p.place)  # 第九版: 住在哪就是哪里的小孩
	if DATA[p.species].stage == "child":
		# 小孩阶段失误不多 (≤2) 长成好的少年, 多了长成调皮的少年 (原版也是 3 次失误为界); 长成哪个地方的看现在住在哪
		var here: Dictionary = PLACES.get(p.place, PLACES.grass)
		return here.teen_good if p.mistakes <= 2 else here.teen_bad
	var group: Dictionary = PLACES.get(place_of(p.species), {})
	if group.is_empty() or Species.DATA[p.species].stage != "teen":
		return p.species
	if p.species == group.teen_good:
		var mix := hybrid_of(p.pair)
		if mix != "" and p.mistakes <= 1:
			return mix  # 第九版: 爸妈是特别的一对, 又照顾得好 (本来会长成最好的那几种), 长成混血 (比隐藏的还优先)
		if p.difficulty == Rules.STRICT and p.mistakes_life == 0 and p.discipline >= 4:
			return group.secret  # 隐藏的: 原版严格才有 (用户 2026-10-25 定的), 从出生到现在一次失误都没有, 管教满了
		if p.mistakes <= 1 and p.discipline >= 4:
			return group.best
		if p.mistakes <= 1:
			return group.good
		if p.mistakes <= 4:
			return group.mid
		return group.low
	if p.discipline >= 3:
		return group.low
	if p.mistakes <= 3:
		return group.bad1
	return group.bad2
