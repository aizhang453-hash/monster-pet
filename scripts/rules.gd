class_name Rules
extends RefCounted
## 所有会调的数字都放在这一个文件里 (用户 2026-10-25 说「能玩以后我试了再调」, 改这里就行)。
## 时间都用秒。STRICT = 原版严格, EASY = 放宽 (放宽的数字是 2026-10-25 用户同意先照着做的)。
## 原版的规矩照拓麻歌子维基 (粉丝整理的) 写的, 维基上没写的是我们自己定的, 后面注明了。

const MIN := 60
const HOUR := 3600
const DAY := 86400

const STRICT := "strict"
const EASY := "easy"
const DIFFICULTY_NAMES := {STRICT: "原版严格", EASY: "放宽"}

## 每个阶段多久 (从这个阶段开始算)。成年以后不再长, 改成到时候问能不能放它走
const STAGE_TIME := {"egg": 5 * MIN, "baby": 60 * MIN, "child": DAY, "teen": 2 * DAY}

## 饿、开心各掉一颗心要多久 (原版严格的; 放宽的乘 EASY_SLOWER, 也就是「慢一半」)
## 维基上没有确切数字, 是我们定的: 宝宝掉得很快, 越大越慢
const HEART_DROP := {"baby": 5 * MIN, "child": 40 * MIN, "teen": 60 * MIN, "adult": 75 * MIN}
const EASY_SLOWER := 2

## 醒着的时候多久拉一次便便 (两种难度一样, 我们定的)。屏幕上最多 4 坨
const POOP_EVERY := {"baby": 15 * MIN, "child": 90 * MIN, "teen": 2 * HOUR, "adult": 150 * MIN}
const MAX_POOP := 4

## 叫你以后多久没理, 算一次照顾失误 (原版 15 分钟; 放宽 2 小时)
const CALL_WINDOW := {STRICT: 15 * MIN, EASY: 2 * HOUR}
## 失误以后心还空着, 过多久再叫你 (我们定的)
const RECALL_GAP := {STRICT: 60 * MIN, EASY: 2 * HOUR}

## 闹脾气 (该管教了): 醒着的时候隔多久闹一次, 在这两个数之间随机 (我们定的)。宝宝不闹
const TANTRUM_GAP := [3 * HOUR, 8 * HOUR]
## 做好事 (该夸它了, 第五版): 醒着的时候隔多久做一次, 在这两个数之间随机 (我们定的)。宝宝不做; 没夸不算失误
const GOOD_GAP := [4 * HOUR, 10 * HOUR]
## 摸摸它 (第五版): 隔多久摸一次才加开心
const PAT_COOLDOWN := 2 * HOUR
## 洗澡 (第六版, 学拓麻歌子 On / Meets 会弄脏、要洗澡): 「干净」0–4 格, 醒着的时候隔这么久少一格 (每天醒来重新算);
## 练完、比完、上完班、出门也会脏一格。脏到 0 格还不洗, 每隔这么久开心 -1 (不叫你、不算失误)。数字是我们定的
const DIRTY_EVERY := {STRICT: 3 * HOUR, EASY: 6 * HOUR}

## 生病
const POOP_SICK := {STRICT: 3 * HOUR, EASY: 8 * HOUR}     # 便便放多久没清会生病 (我们定的)
const EMPTY_SICK := {STRICT: 6 * HOUR, EASY: 12 * HOUR}   # 心空多久会生病 (我们定的)
const SICK_DEATH := {STRICT: 12 * HOUR, EASY: DAY}         # 生病拖多久没治会死 (放宽: 一整天)
const SICK_TIMES_DEATH := 3                                # 原版严格: 同一个阶段病到第 3 次就死 (放宽不算次数)
const OLD_SICK_FROM := 12                                  # 原版: 活到 12 岁会生病, 之后每 3 天病一次
const OLD_SICK_EVERY := 3

## 饿死: 饿或不开心的心空了多久会死 (放宽: 整整一天; 严格的原版主要靠失误次数, 再加一条 12 小时)
const STARVE := {STRICT: 12 * HOUR, EASY: DAY}
## 原版严格: 成年以后照顾失误满 5 次会死。放宽的失误不会死, 只影响长成哪一种
const ADULT_MISTAKES_DEATH := 5

