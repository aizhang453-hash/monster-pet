extends TestCase
## 小游戏 (第二版): 哪个阶段能玩哪个; 每个小游戏会玩完、会玩的能赢、不会玩的赢不了、魔晶算对。


func test_which_stage_plays_what() -> void:
	eq(MiniGames.unlocked("baby"), ["guess"], "宝宝只有猜左右")
	eq(MiniGames.unlocked("child"), ["guess", "catch"])
	eq(MiniGames.unlocked("teen"), ["guess", "catch", "jump"])
	eq(MiniGames.unlocked("adult"), ["guess", "catch", "jump", "memory"])
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
