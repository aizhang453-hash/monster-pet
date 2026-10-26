extends TestCase
## 小游戏 (第二版): 哪个阶段能玩哪个; 每个小游戏会玩完、会玩的能赢、不会玩的赢不了、魔晶算对。


func test_which_stage_plays_what() -> void:
	eq(MiniGames.unlocked("baby"), ["guess", "number", "rope", "climb"], "宝宝: 猜左右、猜数字、跳绳、爬高")
	eq(MiniGames.unlocked("child"), ["guess", "number", "rope", "climb", "catch", "tug", "mimic"])
	eq(MiniGames.unlocked("teen"), ["guess", "number", "rope", "climb", "catch", "tug", "mimic", "jump", "flag", "sprint"])
	eq(MiniGames.unlocked("adult").size(), 13, "成年: 十三个全能玩")
	eq(MiniGames.unlocked("egg"), [])


func _run(g: MiniGame, player: Callable, seconds := 120.0) -> void:
	var dt := 0.05
	var time := 0.0
	while not g.done and time < seconds:
		player.call(g)
		g.step(dt)
		time += dt


func test_guess_counts_hits() -> void:
	var g := MiniGames.make("guess", 7)
	_run(g, func(x: GuessGame): x.press("left"))
	check(g.done, "5 次猜完就结束")
	eq(g.round_no, 5)
	check(g.score >= 0 and g.score <= 5)
	eq(g.won(), g.score >= 3)
	eq(g.reward(), g.score * 3 + (5 if g.won() else 0))


func test_catch_good_player_wins_lazy_player_loses() -> void:
	var good := MiniGames.make("catch", 11) as CatchGame
	_run(good, func(c: CatchGame):
		# 往最低的那个果子下面走
		var target := -1.0
		var lowest := -99.0
		for f in c.fruits:
			if f.y > lowest:
				lowest = f.y
				target = f.x + 2.0 - CatchGame.PET_W / 2.0
		if target < 0 or absf(c.pet_x - target) < 1.0:
			c.release("left")
			c.release("right")
		elif target < c.pet_x:
			c.press("left")
		else:
			c.press("right"))
	check(good.done, "15 个掉完就结束")
	eq(good.score + good.missed, CatchGame.TOTAL)
	check(good.won(), "会玩的能赢 (接住 %d 个)" % good.score)
	var lazy := MiniGames.make("catch", 11) as CatchGame
	_run(lazy, func(_c): pass)
	check(lazy.done)
	check(not lazy.won(), "站着不动赢不了 (接住 %d 个)" % lazy.score)


func test_jump_good_player_wins_lazy_player_loses() -> void:
	var good := MiniGames.make("jump", 5) as JumpGame
	_run(good, func(j: JumpGame):
		# 石头再过 0.15–0.3 秒就要撞上的时候跳
		for r in j.rocks:
			var until: float = (r.x + JumpGame.ROCK_HIT[0] - JumpGame.HIT_RIGHT) / j.speed()
			if until > 0.15 and until < 0.3:
				j.press("jump"))
	check(good.done, "12 块滚完就结束")
	eq(good.score + good.hits, JumpGame.TOTAL)
	check(good.won(), "会跳的能赢 (跳过 %d 块)" % good.score)
	var lazy := MiniGames.make("jump", 5) as JumpGame
	_run(lazy, func(_j): pass)
	eq(lazy.score, 0, "不跳全撞上")
	eq(lazy.hits, JumpGame.TOTAL)


func test_memory_good_player_clears_all_wrong_press_ends() -> void:
	var good := MiniGames.make("memory", 3) as MemoryGame
	_run(good, func(m: MemoryGame):
		if m.phase == "input":
			m.press(m.seq[m.typed]))
	check(good.done)
	eq(good.score, MemoryGame.MAX_ROUNDS, "全记对过 6 关")
	check(good.won())
	eq(good.reward(), MemoryGame.MAX_ROUNDS * 4 + 5)
	var bad := MiniGames.make("memory", 3) as MemoryGame
	_run(bad, func(m: MemoryGame):
		if m.phase == "input":
			m.press("red" if m.seq[m.typed] != "red" else "blue"))
	check(bad.done)
	eq(bad.score, 0, "第一个就按错, 结束")
	check(bad.wrong)


