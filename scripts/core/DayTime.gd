class_name DayTime
extends RefCounted
## Время суток в походе: утро, день, вечер, ночь.
## Каждый пункт маршрута — часть суток. Поход начинается утром (поле "start_time" поручения меняет это),
## каждый следующий пункт — следующая часть суток, но ночь наступает только на привале: до него тянется вечер.
## Привал — ночь, отряд спит, следующий пункт — утро. Поле "time" у пункта маршрута задаёт время явно.
## Ночью в бою действует тьма (BattleSim.NIGHT_SIGHT).

const TIMES := ["morning", "day", "evening", "night"]
const NAMES := {"morning": "Утро", "day": "День", "evening": "Вечер", "night": "Ночь"}
## Надпись на экране, когда время меняется по дороге
const BANNERS := {"morning": "Рассвет", "day": "День", "evening": "Вечереет", "night": "Ночь"}

## Свет 3D-уровня, цвет слоя поверх фигурок (tint) и окраска рисованных фонов (backdrop) для каждой части суток.
## day — исходный свет уровней, night — свет уровня «Ночной дозор» (c5).
const PRESETS := {
	"morning": {"bg": Color(0.8, 0.77, 0.76), "amb": Color(0.82, 0.82, 0.88), "amb_e": 0.55,
		"fog": Color(0.8, 0.76, 0.74), "fog_d": 0.01, "sun": Color(1.0, 0.83, 0.64), "sun_e": 0.9,
		"sun_rot": Vector3(-20, -70, 0), "fire": 0.45, "tint": Color(1.0, 0.78, 0.6, 0.06),
		"backdrop": Color(1.0, 0.9, 0.84)},
	"day": {"bg": Color(0.62, 0.74, 0.84), "amb": Color(0.86, 0.9, 0.95), "amb_e": 0.65,
		"fog": Color(0.62, 0.72, 0.78), "fog_d": 0.007, "sun": Color(1.0, 0.96, 0.88), "sun_e": 1.15,
		"sun_rot": Vector3(-52, -38, 0), "fire": 0.3, "tint": Color(1.0, 1.0, 1.0, 0.0),
		"backdrop": Color(1, 1, 1)},
	"evening": {"bg": Color(0.62, 0.45, 0.42), "amb": Color(0.58, 0.56, 0.68), "amb_e": 0.55,
		"fog": Color(0.5, 0.4, 0.42), "fog_d": 0.01, "sun": Color(1.0, 0.68, 0.45), "sun_e": 0.8,
		"sun_rot": Vector3(-14, 60, 0), "fire": 0.8, "tint": Color(0.55, 0.25, 0.12, 0.08),
		"backdrop": Color(1.0, 0.74, 0.58)},
	"night": {"bg": Color(0.03, 0.05, 0.11), "amb": Color(0.36, 0.44, 0.72), "amb_e": 0.45,
		"fog": Color(0.05, 0.08, 0.15), "fog_d": 0.018, "sun": Color(0.6, 0.7, 1.0), "sun_e": 0.35,
		"sun_rot": Vector3(-42, 30, 0), "fire": 1.0, "tint": Color(0.03, 0.05, 0.16, 0.12),
		"backdrop": Color(0.42, 0.48, 0.74)},
}

## Время каждого пункта маршрута по правилам выше.
static func route_times(route: Array, start := "morning") -> Array:
	var out := []
	var t: int = max(0, TIMES.find(start))
	for i in route.size():
		var nd: Dictionary = route[i]
		if i > 0:
			if route[i - 1].get("type", "") == "camp":
				t = 0
			elif t < 2:
				t += 1
		if nd.get("type", "") == "camp":
			t = 3
		if nd.has("time"):
			t = max(0, TIMES.find(str(nd["time"])))
		out.append(TIMES[t])
	return out

## Время пунктов поручения. Берутся актуальные данные DB (в сохранении маршрут мог быть скопирован до правок),
## если число пунктов совпадает с маршрутом похода.
static func contract_times(cid: String, saved_route: Array = []) -> Array:
	var c: Dictionary = DB.CONTRACTS.get(cid, {})
	var route: Array = c.get("route", [])
	if not saved_route.is_empty() and saved_route.size() != route.size():
		route = saved_route
	if route.is_empty():
		route = saved_route if not saved_route.is_empty() else [{"type": "outpost"}]
	return route_times(route, str(c.get("start_time", "morning")))

## Время пункта поручения по имени (для меню баланса: точка боя → пункт маршрута).
static func node_time_by_name(cid: String, node_name: String) -> String:
	var c: Dictionary = DB.CONTRACTS.get(cid, {})
	var route: Array = c.get("route", [])
	var times := contract_times(cid)
	for i in route.size():
		if route[i].get("name", "") == node_name:
			return times[i]
	return "night" if c.get("night", false) else "day"

## Свет между двумя частями суток, k = 0..1.
static func mix(a: String, b: String, k: float) -> Dictionary:
	var pa: Dictionary = PRESETS.get(a, PRESETS["day"])
	var pb: Dictionary = PRESETS.get(b, PRESETS["day"])
	if a == b or k <= 0.0:
		return pa
	if k >= 1.0:
		return pb
	var out := {}
	for key in pa.keys():
		out[key] = lerp(pa[key], pb[key], k)
	return out
