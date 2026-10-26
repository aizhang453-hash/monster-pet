class_name MiniGames
extends RefCounted
## 有哪些小游戏、哪个阶段起能玩 (第二版, 用户 2026-10-25 选的: 每个阶段多一个, 宝宝还是只有猜左右)。
## 照拓麻歌子 V4.5 那样「每个成长阶段玩不同的小游戏」; 长大了以前的也还能玩。

## 第六版又加了九个 (用户 2026-10-25 说「全做了」), 都是拓麻歌子里有的; 每个阶段 3–4 个
const LIST := [
	{"id": "guess", "name": "猜左右", "from": "baby", "help": "猜它往哪边跳, 5 次猜中 3 次赢"},
	{"id": "number", "name": "猜数字", "from": "baby", "help": "猜下一个数比它大还是小, 5 次猜中 3 次赢"},
	{"id": "rope", "name": "跳绳", "from": "baby", "help": "绳子甩到脚下的时候按「跳」, 跳过 10 下赢"},
	{"id": "climb", "name": "爬高", "from": "baby", "help": "左手右手轮流按往上爬, 12 秒爬到顶赢"},
	{"id": "catch", "name": "接果子", "from": "child", "help": "按住左右接果子, 15 个接住 10 个赢"},
	{"id": "tug", "name": "拔河", "from": "child", "help": "一直按「拉!」, 把绳子拉到你这边赢"},
	{"id": "mimic", "name": "模仿", "from": "child", "help": "你的魔物换到跟对面一样的姿势时按, 5 次对 3 次赢"},
	{"id": "jump", "name": "跳石头", "from": "teen", "help": "石头滚来时按「跳」, 12 块跳过 8 块赢"},
	{"id": "flag", "name": "举旗", "from": "teen", "help": "听口令举红旗、白旗, 「都别动」就别按, 8 次对 6 次赢"},
	{"id": "sprint", "name": "赛跑", "from": "teen", "help": "一直按「跑!」, 比对手先到终点赢"},
	{"id": "memory", "name": "记颜色", "from": "adult", "help": "记住颜色闪的顺序再按一遍, 过 3 关赢"},
	{"id": "dance", "name": "跳舞", "from": "adult", "help": "箭头掉到线上时按一样的箭头, 16 个踩中 10 个赢"},
	{"id": "burger", "name": "做汉堡", "from": "adult", "help": "照客人点的从下往上按, 5 份做好 3 份赢"},
]
const STAGES := ["baby", "child", "teen", "adult"]


## 这个阶段能玩哪些 (代号)
static func unlocked(stage: String) -> Array:
	var out := []
	var at := STAGES.find(stage)
	for g in LIST:
		if at >= 0 and STAGES.find(g.from) <= at:
			out.append(g.id)
	return out


static func info(id: String) -> Dictionary:
	for g in LIST:
		if g.id == id:
			return g
	return {}


## id 还可以是 quiz_smart / quiz_style / quiz_kind (第五版: 上课和几份工作的答题); hard = 出难一点的题
static func make(id: String, rng_seed := 0, hard := false) -> MiniGame:
	var g: MiniGame
	if id.begins_with("quiz_"):
		var q := QuizGame.new()
		q.kind = id.trim_prefix("quiz_")
		q.hard = hard
		g = q
	match id:
		"guess":
			g = GuessGame.new()
		"catch":
			g = CatchGame.new()
		"jump":
			g = JumpGame.new()
		"memory":
			g = MemoryGame.new()
		"number":
			g = NumberGame.new()
		"rope":
			g = RopeGame.new()
		"climb":
			g = ClimbGame.new()
		"tug":
			g = TugGame.new()
		"mimic":
			g = MimicGame.new()
		"flag":
			g = FlagGame.new()
		"sprint":
			g = SprintGame.new()
		"dance":
			g = DanceGame.new()
		"burger":
			g = BurgerGame.new()
	g.id = id
	if rng_seed != 0:
		g.rng.seed = rng_seed
	else:
		g.rng.randomize()
	g.start()
	return g