func test_rewards_are_modest() -> void:
	# 每局最多赚多少: 让商店的东西要攒一阵 (最贵的王冠 300)
	eq(MiniGames.make("guess", 1).reward() <= 20, true)
	var best := {"guess": 5 * 3 + 5, "catch": CatchGame.TOTAL + 5, "jump": JumpGame.TOTAL + 5, "memory": MemoryGame.MAX_ROUNDS * 4 + 5}
	for id in best:
		check(best[id] <= 30, "%s 一局最多 %d 魔晶" % [id, best[id]])


# ---------------------------------------------------------------- 第六版的九个小游戏: 会玩的能赢、不玩的赢不了、一定玩得完

## 每隔 every 秒按一下 action
func _tapper(action: String, every: float) -> Callable:
	var state := {"wait": 0.0}
	return func(g: MiniGame):
		state.wait -= 0.05
		if state.wait <= 0:
			g.press(action)
			state.wait = every


func test_number_guess_finishes_and_smart_guesses_win_more() -> void:
	var wins := 0
	for s in 40:
		var g := MiniGames.make("number", s + 1) as NumberGame
		_run(g, func(x: NumberGame): x.press("big" if x.current < 5 else "small"))
		check(g.done, "5 次猜完就结束")
		eq(g.round_no, NumberGame.ROUNDS)
		if g.won():
			wins += 1
	check(wins >= 25, "照「小的猜大、大的猜小」猜, 40 局赢了 %d 局" % wins)


func test_rope_good_jumper_wins_lazy_trips() -> void:
	for s in 10:
		var good := MiniGames.make("rope", s + 1) as RopeGame
		_run(good, func(r: RopeGame):
			# 绳子再过 0.25 秒到脚下的时候跳
			if (1.0 - r.phase) * r.period <= 0.25:
				r.press("jump"))
		check(good.done)
		check(good.won() and not good.tripped, "会跳的能跳满 (跳了 %d 下)" % good.score)
	var lazy := MiniGames.make("rope", 3) as RopeGame
	_run(lazy, func(_r): pass)
	check(lazy.done and lazy.tripped, "不跳一下就绊倒")
	eq(lazy.score, 0)
	var early := MiniGames.make("rope", 3) as RopeGame
	_run(early, _tapper("jump", 0.5))
	check(early.done, "乱跳也会结束")


func test_climb_alternating_hands_wins() -> void:
	var good := MiniGames.make("climb", 1) as ClimbGame
	var hands := {"n": 0}
	_run(good, func(c: ClimbGame):
		hands.n += 1
		if hands.n % 4 == 0:  # 每 0.2 秒按一下, 左右轮流
			c.press("l" if hands.n % 8 == 0 else "r"))
	check(good.won(), "左右轮流按能爬到顶 (爬了 %d)" % good.score)
	var same := MiniGames.make("climb", 1) as ClimbGame
	_run(same, _tapper("l", 0.2))
	check(same.done and not same.won(), "一直按同一只手会滑下来 (%d)" % same.score)
	check(same.slips > 0)
	var lazy := MiniGames.make("climb", 1) as ClimbGame
	_run(lazy, func(_c): pass)
	check(lazy.done and not lazy.won(), "不按就时间到")


func test_tug_fast_puller_wins_slow_loses() -> void:
	for s in 10:
		var good := MiniGames.make("tug", s + 1) as TugGame
		_run(good, _tapper("pull", 0.2))
		check(good.done and good.won(), "一秒按 5 下能赢 (标记在 %.1f)" % good.mark)
		var slow := MiniGames.make("tug", s + 1) as TugGame
		_run(slow, _tapper("pull", 1.0))
		check(slow.done and not slow.won(), "一秒按 1 下赢不了")


