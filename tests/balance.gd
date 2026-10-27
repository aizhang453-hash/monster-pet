extends SceneTree
## 量难度: 假装有几种主人, 白天 (8 点到 22 点) 每隔一阵看一次, 看的时候该做的都做, 晚上自己也睡觉。
## 每种主人在两种难度下各养几百只, 看多少只能平安长大 (离开或老死)、多少只死掉、长成了什么。
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tests/balance.gd

const T0 := 1767225600 + 9 * 3600   # 2026-01-01 早上 9 点 (时区 0)
const PETS := 300
const GAPS := [15, 30, 60, 120, 240]  # 隔几分钟看一次


func _initialize() -> void:
	print("隔多久看一次 | 难度 | 平安长大 (离开/老死) | 死掉 (没人照顾/病死) | 长成的成年魔物")
	for diff in [Rules.EASY, Rules.STRICT]:
		for gap in GAPS:
			_run(diff, gap)
	print("上学的主人: 早上 8 点托人照看, 下午 6 点接回来, 晚上每小时看一次")
	for diff in [Rules.EASY, Rules.STRICT]:
		_run(diff, 60, true)
	quit()


func _run(diff: String, gap_min: int, school := false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = gap_min * 7 + (1 if diff == Rules.EASY else 2)
	var ends := {}
	var adults := {}
	for n in PETS:
		var p := Pet.create(T0 + rng.randi_range(0, 3600), diff, 0, n + 1)
		while not p.is_over() and p.now < T0 + 40 * 86400:
			var next := p.now + int(gap_min * 60 * rng.randf_range(0.8, 1.2))
			var hour := posmod(floori(next / 3600.0), 24)
			if hour >= 22 or hour < 8:  # 主人晚上睡觉, 第二天 8 点再看
				var day_start := next - posmod(next, 86400) + 8 * 3600
				next = day_start if day_start > next else day_start + 86400
			elif school and hour >= 8 and hour < 18 and p.sitting():
				next = next - posmod(next, 86400) + 18 * 3600  # 托出去了, 下午 6 点才回来
			p.advance(next)
			hour = posmod(floori(p.now / 3600.0), 24)
			if school and p.sitting() and hour >= 18:
				p.end_sitter()
			_care(p)
			if school and hour >= 8 and hour < 18 and not p.sitting():
				p.start_sitter()
		ends[p.end_reason] = int(ends.get(p.end_reason, 0)) + 1
		if Species.DATA[p.species].stage == "adult":
			adults[p.species] = int(adults.get(p.species, 0)) + 1
	var safe := int(ends.get("left", 0)) + int(ends.get("old", 0))
	var dead := int(ends.get("neglect", 0)) + int(ends.get("sick", 0))
	var names := []
	for id in adults:
		names.append("%s %d" % [Species.name_of(id), adults[id]])
	print("%3d 分钟%s | %s | %3d%% (%d/%d) | %3d%% (%d/%d) | %s" % [gap_min, " (上学)" if school else "", Rules.DIFFICULTY_NAMES[diff],
		safe * 100 / PETS, ends.get("left", 0), ends.get("old", 0), dead * 100 / PETS,
		ends.get("neglect", 0), ends.get("sick", 0), ", ".join(names)])


func _care(p: Pet) -> void:
	if p.is_over():
		return
	if p.asleep:
		if p.lights:
			p.toggle_lights()
		p.clean()  # 第八版: 睡着了也顺手把便便扫掉 (真人会这么做; 以前不扫, 睡前的便便放一整晚会病)
		return
	while p.hunger < 4 and p.feed_meal() in ["ok", "bland"]:
		pass
	while p.happy < 4 and p.feed_snack() == "ok":
		pass
	while p.sick and p.give_medicine() != "healthy":
		pass
	p.clean()
	p.clean()  # 第六版: 清完便便再洗澡
	if p.call == "discipline":
		p.scold()
	if p.call == "good":
		p.praise()
	if p.wants_match:
		p.answer_match(-1)
	if p.pest_at > 0:
		p.shoo()  # 第八版: 看到捣蛋精就赶走 (散步就让它散)  # 第七版: 量难度的主人不结婚 (跟以前的数字好比)
	if p.wants_leave:
		p.answer_leave(true)
