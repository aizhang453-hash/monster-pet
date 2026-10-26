class_name MiniGames
extends RefCounted
## 有哪些小游戏、哪个阶段起能玩 (第二版, 用户 2026-10-25 选的: 每个阶段多一个, 宝宝还是只有猜左右)。
## 照拓麻歌子 V4.5 那样「每个成长阶段玩不同的小游戏」; 长大了以前的也还能玩。

const LIST := [
	{"id": "guess", "name": "猜左右", "from": "baby", "help": "猜它往哪边跳, 5 次猜中 3 次赢"},
	{"id": "catch", "name": "接果子", "from": "child", "help": "按住左右接果子, 15 个接住 10 个赢"},
	{"id": "jump", "name": "跳石头", "from": "teen", "help": "石头滚来时按「跳」, 12 块跳过 8 块赢"},
	{"id": "memory", "name": "记颜色", "from": "adult", "help": "记住颜色闪的顺序再按一遍, 过 3 关赢"},
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
	g.id = id
	if rng_seed != 0:
		g.rng.seed = rng_seed
	else:
		g.rng.randomize()
	g.start()
	return g
