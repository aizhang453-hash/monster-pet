class_name Genes
extends RefCounted
## 结婚和下一代的遗传 (第七版, 用户 2026-10-26 定的: 长成哪一种还是看照顾, 颜色像爸妈, 样子也遗传一点)。
## 学拓麻歌子 m!x: 孩子身上的颜色是爸妈两个的中间 (每一代再随机偏一点), 头上会长出从爸妈之一遗传来的小特征 (小角、叶芽……)。
## 媒人介绍的对象也在这里挑。特征的种类、名字、颜色偏多少都是我们定的, 改这里就行。

const FEATURES := {"horn": "小角", "leaf": "叶芽", "fin": "小鳍", "feather": "羽毛", "tuft": "呆毛", "flower": "小花"}
## 没有遗传特征的魔物, 按住的地方算它的特征 (第一代的魔物也能把特征传下去)
const PLACE_FEATURE := {"grass": "leaf", "lake": "fin", "sky": "feather"}
## 第九版: 身上的东西 (用户 2026-10-26 说再多遗传一样, 比如尾巴或翅膀); 学 m!x, 少年起才长出来。第一代没有, 媒人介绍的对象有的有
const EXTRAS := {"wing": "小翅膀", "batwing": "蝠翼", "tail": "卷尾巴", "startail": "星星尾巴"}
const EXTRA_CHANCE := 0.6  # 媒人介绍的对象身上有东西的机会
const MUTATION := 0.04     # 每一代颜色随机偏多少 (色相, 一整圈是 1)
const OFFERS := 3          # 媒人一次介绍几位
const SPECIAL_CHANCE := 1.0 / 3  # 第九版: 媒人带来「特别有缘」的对象的机会 (有这样的对象、它住的地方也打开了的话)


## 一只魔物的样子: 种类、颜色 (-1 = 原来的)、头上的特征 (空 = 没有)、身上的东西 (第九版)
static func look_of(p: Pet) -> Dictionary:
	return {"species": p.species, "hue": p.hue, "feature": p.feature, "extra": p.extra}


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


## 下一代的蛋: 颜色是爸妈两个的中间 (只有一个就照它的), 再随机偏一点; 头上的特征、身上的东西各自从爸妈之一来;
## 第九版: 记下爸妈是哪两种 (pair), 特别的一对会生混血或大奖蛋
static func child(a: Dictionary, b: Dictionary, gen: int, rng: RandomNumberGenerator) -> Dictionary:
	var h := hue_of(a)
	var f := feature_of(a)
	var e := str(a.get("extra", ""))
	var pair := []
	if not b.is_empty():
		h = mix(h, hue_of(b))
		if rng.randf() < 0.5:
			f = feature_of(b)
		if rng.randf() < 0.5:
			e = str(b.get("extra", ""))
		pair = [a.species, b.species]
	h = fposmod(h + rng.randf_range(-MUTATION, MUTATION), 1.0)
	return {"gen": gen + 1, "hue": h, "feature": f, "extra": e, "pair": pair}


## 第九版: 算命的 / 配对模拟器 (学 m!x 的算命和 My Lab 的配对模拟): 这两位的孩子大概什么样。
## 回 {hue 颜色 (不算随机偏的那一点), features 头上可能长的, extras 身上可能有的 (空 = 没有), hybrid 照顾得好会长成的混血, line 大奖那一族}
static func preview(a: Dictionary, b: Dictionary) -> Dictionary:
	var features := [feature_of(a)]
	if not feature_of(b) in features:
		features.append(feature_of(b))
	var extras := [str(a.get("extra", ""))]
	if not str(b.get("extra", "")) in extras:
		extras.append(str(b.get("extra", "")))
	var pair := [a.species, b.species]
	return {"hue": mix(hue_of(a), hue_of(b)), "features": features, "extras": extras,
		"hybrid": Species.hybrid_of(pair), "line": Species.line_of(pair)}


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
	var picks := []
	# 第九版: 有「特别有缘」的对象 (跟它能生混血或大奖蛋) 的话, 三次里有一次会带一位来 (不然要等很多天才碰得到)
	var special := Species.special_partners(own).filter(func(sp): return sp in pool)
	if not special.is_empty() and rng.randf() < SPECIAL_CHANCE:
		picks.append(special[rng.randi() % special.size()])
	while picks.size() < mini(OFFERS, pool.size()):
		var sp: String = pool[rng.randi() % pool.size()]
		if not sp in picks:
			picks.append(sp)
	for i in range(picks.size() - 1, 0, -1):  # 打乱顺序, 特别的那位不总是排第一 (用自己的随机数, 测试能重来)
		var j := rng.randi() % (i + 1)
		var tmp: String = picks[i]
		picks[i] = picks[j]
		picks[j] = tmp
	var out := []
	for sp in picks:
		out.append(random_look(sp, rng))
	return out