## 成年以后过多久, 它会说想离开 (出去闯荡); 你不放它走的话, 过多久再问 (我们定的)
const LEAVE_ASK_AFTER := 3 * DAY
const LEAVE_ASK_AGAIN := 2 * DAY
## 第十版: 成年以后多久还没结婚, 就老了 (学 Connection 1–4.5 代是 5 天; 用户 2026-10-26 定的: 老了媒人不来, 也不能再结婚)
const SENIOR_AFTER := 5 * DAY
## 老死: 成年时定下活到几岁 = 种类的寿命 + 这两个数之间随机 (原版平均 12 岁左右, 最短 7, 最长 25)
const LIFESPAN_RANDOM := [-2, 4]
const LIFESPAN_MIN := 8

## 结婚 (第七版, 学拓麻歌子 Connection 的媒人): 成年以后过多久媒人上门; 不想结婚的话, 过多久再来 (我们定的)
const MATCH_AFTER := DAY
const MATCH_AGAIN := DAY
## 爸妈家 (第七版, 学 On / Meets): 送去爸妈家跟托人照看一样 (共用每天的时间); 待够这么久, 爸妈教它一些东西 (一天一次)
const PARENTS_TEACH := HOUR
## 第九版: 小孩搬到别的地方, 过多久变成那个地方的小孩 (学乐园, 用户 2026-10-26 选的)
const MORPH_TIME := HOUR
## 第九版: 别的结婚办法 (用户 2026-10-26 说拓麻歌子的结婚办法「都做上」; 数字都是 Claude 定的)
const DATE_PER_DAY := 3       # 约会广场一天能约几次 (学 Paradise、V5 相亲节目)
const DATE_OFFERS := 4        # 约会广场一次来几位 (学 Paradise、Uni)
const FRIEND_MAX := 5         # 交情最多几颗心; 满了对方会来求婚 (学 m!x、On)
const RING_HEARTS := 3        # 用普通戒指求婚, 交情要几颗心才答应 (钻石戒指一定答应)
const GIFT_PRICE := 10        # 给朋友送礼物花几个魔晶 (交情 +1, 每位朋友一天一次)

## 它自己出去散步 (第八版, 学拓麻歌子天使): 醒着、心情好的时候隔多久溜出去一次, 出去多久 (都在这两个数之间随机, 我们定的)。
## 散步的时候不在家, 饿和开心不掉; 回来会带点小东西
const WALK_GAP := [6 * HOUR, 12 * HOUR]
const WALK_TIME := [30 * MIN, 60 * MIN]
## 捣蛋精 (第八版, 学拓麻歌子海洋、森林发现的天敌): 醒着的时候隔多久来一次; 来了以后多久没赶走就捣乱 (吓它一跳: 开心 -1, 不算失误)。
## 一开始是「饿 -1、开心 -1, 严格 15 分钟」, 量出来原版严格变难太多 (隔 2 小时看一次平安长大 79% → 68%), 改轻了
const PEST_GAP := [8 * HOUR, 16 * HOUR]
const PEST_WINDOW := {STRICT: 30 * MIN, EASY: HOUR}

## 托人照看 (学现代拓麻歌子的暂停 / 照看模式, 用户 2026-10-25 要的): 上学、上班时托给别人,
## 照看的人会喂饱、哄开心、打扫、治病、关灯, 这段时间不叫你、不算失误, 但它照样长大。每天最多托这么久 (我们定的)
const SITTER_PER_DAY := 10 * HOUR

## 小游戏的规矩 (几次、怎么算赢、给多少魔晶) 在 scripts/game_*.gd 里; 商店的价钱在 scripts/items.gd 里

## 体重 (克): 正餐 +1, 零食 +2, 玩一次小游戏 -1 (照原版)。最轻不会低于这个种类的基本体重
const MEAL_WEIGHT := 1
const SNACK_WEIGHT := 2
const GAME_WEIGHT := 1

## 一次最多补算多久 (很久没打开游戏的时候)
const MAX_CATCH_UP := 60 * DAY


static func heart_drop(stage: String, difficulty: String) -> int:
	return HEART_DROP[stage] * (EASY_SLOWER if difficulty == EASY else 1)
