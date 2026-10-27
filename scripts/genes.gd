class_name Genes
extends RefCounted
## 结婚和下一代的遗传 (第七版, 用户 2026-10-26 定的: 长成哪一种还是看照顾, 颜色像爸妈, 样子也遗传一点)。
## 学拓麻歌子 m!x: 孩子身上的颜色是爸妈两个的中间 (每一代再随机偏一点), 头上会长出从爸妈之一遗传来的小特征 (小角、叶芽……)。
## 媒人介绍的对象也在这里挑。特征的种类、名字、颜色偏多少都是我们定的, 改这里就行。

const FEATURES := {"horn": "小角", "leaf": "叶芽", "fin": "小鳍", "feather": "羽毛", "tuft": "呆毛", "flower": "小花"}
## 没有遗传特征的魔物, 按住的地方算它的特征 (第一代的魔物也能把特征传下去)
const PLACE_FEATURE := {"grass": "leaf", "lake": "fin", "sky": "feather"}
const MUTATION := 0.04     # 每一代颜色随机偏多少 (色相, 一整圈是 1)
const OFFERS := 3          # 媒人一次介绍几位


## 一只魔物的样子: 种类、颜色 (-1 = 原来的)、头上的特征 (空 = 没有)
static func look_of(p: Pet) -> Dictionary:
	return {"species": p.species, "hue": p.hue, "feature": p.feature}


## 身上的颜色 (色相): 遗传来的, 没有的话就是这一种原来的颜色
static func hue_of(look: Dictionary) -> float:
	var h: float = look.get("hue", -1.0)
	return h if h >= 0 else Art.main_hue(look.species)


## 能传下去的特征: 遗传来的, 没有的话按住的地方 (草原叶芽、湖泊小鳍、天空岛羽毛, 别的小角)
static func feature_of(look: Dictionary) -> String:
	var f: String = look.get("feature", "")
	if f != "":
		return f
	return PLACE_FEATURE.get(Species.place_of(look.species), "horn")


## 下一代的蛋: 颜色是爸妈两个的中间 (只有一个就照它的), 再随机偏一点; 头上的特征从爸妈之一来
static func child(a: Dictionary, b: Dictionary, gen: int, rng: RandomNumberGenerator) -> Dictionary:
	var h := hue_of(a)
	var f := feature_of(a)
	if not b.is_empty():
		h = mix(h, hue_of(b))
		if rng.randf() < 0.5:
			f = feature_of(b)
	h = fposmod(h + rng.randf_range(-MUTATION, MUTATION), 1.0)
	return {"gen": gen + 1, "hue": h, "feature": f}


## 两个色相的中间 (色相是一个圈, 0.95 和 0.05 的中间是 0, 不是 0.5)
static func mix(x: float, y: float) -> float:
	var d := fposmod(y - x + 0.5, 1.0) - 0.5
	return fposmod(x + d / 2.0, 1.0)


## 媒人介绍的对象: 打开了的地方的成年魔物 (不是自己这一种, 也不是隐藏的), 颜色多半是原来的样子、偶尔很特别, 头上的特征随机
static func offers(places: Array, own: String, rng: RandomNumberGenerator) -> Array:
	var pool := []
	for place in places:
		for k in ["best", "good", "mid", "low", "bad1", "bad2"]:
			var sp: String = Species.PLACES[place][k]
			if sp != own and not sp in pool:
				pool.append(sp)
	var out := []
	while out.size() < mini(OFFERS, pool.size()):
		var sp: String = pool[rng.randi() % pool.size()]
		if out.any(func(o): return o.species == sp):
			continue
		var h := fposmod(Art.main_hue(sp) + rng.randf_range(-0.1, 0.1), 1.0)
		if rng.randf() < 0.25:
			h = rng.randf()  # 稀有的颜色
		var keys := FEATURES.keys()
		out.append({"species": sp, "hue": h, "feature": keys[rng.randi() % keys.size()]})
	return out