func test_mimic_good_eye_wins_lazy_times_out() -> void:
	var good := MiniGames.make("mimic", 4) as MimicGame
	_run(good, func(m: MimicGame):
		if m.pose() == m.target:
			m.press("pick"))
	check(good.done)
	eq(good.score, MimicGame.ROUNDS, "看准了再按, 全对")
	var lazy := MiniGames.make("mimic", 4) as MimicGame
	_run(lazy, func(_m): pass)
	check(lazy.done, "不按的话每次 5 秒到了就算错, 也会结束")
	eq(lazy.score, 0)
	var rash := MiniGames.make("mimic", 4) as MimicGame
	_run(rash, func(m: MimicGame):
		if m.pose() != m.target:
			m.press("pick"))
	eq(rash.score, 0, "专挑不一样的时候按, 全错")


func test_flag_follows_orders() -> void:
	for s in 10:
		var good := MiniGames.make("flag", s + 1) as FlagGame
		_run(good, func(f: FlagGame):
			if f.order in ["red", "white"] and not f.answered and f._left < f.window - 0.3:
				f.press(f.order))
		check(good.done)
		eq(good.score, FlagGame.ROUNDS, "照口令做全对 (「都别动」忍住不按也算对)")
	var wrong := MiniGames.make("flag", 2) as FlagGame
	_run(wrong, _tapper("red", 0.1))
	check(wrong.done)
	check(not wrong.won(), "一直举红旗赢不了 (对了 %d)" % wrong.score)


func test_sprint_fast_runner_wins() -> void:
	for s in 10:
		var good := MiniGames.make("sprint", s + 1) as SprintGame
		_run(good, _tapper("run", 0.25))
		check(good.done and good.won(), "一秒按 4 下跑得赢 (对手 %d 米)" % good.rival)
		var slow := MiniGames.make("sprint", s + 1) as SprintGame
		_run(slow, _tapper("run", 0.5))
		check(slow.done and not slow.won(), "一秒按 2 下跑不赢")


func test_dance_hits_arrows_on_the_line() -> void:
	var good := MiniGames.make("dance", 6) as DanceGame
	_run(good, func(d: DanceGame):
		for n in d.notes.duplicate():
			if absf(n.y - DanceGame.LINE) < 1.0:
				d.press(n.lane))
	check(good.done)
	eq(good.score, DanceGame.TOTAL, "到线上就按, 全踩中")
	check(good.won())
	var lazy := MiniGames.make("dance", 6) as DanceGame
	_run(lazy, func(_d): pass)
	check(lazy.done)
	eq(lazy.missed, DanceGame.TOTAL, "不按全没踩到")


func test_burger_follow_the_order() -> void:
	var good := MiniGames.make("burger", 8) as BurgerGame
	var tick := {"n": 0}
	_run(good, func(b: BurgerGame):
		tick.n += 1
		if tick.n % 6 == 0 and b._wait <= 0:  # 0.3 秒放一层
			b.press(b.order[b.built.size()]))
	check(good.done)
	eq(good.score, BurgerGame.ORDERS, "照着点的放, 5 份都做好")
	var bad := MiniGames.make("burger", 8) as BurgerGame
	_run(bad, _tapper("cheese", 0.3))
	check(bad.done)
	eq(bad.score, 0, "第一层就放芝士, 全做坏")
	var lazy := MiniGames.make("burger", 8) as BurgerGame
	_run(lazy, func(_b): pass)
	check(lazy.done, "不按的话每份 10 秒到了也会结束")
	eq(lazy.failed, BurgerGame.ORDERS)


func test_every_game_ends_and_pays_little() -> void:
	# 十三个小游戏乱按都能玩完, 一局最多赚 30 魔晶以内 (商店的东西要攒一阵)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for info in MiniGames.LIST:
		for s in 5:
			var g := MiniGames.make(info.id, s + 1)
			var acts: Array = g.buttons().map(func(b): return b[0])
			_run(g, func(x: MiniGame):
				if rng.randf() < 0.3:
					var a: String = acts[rng.randi() % acts.size()]
					x.press(a)
					if x.hold_buttons() and rng.randf() < 0.5:
						x.release(a), 300.0)
			check(g.done, "%s 乱按也能玩完" % info.id)
			check(g.reward() >= 0 and g.reward() <= 30, "%s 一局给 %d 魔晶" % [info.id, g.reward()])