## 一位对象的样子: 颜色多半是原来的 (偶尔很特别), 头上的特征随机, 身上的东西有的有
static func random_look(sp: String, rng: RandomNumberGenerator) -> Dictionary:
	var h := fposmod(Art.main_hue(sp) + rng.randf_range(-0.1, 0.1), 1.0)
	if rng.randf() < 0.25:
		h = rng.randf()  # 稀有的颜色
	var keys := FEATURES.keys()
	var extras := EXTRAS.keys()
	var e: String = extras[rng.randi() % extras.size()] if rng.randf() < EXTRA_CHANCE else ""
	return {"species": sp, "hue": h, "feature": keys[rng.randi() % keys.size()], "extra": e}


## 第九版: 节日嘉宾换掉最后一位 (嘉宾是平时碰不到的混血魔物; 跟自己同一种就不换)
static func add_guest(looks: Array, guest: String, own: String, rng: RandomNumberGenerator) -> Array:
	if guest == "" or guest == own or looks.is_empty() or looks.any(func(o): return o.species == guest):
		return looks
	var look := random_look(guest, rng)
	look["guest"] = true
	looks[looks.size() - 1] = look
	return looks


## 第九版: 约会广场来的几位 (学 Paradise: 从现在住的这块地来; 想认识别的地方的就搬过去)
static func date_offers(place: String, own: String, rng: RandomNumberGenerator) -> Array:
	var pool := []
	for k in ["best", "good", "mid", "low", "bad1", "bad2"]:
		var sp: String = Species.PLACES.get(place, Species.PLACES.grass)[k]
		if sp != own:
			pool.append(sp)
	var out := []
	while out.size() < mini(Rules.DATE_OFFERS, pool.size()):
		var sp: String = pool[rng.randi() % pool.size()]
		if not out.any(func(o): return o.species == sp):
			out.append(random_look(sp, rng))
	return out


## 第九版: 算命的说的话 (pv 是 preview 回的; dex 图鉴, 养出过的混血才说名字)
static func fortune_text(pv: Dictionary, dex: Dictionary) -> String:
	if pv.line != "":
		return "【大奖】哇! 这两位会生下一颗闪闪发光的蛋, 孵出来的宝宝跟谁都不一样!"
	var heads := []
	for f in pv.features:
		heads.append(Genes.FEATURES.get(f, ""))
	var bodies := []
	for e in pv.extras:
		if Genes.EXTRAS.has(e):
			bodies.append(Genes.EXTRAS[e])
	var body := "什么都没有"
	if not bodies.is_empty():
		body = "或".join(bodies) + ("" if bodies.size() == pv.extras.size() else ", 也可能什么都没有")
	var out := "宝宝大概是这个颜色~\n头上: %s\n身上: %s (少年才长出来)" % ["或".join(heads), body]
	if pv.hybrid != "":
		var what := "「%s」" % Species.name_of(pv.hybrid) if dex.has(pv.hybrid) else "从没见过的魔物"
		out = "【有缘】这两位特别有缘! 宝宝照顾得好的话, 会长成%s哦\n" % what + out
	return out
