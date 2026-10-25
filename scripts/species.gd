class_name Species
extends RefCounted
## 魔物的种类和怎么长大。照原版第一代的长法: 蛋 → 宝宝 → 小孩 → 少年 (两种) → 成年 (六种, 外加一种隐藏的)。
## 长成哪一种看照顾失误几次、管教得怎么样 (照原版的思路; 具体分界是我们定的)。
## 名字都是暂定的 (2026-10-25 Claude 起的), 用户想改随时改。

## bed / wake: 几点睡、几点醒 (从 0 点算起的分钟); life: 平均活到几岁; weight: 基本体重 (克)
## hat: 帽子的下沿放在图的第几行; neck: 领结、围巾的上沿放在第几行 (嘴巴下面; 第二版的装扮用)
const DATA := {
	"egg": {"name": "魔物蛋", "stage": "egg", "weight": 0},
	"tuanzi": {"hat": 6, "neck": 12, "name": "小团子", "stage": "baby", "weight": 5},
	"jianjiao": {"hat": 5, "neck": 12, "name": "小尖角", "stage": "child", "weight": 10, "bed": 20 * 60, "wake": 9 * 60},
	"yishou": {"hat": 4, "neck": 10, "name": "小翼兽", "stage": "teen", "weight": 20, "bed": 21 * 60, "wake": 9 * 60},
	"nigui": {"hat": 4, "neck": 11, "name": "小泥怪", "stage": "teen", "weight": 20, "bed": 21 * 60, "wake": 9 * 60},
	"huolong": {"hat": 4, "neck": 11, "name": "火焰龙", "stage": "adult", "weight": 35, "bed": 21 * 60, "wake": 8 * 60, "life": 14},
	"shuiling": {"hat": 5, "neck": 11, "name": "水灵", "stage": "adult", "weight": 25, "bed": 22 * 60, "wake": 9 * 60, "life": 13},
	"linlu": {"hat": 4, "neck": 10, "name": "林鹿", "stage": "adult", "weight": 30, "bed": 20 * 60, "wake": 8 * 60, "life": 12},
	"shixiang": {"hat": 2, "neck": 7, "name": "石头魔像", "stage": "adult", "weight": 50, "bed": 22 * 60, "wake": 9 * 60, "life": 16},
	"mogu": {"hat": 2, "neck": 13, "name": "毒蘑菇", "stage": "adult", "weight": 20, "bed": 21 * 60, "wake": 9 * 60, "life": 10},
	"xiaomo": {"hat": 4, "neck": 10, "name": "小恶魔", "stage": "adult", "weight": 25, "bed": 23 * 60, "wake": 10 * 60, "life": 9},
	"xingguang": {"hat": 4, "neck": 11, "name": "星光龙", "stage": "adult", "weight": 30, "bed": 21 * 60, "wake": 8 * 60, "life": 18, "secret": true},
}

## 图鉴里的顺序 (蛋不算)
const ORDER := ["tuanzi", "jianjiao", "yishou", "nigui", "huolong", "shuiling", "linlu", "shixiang", "mogu", "xiaomo", "xingguang"]

const STAGE_NAMES := {"egg": "蛋", "baby": "宝宝", "child": "小孩", "teen": "少年", "adult": "成年"}


static func name_of(id: String) -> String:
	return DATA[id].name


## 到时候该长成哪一种
static func next_form(p: Pet) -> String:
	match p.species:
		"egg":
			return "tuanzi"
		"tuanzi":
			return "jianjiao"
		"jianjiao":
			# 小孩阶段失误不多 (≤2) 长成小翼兽, 多了长成小泥怪 (原版也是 3 次失误为界)
			return "yishou" if p.mistakes <= 2 else "nigui"
		"yishou":
			if p.difficulty == Rules.STRICT and p.mistakes_life == 0 and p.discipline >= 4:
				return "xingguang"  # 隐藏的: 原版严格才有 (用户 2026-10-25 定的), 从出生到现在一次失误都没有, 管教满了
			if p.mistakes <= 1 and p.discipline >= 4:
				return "huolong"
			if p.mistakes <= 1:
				return "shuiling"
			if p.mistakes <= 4:
				return "linlu"
			return "shixiang"
		"nigui":
			if p.discipline >= 3:
				return "shixiang"
			if p.mistakes <= 3:
				return "mogu"
			return "xiaomo"
	return p.species
