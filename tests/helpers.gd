class_name Helpers
extends RefCounted
## 测试用的小工具: 固定的开始时间、直接做出某个阶段的魔物、一个「很勤快的主人」。

## 2026-01-06 上午 10 点 (测试里时区都是 0, 所以本地时间也是 10 点)。
## 第六版有了节日以后, 从元旦挪到 1 月 6 日 (不是节日), 不然每个测试一开始都会收到新年礼物
const T0 := 1767225600 + 5 * 86400 + 10 * 3600


static func pet(diff := Rules.EASY, t := T0, rng_seed := 12345) -> Pet:
	return Pet.create(t, diff, 0, rng_seed)


## 直接做出一只某个种类的魔物 (心都是满的)
static func at(id: String, diff := Rules.EASY, t := T0, rng_seed := 12345) -> Pet:
	var p := pet(diff, t, rng_seed)
	p.hatched_at = t
	p._become(id)
	p.hunger = 4
	p.happy = 4
	p._settle()
	p.events.clear()
	return p


## 很勤快的主人: 每 step 秒看一次, 该做的都做 (喂饱、哄开心、关灯、吃药、打扫、管教);
## 媒人来了说「现在还不想结婚」(decline_match = false 就不理媒人, 让测试自己挑)
static func care(p: Pet, until: int, step := 5 * 60, do_clean := true, do_medicine := true, decline_match := true) -> void:
	while p.now < until and not p.is_over():
		p.advance(mini(p.now + step, until))
		if p.is_over():
			return
		if p.asleep:
			if p.lights:
				p.toggle_lights()
			continue
		while p.hunger < 4 and p.feed_meal() in ["ok", "bland"]:
			pass
		while p.happy < 4 and p.feed_snack() == "ok":
			pass
		if do_medicine:
			while p.sick and p.give_medicine() != "healthy":
				pass
		if do_clean:
			p.clean()
			p.clean()  # 第六版: 清完便便再洗澡
		if p.call == "discipline":
			p.scold()
		if p.call == "good":
			p.praise()
		if p.wants_leave:
			p.answer_leave(false)
		if p.wants_match and decline_match:
			p.answer_match(-1)
		if p.walking():
			p.end_walk()  # 第八版: 勤快的主人把散步的叫回来 (测试好算)
		if p.pest_at > 0:
			p.shoo()
