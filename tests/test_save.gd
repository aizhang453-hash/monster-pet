extends TestCase
## 存档和补算: 存了再读一模一样; 很久没打开游戏, 打开时一下子算到现在。存档写到临时文件夹, 不碰真的存档。

const T0 := Helpers.T0
const DAY := 86400


func before_each() -> void:
	SaveGame.dir = OS.get_temp_dir().path_join("monster_pet_test_save_%d" % OS.get_process_id())


func after_each() -> void:
	SaveGame.erase()
	DirAccess.remove_absolute(SaveGame.dir)


func test_pet_round_trip_keeps_everything() -> void:
	var p := Helpers.pet(Rules.STRICT)
	Helpers.care(p, T0 + DAY + 3 * 3600)
	var copy := Pet.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	for k in Pet.SAVE_KEYS:
		eq(copy.get(k), p.get(k), k)
	eq(copy.rng.state, p.rng.state, "随机数接着原来的往下走")
	# 两只接着一模一样地养, 结果也一模一样
	Helpers.care(p, T0 + 3 * DAY)
	Helpers.care(copy, T0 + 3 * DAY)
	eq(copy.species, p.species)
	eq(copy.discipline, p.discipline)
	eq(copy.next_tantrum, p.next_tantrum)


func test_game_saves_to_the_given_folder() -> void:
	var g := Game.new()
	g.use_system_tz = false
	g.new_egg(Rules.EASY, T0)
	g.fixed_time = T0 + 10 * 60
	g.tick()
	g.act("meal")
	check(g.save())
	check(FileAccess.file_exists(SaveGame.dir.path_join("save.json")), "存在临时文件夹里")
	var g2 := Game.load_saved()
	eq(g2.pet.species, "tuanzi")
	eq(g2.dex, g.dex)
	eq(g2.difficulty, Rules.EASY)


func test_history_and_dex_survive() -> void:
	var g := Game.new()
	g.use_system_tz = false
	g.new_egg(Rules.EASY, T0)
	g.tick(T0 + 10 * 60)
	g.pet.wants_leave = true
	g.pet.answer_leave(true)
	g._take_events()
	eq(g.history.size(), 1)
	eq(g.history[0].reason, "left")
	g.save()
	var g2 := Game.load_saved()
	eq(g2.history.size(), 1)
	eq(g2.history[0].reason, "left")
	eq(g2.dex.get("tuanzi", 0), 1)
	check(g2.pet.is_over())


func test_broken_save_starts_fresh() -> void:
	DirAccess.make_dir_recursive_absolute(SaveGame.dir)
	var f := FileAccess.open(SaveGame.path(), FileAccess.WRITE)
	f.store_string("{坏掉的")
	f.close()
	var g := Game.load_saved()
	check(g.pet == null, "存档坏了就从头开始, 不会出错")


func test_catching_up_after_days_away_is_fast() -> void:
	var p := Helpers.at("huolong", Rules.EASY)
	var started := Time.get_ticks_msec()
	p.advance(T0 + 30 * DAY)
	var ms := Time.get_ticks_msec() - started
	check(ms < 500, "离开一个月, 补算用了 %d 毫秒" % ms)
	eq(p.stage, "dead", "一个月没管, 死了")
	eq(p.now, T0 + 30 * DAY, "时间算到了现在")
