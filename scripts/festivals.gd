class_name Festivals
extends RefCounted
## 节日 (第六版, 学拓麻歌子 Uni 的季节活动和「圣诞老人」那一款; 用户 2026-10-25 说「把第六版做了」, 节日是 Claude 挑的)。
## 按真实的日期 (本地时间) 过节: 那天小屏幕有节日的装饰, 第一次打开游戏收到节日礼物和一件纪念品, 商店里有节日的吃的。
## 春节、中秋是农历, 这里写好了 2026–2035 年的公历日期 (2026-10-25 上网跟几个日历网站核对过); **2035 年以后要加**, 测试 test_festivals 会提醒。

const LIST := {
	"newyear": {"name": "新年", "days": [[1, 1]], "deco": "firework", "souvenir": "firework"},
	"spring": {"name": "春节", "lunar": "spring", "length": 3, "deco": "fu", "souvenir": "fu"},
	"children": {"name": "儿童节", "days": [[6, 1]], "deco": "balloon", "souvenir": "balloon"},
	"midautumn": {"name": "中秋节", "lunar": "midautumn", "length": 1, "deco": "moon", "souvenir": "moon"},
	"halloween": {"name": "万圣节", "days": [[10, 31]], "deco": "pumpkin", "souvenir": "pumpkin"},
	"christmas": {"name": "圣诞节", "days": [[12, 24], [12, 25]], "deco": "snowman", "souvenir": "snowman"},
}

## 第九版: 节日嘉宾 (学 m!x 店里大机器每季换的特别对象): 过节那天, 媒人和约会广场会多带一位平时碰不到的混血魔物
const GUESTS := {"newyear": "zhengqilong", "spring": "yanjiagui", "children": "moguwa", "midautumn": "yuyunjing",
	"halloween": "feisha", "christmas": "feilu"}

## 农历节日的公历日期 [月, 日]
const LUNAR := {
	"spring": {2026: [2, 17], 2027: [2, 6], 2028: [1, 26], 2029: [2, 13], 2030: [2, 3],
		2031: [1, 23], 2032: [2, 11], 2033: [1, 31], 2034: [2, 19], 2035: [2, 8]},
	"midautumn": {2026: [9, 25], 2027: [9, 15], 2028: [10, 3], 2029: [9, 22], 2030: [9, 12],
		2031: [10, 1], 2032: [9, 19], 2033: [9, 8], 2034: [9, 27], 2035: [9, 16]},
}
const LAST_YEAR := 2035

## 节日礼物 (第一次打开游戏时给): money 魔晶 / items 吃的 / toy 一个还没有的玩具
const GIFTS := {
	"newyear": {"text": "新年快乐! 放了烟花, 收到魔晶 30", "money": 30},
	"spring": {"text": "春节快乐! 收到红包: 魔晶 88, 还有饺子", "money": 88, "items": {"dumpling": 2}},
	"children": {"text": "儿童节快乐! 收到一个礼物", "toy": true, "money": 40},
	"midautumn": {"text": "中秋快乐! 一起赏月, 收到月饼", "items": {"mooncake": 3}},
	"halloween": {"text": "不给糖就捣蛋! 收到南瓜糖", "items": {"pumpkin_candy": 3}},
	"christmas": {"text": "圣诞快乐! 收到圣诞礼物: 蛋糕", "items": {"cake": 2}, "money": 30},
}


## 这一天 (Unix 秒 + 本地时差) 是什么节, 不是节日回空
static func today(t: int, tz: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(t + tz)
	for id in LIST:
		var f: Dictionary = LIST[id]
		if f.has("days"):
			for md in f.days:
				if d.month == md[0] and d.day == md[1]:
					return id
		else:
			var dates: Dictionary = LUNAR[f.lunar]
			if not dates.has(d.year):
				continue
			var start := Time.get_unix_time_from_datetime_dict({"year": d.year, "month": dates[d.year][0], "day": dates[d.year][1]})
			var day0 := Time.get_unix_time_from_datetime_dict({"year": d.year, "month": d.month, "day": d.day})
			var n := floori((day0 - start) / 86400.0)
			if n >= 0 and n < int(f.length):
				return id
	return ""


static func name_of(id: String) -> String:
	return LIST[id].name
