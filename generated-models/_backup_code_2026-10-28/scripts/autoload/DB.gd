extends Node
## Статические данные игры: герои, умения, перки, предметы, враги, контракты, события, разговоры.

const HERO_IDS := ["aiden", "marek", "elira", "neris"]

func _ready() -> void:
	Balance.boot()

const COMPANIONS := ["marek", "elira", "neris"]
const STORAGE_SIZE := 80
const BACKPACK_CAP := 8
const MAX_LEVEL := 10
## Job 4 — последний: очки Job идут на три этапа перков (2, 3, 4)
const MAX_JOB := 4
const SLOTS := ["head", "chest", "hands", "waist", "feet", "neck", "ring1", "ring2", "main", "off"]
const SLOT_NAMES := {
	"head": "Голова", "chest": "Грудь", "hands": "Перчатки", "waist": "Пояс", "feet": "Обувь",
	"neck": "Амулет", "ring1": "Кольцо I", "ring2": "Кольцо II", "main": "Правая рука", "off": "Левая рука",
}
const STAT_NAMES := {
	"sta": "Выносливость", "str": "Сила", "agi": "Ловкость", "int": "Интеллект",
	"armor": "Броня", "crit": "Крит. шанс", "hit": "Меткость", "dodge": "Уклонение",
	"parry": "Парирование", "block": "Шанс блока", "block_val": "Сила блока", "sp": "Сила заклинаний",
	"res_fire": "Сопр. огню", "res_shadow": "Сопр. тьме", "res_nature": "Сопр. природе",
	"res_holy": "Сопр. свету", "hp": "Здоровье", "mp": "Мана",
}
const PCT_STATS := ["crit", "hit", "dodge", "parry", "block"]
const SCHOOL_NAMES := {"phys": "физический", "fire": "огонь", "shadow": "тьма", "nature": "природа", "holy": "свет"}
const RARITY := ["common", "uncommon", "rare", "epic"]
const RARITY_NAMES := {"common": "Обычная", "uncommon": "Необычная", "rare": "Редкая", "epic": "Эпическая"}
const RARITY_COLORS := {"common": Color(0.86, 0.84, 0.8), "uncommon": Color(0.45, 0.85, 0.4), "rare": Color(0.4, 0.62, 1.0), "epic": Color(0.78, 0.45, 1.0)}
const RARITY_AFFIXES := {"common": 0, "uncommon": 1, "rare": 2, "epic": 3}
const ARMOR_TYPE_NAMES := {"cloth": "ткань", "leather": "кожа", "mail": "кольчуга", "plate": "латы", "jewel": "украшение"}
const WEAPON_TYPE_NAMES := {"sword": "меч", "mace": "булава", "dagger": "кинжал", "bow": "лук", "staff": "посох", "shield": "щит"}

# ---------------------------------------------------------------- Герои
var HEROES := {
	"aiden": {
		"name": "Эйден", "full": "Эйден", "cls": "Жрец", "role": "Целитель, щиты света",
		"color": Color(0.95, 0.85, 0.55),
		"base": {"sta": 10, "str": 6, "agi": 7, "int": 16},
		"grow": {"sta": 2.2, "str": 0.8, "agi": 1.0, "int": 3.2},
		"weapons": ["staff", "mace"], "armors": ["cloth"],
		"school": "holy",
		"bio": "Молодой жрец, унаследовавший от наставника, отца Тибальда, дом гильдии, долги и упрямую веру в то, что людям надо помогать — даже за медяки.",
		"likes_hint": "",
	},
	"marek": {
		"name": "Марек", "full": "Марек Вальд", "cls": "Воин", "role": "Защитник: меч и щит",
		"color": Color(0.35, 0.45, 0.75),
		"base": {"sta": 16, "str": 14, "agi": 8, "int": 5},
		"grow": {"sta": 3.4, "str": 2.6, "agi": 1.2, "int": 0.4},
		"weapons": ["sword", "mace", "shield"], "armors": ["mail", "plate"],
		"school": "phys",
		"bio": "Бывший сержант пограничной стражи. Немногословен, встаёт первым под удар и последним садится к костру.",
	},
	"elira": {
		"name": "Элира", "full": "Элира", "cls": "Охотница", "role": "Лучница против опасных целей",
		"color": Color(0.35, 0.65, 0.35),
		"base": {"sta": 11, "str": 7, "agi": 16, "int": 7},
		"grow": {"sta": 2.2, "str": 0.8, "agi": 3.2, "int": 0.8},
		"weapons": ["bow", "dagger"], "armors": ["leather"],
		"school": "phys",
		"bio": "Эльфийская охотница из лесов за Ольховым Бродом. Смеётся громко, стреляет тихо и считает каждого волка на тракте.",
	},
	"neris": {
		"name": "Нэрис", "full": "Нэрис Вейль", "cls": "Чернокнижница", "role": "Проклятия и тёмная магия",
		"color": Color(0.6, 0.35, 0.7),
		"base": {"sta": 9, "str": 5, "agi": 7, "int": 17},
		"grow": {"sta": 2.0, "str": 0.4, "agi": 1.0, "int": 3.4},
		"weapons": ["staff", "dagger"], "armors": ["cloth"],
		"school": "shadow",
		"bio": "Чернокнижница с рогами и острым языком. Деревенские крестятся ей вслед, а она делает вид, что ей всё равно.",
	},
}

# ---------------------------------------------------------------- Умения
# cost: ATB-заряды, mp: мана, cast: подготовка (с), cd: перезарядка (с), lvl: Base Level открытия
# target: enemy / ally / self / area / allies
var ABILITIES := {
	# Марек
	"taunt": {"hero": "marek", "name": "Провокация", "cost": 1, "mp": 30, "cast": 0.0, "cd": 10.0, "lvl": 1, "target": "self",
		"desc": "Враги в радиусе 320 атакуют Марека 6 с. Броня +25% на время провокации."},
	"bash": {"hero": "marek", "name": "Сбивающий удар", "cost": 1, "mp": 25, "cast": 0.0, "cd": 8.0, "lvl": 1, "target": "enemy", "melee": true,
		"desc": "Удар щитом: 80% урона оружия, прерывает подготовку и оглушает на 1,5 с."},
	"wall": {"hero": "marek", "name": "Стена щитов", "cost": 2, "mp": 40, "cast": 0.0, "cd": 22.0, "lvl": 3, "target": "self",
		"desc": "Марек получает на 50% меньше урона 7 с."},
	"cleave": {"hero": "marek", "name": "Размашистый удар", "cost": 1, "mp": 30, "cast": 0.0, "cd": 7.0, "lvl": 5, "target": "enemy", "melee": true,
		"desc": "120% урона оружия цели и всем врагам в 110 от неё."},
	# Элира
	"aimed": {"hero": "elira", "name": "Прицельный выстрел", "cost": 1, "mp": 25, "cast": 1.0, "cd": 0.0, "lvl": 1, "target": "enemy",
		"desc": "Подготовка 1 с. 220% урона, крит. шанс +40%."},
	"pin": {"hero": "elira", "name": "Пригвождающая стрела", "cost": 1, "mp": 25, "cast": 0.0, "cd": 9.0, "lvl": 1, "target": "enemy",
		"desc": "90% урона, прерывает подготовку, замедляет на 40% на 5 с."},
	"volley": {"hero": "elira", "name": "Град стрел", "cost": 2, "mp": 50, "cast": 1.5, "cd": 14.0, "lvl": 3, "target": "ground", "area": 200,
		"desc": "Подготовка 1,5 с. 100% урона всем врагам в выбранной области радиусом 200."},
	"mark": {"hero": "elira", "name": "Метка охотника", "cost": 1, "mp": 20, "cast": 0.0, "cd": 12.0, "lvl": 5, "target": "enemy",
		"desc": "Цель получает на 25% больше урона 8 с."},
	# Нэрис
	"bolt": {"hero": "neris", "name": "Стрела тьмы", "cost": 1, "mp": 35, "cast": 1.2, "cd": 0.0, "lvl": 1, "target": "enemy", "school": "shadow",
		"desc": "Подготовка 1,2 с. 200% силы заклинаний, тьма."},
	"curse": {"hero": "neris", "name": "Проклятие слабости", "cost": 1, "mp": 30, "cast": 0.0, "cd": 8.0, "lvl": 1, "target": "ground", "area": 110, "school": "shadow",
		"desc": "Враги в выбранной области радиусом 110 наносят на 30% меньше урона и получают урон тьмой 8 с."},
	"hellfire": {"hero": "neris", "name": "Пламя бездны", "cost": 2, "mp": 70, "cast": 1.8, "cd": 16.0, "lvl": 3, "target": "ground", "area": 180, "school": "fire",
		"desc": "Подготовка 1,8 с. 140% силы заклинаний огнём по выбранной области радиусом 180 и горение."},
	"drain": {"hero": "neris", "name": "Похищение жизни", "cost": 1, "mp": 40, "cast": 0.0, "cd": 10.0, "lvl": 5, "target": "enemy", "school": "shadow",
		"desc": "120% силы заклинаний; Нэрис исцеляется на нанесённый урон."},
	# Эйден
	"heal": {"hero": "aiden", "name": "Исцеление", "cost": 1, "mp": 35, "cast": 1.2, "cd": 0.0, "lvl": 1, "target": "ally",
		"desc": "Подготовка 1,2 с. Лечит союзника на 30 + 220% силы заклинаний."},
	"ward": {"hero": "aiden", "name": "Щит света", "cost": 1, "mp": 40, "cast": 0.0, "cd": 7.0, "lvl": 1, "target": "ally",
		"desc": "Барьер поглощает 40 + 160% силы заклинаний урона, 12 с."},
	"renew": {"hero": "aiden", "name": "Обновление", "cost": 1, "mp": 30, "cast": 0.0, "cd": 5.0, "lvl": 3, "target": "ally",
		"desc": "Лечит союзника на 25 + 150% силы заклинаний за 10 с."},
	"prayer": {"hero": "aiden", "name": "Молитва исцеления", "cost": 2, "mp": 90, "cast": 2.0, "cd": 20.0, "lvl": 5, "target": "allies",
		"desc": "Подготовка 2 с. Лечит всех союзников на 20 + 140% силы заклинаний."},
	# Сильные приёмы (Base 7)
	"banner": {"hero": "marek", "name": "Знамя гильдии", "cost": 2, "mp": 50, "cast": 0.0, "cd": 40.0, "lvl": 7, "target": "self",
		"desc": "Каждый союзник получает +1 заряд ATB; весь отряд 6 с наносит на 20% больше урона."},
	"deadeye": {"hero": "elira", "name": "Выстрел в сердце", "cost": 2, "mp": 50, "cast": 1.5, "cd": 25.0, "lvl": 7, "target": "enemy",
		"desc": "Подготовка 1,5 с. 350% урона без промаха. Цель ниже 30% здоровья падает сразу (кроме главарей)."},
	"doom": {"hero": "neris", "name": "Рок", "cost": 2, "mp": 60, "cast": 0.0, "cd": 30.0, "lvl": 7, "target": "enemy", "school": "shadow",
		"desc": "Через 5 с цель получает 450% силы заклинаний тьмой; проклятая цель — в полтора раза больше."},
	"intercede": {"hero": "aiden", "name": "Заступничество", "cost": 2, "mp": 60, "cast": 0.0, "cd": 35.0, "lvl": 7, "target": "ally",
		"desc": "6 с союзник получает на 30% меньше урона и не может пасть: здоровье не опускается ниже 1."},
}
var HERO_ABILITIES := {
	"marek": ["taunt", "bash", "wall", "cleave", "banner"],
	"elira": ["aimed", "pin", "volley", "mark", "deadeye"],
	"neris": ["bolt", "curse", "hellfire", "drain", "doom"],
	"aiden": ["heal", "ward", "renew", "prayer", "intercede"],
}

# ---------------------------------------------------------------- Перки (Job Level)
# Ритм главы: этап I — после c1, этап II — после c3, этап III — после c5 (умения приходят после c2, c4 и c6).
const PERK_STAGES := {1: {"base": 2, "job": 2, "story": 1}, 2: {"base": 4, "job": 3, "story": 3}, 3: {"base": 6, "job": 4, "story": 5}}
const STAGE_NAMES := {1: "I", 2: "II", 3: "III"}
var PERKS := {
	"marek": {1: [
		{"id": "riposte", "name": "Ответный удар", "desc": "Во время провокации Марек отвечает на каждый полученный удар атакой на 60% урона оружия (не чаще раза в 0,8 с)."},
		{"id": "bulwark", "name": "Несокрушимость", "desc": "Провокация также даёт Мареку барьер на 15% его максимального здоровья."}],
		2: [
		{"id": "guardian", "name": "Страж отряда", "desc": "Стена щитов также снижает урон по всем союзникам на 20%."},
		{"id": "stunner", "name": "Оглушающий натиск", "desc": "Сбивающий удар наносит 150% урона и оглушает на 3 с, но стоит 2 ATB."}],
		3: [
		{"id": "bastion", "name": "Бастион", "desc": "Каждый блок, парирование и уклонение дают Мареку 0,3 заряда ATB вместо 0,12."},
		{"id": "warcry", "name": "Грозный рык", "desc": "Провокация бьёт всех врагов рядом на 70% урона оружия и сбивает их подготовку."}]},
	"elira": {1: [
		{"id": "predator", "name": "Охотник на хищников", "desc": "Прицельный выстрел наносит +60% урона зверям и врагам, готовящим приём."},
		{"id": "quickdraw", "name": "Быстрая тетива", "desc": "Прицельный выстрел без подготовки, но урон 170%."}],
		2: [
		{"id": "thorns", "name": "Шипастая стрела", "desc": "Пригвождающая стрела вдобавок обездвиживает цель на 2 с и наносит 160% урона."},
		{"id": "twinmark", "name": "Двойная метка", "desc": "Метка охотника перескакивает на ближайшего к цели врага."}],
		3: [
		{"id": "firstblood", "name": "Первая кровь", "desc": "В начале боя Элира получает заряд ATB, а её первый Прицельный выстрел — без подготовки."},
		{"id": "tavielsight", "name": "Глаз Тавиэля", "desc": "Прицельный выстрел по цели с Меткой охотника всегда критический."}]},
	"neris": {1: [
		{"id": "hunger", "name": "Голодное проклятие", "desc": "Урон проклятия удвоен; если проклятый враг гибнет, Нэрис восстанавливает 30 маны."},
		{"id": "brittle", "name": "Хрупкость", "desc": "Проклятие также делает цель уязвимой: +15% получаемого урона."}],
		2: [
		{"id": "pact", "name": "Тёмный договор", "desc": "Стрела тьмы при нехватке маны расходует здоровье Нэрис (15% максимума) вместо маны."},
		{"id": "wildfire", "name": "Пожар", "desc": "Горение от Пламени бездны длится вдвое дольше и не даёт врагам лечиться."}],
		3: [
		{"id": "unleash", "name": "Отпустить Голос", "desc": "Раз за бой, когда здоровье Нэрис падает ниже 25%: 6 с заклинания без маны и без подготовки."},
		{"id": "leash", "name": "Обуздать Голос", "desc": "Когда проклятый враг гибнет, проклятие перескакивает на ближайшего врага."}]},
	"aiden": {1: [
		{"id": "consecrate", "name": "Освящённый щит", "desc": "Исцеление цели под Щитом света сильнее на 35% и восполняет щит на 30% исходной прочности."},
		{"id": "swiftprayer", "name": "Быстрая молитва", "desc": "Подготовка Исцеления вдвое короче."}],
		2: [
		{"id": "radiance", "name": "Отражённый свет", "desc": "Когда Щит света разрушается, носитель исцеляется на 50% прочности щита."},
		{"id": "compassion", "name": "Сострадание", "desc": "Обновление одновременно накладывается на самого раненого союзника."}],
		3: [
		{"id": "lastrite", "name": "Последний обряд", "desc": "Раз за бой павший союзник тут же поднимается с 30% здоровья (если Эйден на ногах)."},
		{"id": "dawn", "name": "Рассвет", "desc": "Молитва исцеления снимает с отряда горение и яды и даёт каждому Щит света вполсилы."}]},
}

# ---------------------------------------------------------------- Предметы
# Основы: тип, слот, требования, базовые параметры, цена. Числа масштабируются уровнем предмета.
var BASES := {
	# Оружие
	"sword_rusty": {"name": "Ржавый меч", "slot": "main", "wtype": "sword", "hands": 1, "dmg": [8, 12], "interval": 2.0, "range": 75, "price": 30, "req": {"str": 10}, "minlvl": 1},
	"sword_watch": {"name": "Меч дозорного", "slot": "main", "wtype": "sword", "hands": 1, "dmg": [11, 16], "interval": 2.0, "range": 75, "price": 70, "req": {"str": 16}, "minlvl": 2},
	"sword_knight": {"name": "Рыцарский клинок", "slot": "main", "wtype": "sword", "hands": 1, "dmg": [14, 20], "interval": 2.1, "range": 80, "price": 140, "req": {"str": 24}, "minlvl": 5},
	"mace_iron": {"name": "Железная булава", "slot": "main", "wtype": "mace", "hands": 1, "dmg": [11, 17], "interval": 2.4, "range": 70, "price": 55, "req": {"str": 12}, "minlvl": 1},
	"dagger_skin": {"name": "Свежевальный нож", "slot": "main", "wtype": "dagger", "hands": 1, "dmg": [6, 9], "interval": 1.5, "range": 65, "price": 35, "req": {"agi": 10}, "minlvl": 1},
	"bow_hunt": {"name": "Охотничий лук", "slot": "main", "wtype": "bow", "hands": 2, "dmg": [9, 14], "interval": 2.4, "range": 620, "price": 40, "req": {"agi": 12}, "minlvl": 1},
	"bow_long": {"name": "Длинный тисовый лук", "slot": "main", "wtype": "bow", "hands": 2, "dmg": [13, 19], "interval": 2.6, "range": 700, "price": 110, "req": {"agi": 20}, "minlvl": 3},
	"staff_novice": {"name": "Посох послушника", "slot": "main", "wtype": "staff", "hands": 2, "dmg": [7, 11], "interval": 2.8, "range": 360, "price": 35, "req": {"int": 12}, "sp": 4, "minlvl": 1},
	"staff_sun": {"name": "Солнечный посох", "slot": "main", "wtype": "staff", "hands": 2, "dmg": [9, 13], "interval": 2.8, "range": 370, "price": 120, "req": {"int": 22}, "sp": 10, "minlvl": 3},
	"staff_amethyst": {"name": "Посох с аметистом", "slot": "main", "wtype": "staff", "hands": 2, "dmg": [10, 14], "interval": 2.8, "range": 370, "price": 120, "req": {"int": 22}, "sp": 10, "minlvl": 3},
	"shield_wood": {"name": "Деревянный щит", "slot": "off", "wtype": "shield", "armor": 70, "block": 12, "block_val": 8, "price": 30, "req": {"str": 10}, "minlvl": 1},
	"shield_iron": {"name": "Окованный щит", "slot": "off", "wtype": "shield", "armor": 120, "block": 16, "block_val": 14, "price": 90, "req": {"str": 18}, "minlvl": 3},
	# Украшения
	"amulet_bone": {"name": "Костяной амулет", "slot": "neck", "atype": "jewel", "price": 40, "req": {}, "minlvl": 1},
	"amulet_sun": {"name": "Солнечный медальон", "slot": "neck", "atype": "jewel", "price": 80, "req": {}, "minlvl": 3},
	"ring_copper": {"name": "Медное кольцо", "slot": "ring", "atype": "jewel", "price": 30, "req": {}, "minlvl": 1},
	"ring_silver": {"name": "Серебряное кольцо", "slot": "ring", "atype": "jewel", "price": 70, "req": {}, "minlvl": 3},
}
# Броня генерируется по слоту и типу
const ARMOR_NAMES := {
	"cloth": {"head": "Капюшон", "chest": "Ряса", "hands": "Перчатки из льна", "waist": "Кушак", "feet": "Сандалии"},
	"leather": {"head": "Кожаный капюшон", "chest": "Кожаная куртка", "hands": "Кожаные наручи", "waist": "Охотничий пояс", "feet": "Кожаные сапоги"},
	"mail": {"head": "Кольчужный капюшон", "chest": "Кольчуга", "hands": "Кольчужные рукавицы", "waist": "Пояс с бляхами", "feet": "Кольчужные сапоги"},
	"plate": {"head": "Шлем", "chest": "Кираса", "hands": "Латные перчатки", "waist": "Латный пояс", "feet": "Латные сапоги"},
}
# Броня в масштабе Classic WoW (нагрудник ур. 1: ткань ~20, кожа ~40, кольчуга ~70, латы ~105)
const ARMOR_BASE := {"cloth": 15, "leather": 30, "mail": 50, "plate": 75}
const SLOT_ARMOR_MULT := {"head": 0.8, "chest": 1.4, "hands": 0.6, "waist": 0.5, "feet": 0.7}
const ARMOR_REQ := {"cloth": {}, "leather": {"agi": 9}, "mail": {"str": 14}, "plate": {"str": 20}}
const ARMOR_PRICE := {"cloth": 18, "leather": 24, "mail": 34, "plate": 44}

func _init() -> void:
	for t in ARMOR_NAMES.keys():
		for s in ARMOR_NAMES[t].keys():
			var id: String = "%s_%s" % [t, s]
			BASES[id] = {"name": ARMOR_NAMES[t][s], "slot": s, "atype": t,
				"armor_t": ARMOR_BASE[t] * SLOT_ARMOR_MULT[s], "price": int(ARMOR_PRICE[t] * (1.0 + SLOT_ARMOR_MULT[s])),
				"req": ARMOR_REQ[t].duplicate(), "minlvl": 1 if t != "plate" else 2}

# Случайные свойства: [стат, мин на ур.1, прирост за уровень предмета]
const AFFIXES := [
	["sta", 2.0, 0.9], ["str", 2.0, 0.8], ["agi", 2.0, 0.8], ["int", 2.0, 0.8],
	["armor", 25.0, 12.0], ["crit", 1.0, 0.25], ["hit", 1.0, 0.2], ["dodge", 1.0, 0.2],
	["parry", 1.0, 0.25], ["block", 1.0, 0.3], ["sp", 3.0, 1.2],
	["res_fire", 4.0, 1.5], ["res_shadow", 4.0, 1.5], ["res_nature", 4.0, 1.5],
]
const AFFIX_PREFIX := {
	"sta": "Стойкий", "str": "Могучий", "agi": "Ловкий", "int": "Мудрый", "armor": "Прочный",
	"crit": "Острый", "hit": "Меткий", "dodge": "Вёрткий", "parry": "Фехтовальный", "block": "Надёжный",
	"sp": "Колдовской", "res_fire": "Огнеупорный", "res_shadow": "Освящённый", "res_nature": "Лесной",
}

# Расходники и походные вещи
var CONSUMABLES := {
	"potion_hp": {"name": "Лечебное зелье", "price": 25, "desc": "Восстанавливает 45% здоровья живому союзнику. Тратит 1 ATB действующего героя, не тратит ману. Не воскрешает."},
	"potion_mp": {"name": "Зелье маны", "price": 30, "desc": "Восстанавливает 45% маны живому союзнику. Тратит 1 ATB действующего героя."},
	"kit": {"name": "Ремонтный комплект", "price": 20, "desc": "Нужен для починки повозки. Ремонт временно выводит героя из боя."},
}
var GIFTS := {
	"apple": {"name": "Яблоки", "price": 6, "desc": "Хрусткие яблоки из сада у мельницы."},
	"berries": {"name": "Лесные ягоды", "price": 8, "desc": "Корзинка земляники и черники."},
	"wine": {"name": "Красное вино", "price": 18, "desc": "Бутылка недорогого, но честного вина."},
	"bread": {"name": "Медовый хлеб", "price": 5, "desc": "Тёплый хлеб с мёдом из пекарни Ольги."},
	"tea": {"name": "Травяной чай", "price": 7, "desc": "Мята, чабрец и шиповник."},
	"book": {"name": "Потрёпанная книга стихов", "price": 15, "desc": "Сборник баллад о странствующих рыцарях."},
}
var PREFERENCES := {"marek": "apple", "elira": "berries", "neris": "wine"}
# Что ещё неплохо принимает каждый (небольшой плюс)
var LIKES_OK := {"marek": ["bread", "tea"], "elira": ["tea", "apple"], "neris": ["book", "berries"]}

# ---------------------------------------------------------------- Враги
# Шкала Classic WoW: уровень контракта L соответствует уровню WoW 2L+3 (L1 → 5, L4 → 11, L7 → 17).
# Здоровье и урон обычного моба берутся из таблиц Classic по уровню WoW, у типа врага — множители.
# rank: normal — обычный моб, elite — элитный (как в подземельях), boss — босс подземелья (+уровни).
# wow — ближайший аналог из Classic WoW.
const MOB_HP := [42, 55, 71, 86, 102, 120, 137, 156, 176, 198, 222, 247, 273, 300, 328,
	356, 386, 417, 449, 484, 521, 555, 596, 636, 680, 725, 770, 820, 870, 920]
const RANK := {
	"normal": {"hp": 1.0, "dmg": 1.0, "lvl": 0},
	"elite": {"hp": 2.6, "dmg": 1.5, "lvl": 1},
	"boss": {"hp": 5.5, "dmg": 2.2, "lvl": 2},
}
## Чемпионы — именные враги со свойством (поле champion у боя в CONTRACTS).
## Общие множители: здоровье ×1,8, урон ×1,25, опыт ×2, монеты ×4; за победу — дополнительная вещь.
const CHAMPION := {"hp": 1.8, "dmg": 1.25, "xp": 2, "coins": 4}
const CHAMPION_AFFIXES := {
	"stone": {"name": "Каменная кожа", "desc": "Здоровье ещё ×1,6, броня ×2."},
	"swift": {"name": "Быстрый", "desc": "Бьёт и бегает на 50% быстрее."},
	"vampire": {"name": "Вампир", "desc": "Исцеляется на 60% нанесённого урона."},
	"fiery": {"name": "Огненный", "desc": "Удары поджигают цель: горение 6 с."},
}
var ENEMIES := {
	"wolf": {"name": "Волк", "wow": "Prowler / Timber Wolf", "rank": "normal", "hp_k": 0.9, "dmg_k": 1.0, "armor_k": 0.8,
		"interval": 1.6, "range": 60, "speed": 170, "xp": 6, "coins": 2, "tags": ["beast"], "dodge": 8, "look": "wolf"},
	"wolf_alpha": {"name": "Вожак стаи", "wow": "Coyote Packleader (элитный)", "rank": "elite", "hp_k": 1.0, "dmg_k": 1.2, "armor_k": 1.2,
		"interval": 1.7, "range": 65, "speed": 160, "xp": 24, "coins": 8, "tags": ["beast", "elite"], "dodge": 8, "look": "wolf_alpha",
		"skill": {"id": "howl", "name": "Вой стаи", "cast": 2.2, "cd": 14.0}},
	"bandit": {"name": "Разбойник", "wow": "Defias Bandit", "rank": "normal", "hp_k": 1.0, "dmg_k": 1.0, "armor_k": 1.8,
		"interval": 2.0, "range": 70, "speed": 105, "xp": 8, "coins": 4, "tags": ["human"], "parry": 5, "look": "bandit"},
	"raider": {"name": "Налётчик", "wow": "Defias Footpad", "rank": "normal", "hp_k": 0.9, "dmg_k": 1.0, "armor_k": 1.4,
		"interval": 1.8, "range": 70, "speed": 120, "xp": 8, "coins": 4, "tags": ["human", "raider"], "look": "raider"},
	"archer": {"name": "Лучник-разбойник", "wow": "Defias Smuggler", "rank": "normal", "hp_k": 0.85, "dmg_k": 0.9, "armor_k": 1.0,
		"interval": 2.4, "range": 380, "speed": 95, "xp": 9, "coins": 4, "tags": ["human", "ranged"], "look": "archer",
		"skill": {"id": "volley", "name": "Залп", "cast": 2.0, "cd": 12.0}},
	"brute": {"name": "Громила", "wow": "Defias Enforcer (элитный)", "rank": "elite", "hp_k": 1.0, "dmg_k": 1.0, "armor_k": 2.4,
		"interval": 2.6, "range": 75, "speed": 85, "xp": 18, "coins": 8, "tags": ["human", "elite"], "look": "brute",
		"skill": {"id": "smash", "name": "Сокрушающий удар", "cast": 2.4, "cd": 10.0}},
	"healer": {"name": "Знахарь банды", "wow": "Riverpaw Mystic", "rank": "normal", "hp_k": 0.85, "dmg_k": 0.6, "armor_k": 0.9,
		"interval": 2.6, "range": 320, "speed": 90, "xp": 11, "coins": 5, "tags": ["human", "ranged", "caster"], "look": "healer", "school": "nature",
		"skill": {"id": "mend", "name": "Перевязка", "cast": 2.2, "cd": 9.0}},
	"arsonist": {"name": "Поджигатель", "wow": "Defias Pillager", "rank": "normal", "hp_k": 0.9, "dmg_k": 0.8, "armor_k": 1.2,
		"interval": 2.0, "range": 70, "speed": 110, "xp": 11, "coins": 5, "tags": ["human", "arsonist"], "look": "arsonist",
		"skill": {"id": "ignite", "name": "Поджог", "cast": 3.0, "cd": 12.0}},
	"captain": {"name": "Ганс Рыжий", "wow": "Mr. Smite (босс Мертвых копей)", "rank": "boss", "hp_k": 1.0, "dmg_k": 1.0, "armor_k": 2.4,
		"interval": 2.0, "range": 80, "speed": 100, "xp": 90, "coins": 45, "tags": ["human", "boss"], "parry": 8, "look": "captain",
		"skill": {"id": "whirl", "name": "Вихрь клинков", "cast": 2.6, "cd": 13.0}},
}

## Общие множители для всех врагов, % (меню баланса F10 → «Типы врагов»)
var enemy_hp_pct := 100
var enemy_dmg_pct := 100

## Уровень по шкале Classic WoW для уровня героя/контракта
func wow_level(lvl: int) -> int:
	return 2 * lvl + 3

## Здоровье обычного моба Classic данного уровня WoW
func mob_hp(w: int) -> float:
	var i: int = clamp(w, 1, MOB_HP.size()) - 1
	return float(MOB_HP[i]) + (max(0, w - MOB_HP.size()) * 50.0)

## Средний урон удара обычного моба Classic (оружие 2,0 с)
func mob_hit(w: int) -> float:
	return 1.5 * w + 2.0

## Итоговые параметры врага на уровне контракта
func enemy_stats(t: String, lvl: int) -> Dictionary:
	var e: Dictionary = ENEMIES[t]
	var rk: Dictionary = RANK[e.get("rank", "normal")]
	var w: int = wow_level(lvl) + int(rk["lvl"])
	var hp: float = round(mob_hp(w) * float(rk["hp"]) * float(e["hp_k"]) * enemy_hp_pct / 100.0)
	var hit: float = mob_hit(w) * float(rk["dmg"]) * float(e["dmg_k"]) * float(e["interval"]) / 2.0 * enemy_dmg_pct / 100.0
	return {"wlvl": w, "hp": hp, "dmg_min": round(hit * 0.8), "dmg_max": round(hit * 1.2),
		"armor": round(20.0 * w * float(e["armor_k"])), "sp": 4.0 + 2.0 * w}

# ---------------------------------------------------------------- Цели
# Общие дополнительные поручения
var GENERAL_OBJECTIVES := {
	"no_ko": {"name": "Все возвращаются", "desc": "Ни один герой не падает в походе.", "coins": 40, "jxp": 40},
	"few_potions": {"name": "Бережливость", "desc": "Израсходовать не больше 2 зелий.", "coins": 35, "jxp": 35},
	"helpful": {"name": "Помощь встречным", "desc": "Помочь людям хотя бы в одном дорожном событии.", "coins": 25, "jxp": 40},
	"thrift": {"name": "Полный кошелёк", "desc": "Вернуть из похода не меньше монет, чем взяли.", "coins": 30, "jxp": 35},
	"wagon80": {"name": "Обоз ≥80%", "desc": "Повозка доходит, сохранив не меньше 80% прочности.", "coins": 50, "jxp": 45},
	"gate60": {"name": "Крепкие ворота", "desc": "Ворота заставы сохраняют ≥60% прочности.", "coins": 50, "jxp": 45},
	"fast_boss": {"name": "Быстрая расправа", "desc": "Победить главаря быстрее 100 секунд боя.", "coins": 45, "jxp": 45},
}
# Личные дополнительные поручения
var PERSONAL_OBJECTIVES := {
	"marek": [
		{"id": "tank", "name": "Принять удар", "desc": "Марек принимает 450 урона (до брони).", "stat": "dmg_taken", "goal": 450},
		{"id": "taunts", "name": "Держать внимание", "desc": "Марек 4 раза применяет Провокацию.", "stat": "taunts", "goal": 4}],
	"elira": [
		{"id": "kills", "name": "Охотничий счёт", "desc": "Элира добивает 6 врагов.", "stat": "kills", "goal": 6},
		{"id": "interrupts", "name": "Сорвать замысел", "desc": "Отряд прерывает 3 вражеские подготовки (Элира — хотя бы одну).", "stat": "interrupts", "goal": 3}],
	"neris": [
		{"id": "curses", "name": "Шёпот проклятий", "desc": "Нэрис накладывает 5 проклятий.", "stat": "curses", "goal": 5},
		{"id": "spell", "name": "Тёмный счёт", "desc": "Нэрис наносит 900 урона заклинаниями.", "stat": "spell_dmg", "goal": 900}],
	"aiden": [
		{"id": "healing", "name": "Рука помощи", "desc": "Эйден восстанавливает союзникам 700 здоровья.", "stat": "healing", "goal": 700},
		{"id": "wards", "name": "Свет над всеми", "desc": "Эйден ставит 5 Щитов света.", "stat": "wards", "goal": 5}],
}

# ---------------------------------------------------------------- Контракты
# Время суток: каждый пункт маршрута — часть суток (утро → день → вечер), привал — ночь, после него утро.
# "start_time" поручения — время первого пункта, "time" пункта — явное время (см. scripts/core/DayTime.gd).
# nodes: тип узла и данные. battle.groups — массив волн-групп. ambush — волки из кустов в спину.
# Враг в группе — "wolf" (уровень поручения) или ["wolf", 3] (свой уровень). hp_pct / dmg_pct — множители точки, %.
# Волны, уровни и множители переопределяются файлом data/balance.json (меню баланса F10, см. scripts/core/Balance.gd).
var CONTRACTS := {
	"c1": {"name": "Первый лесной тракт", "story": 1, "requires": [], "level": 1,
		"desc": "Староста Берта просит расчистить тракт к Ольховому Броду: волки нападают на путников у Старой развилки.",
		"pay": 110, "repeat_pay": 55, "premium": {"name": "Все возвращаются", "check": "no_ko", "coins": 60},
		"jxp": 100, "general": ["helpful", "few_potions"], "night": false,
		"twists": [["Засада с тыла", "Волки выскакивают из кустов и бьют задний ряд."]],
		"route": [
			{"type": "battle", "name": "Опушка", "groups": [["wolf", "wolf"], ["wolf", "wolf", "wolf"]]},
			{"type": "event", "name": "Ручей", "event": "spring"},
			{"type": "battle", "name": "Бурелом", "groups": [["wolf", "wolf", "wolf"], ["wolf", "wolf"], [["wolf", 2], ["wolf", 2]]], "ambush": [["wolf", 2], ["wolf", 2], ["wolf", 1]]},
			{"type": "camp", "name": "Привал"},
			{"type": "event", "name": "Развилка", "event": "wounded_trader"},
			{"type": "battle", "name": "Логово", "groups": [["wolf", "wolf", "wolf"], [["wolf", 2], "wolf", ["wolf", 2]], [["wolf", 2], ["wolf_alpha", 2], ["wolf", 2]]], "boss": true},
		],
		"intro": "Тракт зарос, а волки осмелели. Если гильдия справится, деревня, быть может, снова начнёт нам платить.",
		"outro": "У логова мы нашли не только кости. Ошейник с медной биркой: «Собственность К.Г.» Кто держит волков на привязи?"},
	"c2": {"name": "Запасы для Ольховки", "story": 2, "requires": ["c1"], "level": 2,
		"desc": "Хутор Ольховка отрезан. Нужно донести мешки с солью и лекарства, пока разбойники не перехватили и эти.",
		"pay": 150, "repeat_pay": 70, "premium": {"name": "Бережливость", "check": "few_potions", "coins": 60},
		"jxp": 110, "general": ["thrift", "no_ko"], "night": false,
		"twists": [["Стрелки", "Лучники держатся позади и дают залпы по площади. Сбивайте подготовку."]],
		"route": [
			{"type": "battle", "name": "Мост", "groups": [["bandit", "bandit", "archer"], ["bandit", "bandit"]]},
			{"type": "event", "name": "Сломанный мост", "event": "bridge"},
			{"type": "shop", "name": "Придорожная лавка"},
			{"type": "battle", "name": "Овраг", "groups": [["bandit", "archer", "bandit"], ["bandit", "archer", "bandit"]], "ambush": ["wolf", "wolf"]},
			{"type": "camp", "name": "Привал"},
			{"type": "battle", "name": "Ольховка", "groups": [["bandit", "archer", "bandit"], ["brute", "bandit", "archer"]], "boss": true,
				"champion": {"type": "bandit", "affix": "stone", "name": "Меченый"}},
		],
		"intro": "Соль, бинты и письма. Ольховка ждёт уже неделю.",
		"outro": "Хуторяне рассказали: долговые расписки за «охрану дороги» им приносил человек ростовщика Корнелия."},
	"c3": {"name": "Последний обоз", "story": 3, "requires": ["c2"], "level": 3, "escort": true,
		"desc": "Возчик Тимофей ведёт последний в сезоне обоз с зерном. Налётчики охотятся именно на повозки.",
		"pay": 200, "repeat_pay": 90, "premium": {"name": "Обоз ≥80%", "check": "wagon80", "coins": 80},
		"jxp": 120, "general": ["no_ko", "few_potions"], "night": false, "kits": 2,
		"twists": [["Обоз", "Налётчики бегут к повозке, поджигатели жгут её. Чините и тушите — повозка должна дойти."]],
		"route": [
			{"type": "battle", "name": "Лес", "groups": [["raider", "wolf", "raider"], ["wolf", "wolf"]], "ambush": ["wolf", "wolf"]},
			{"type": "event", "name": "Ручей", "event": "stuck_wagon"},
			{"type": "battle", "name": "Развилка", "groups": [["raider", "raider", "archer"], ["raider", "bandit", "archer"]]},
			{"type": "camp", "name": "Лагерь"},
			{"type": "shop", "name": "Застава"},
			{"type": "battle", "name": "Ущелье", "groups": [["raider", "arsonist", "raider"], ["brute", "archer", "raider"]], "boss": true},
		],
		"intro": "Обоз — это хлеб на зиму. И, если мы не ошибаемся, лакомый кусок для того, кто скупает долги голодных.",
		"outro": "Повозка дошла. Тимофей шепнул: налётчики спрашивали не про зерно, а про «бумаги с печатью старосты»."},
	"c4": {"name": "Спасение возчиков", "story": 4, "requires": ["c3"], "level": 4,
		"desc": "Трое возчиков пропали на Каменном броде. Говорят, их держат в лагере банды и требуют выкуп.",
		"pay": 230, "repeat_pay": 100, "premium": {"name": "Спасти всех", "check": "carters_all", "coins": 90},
		"jxp": 130, "general": ["helpful", "no_ko"], "night": false,
		"twists": [["Пленники", "По дороге можно освободить возчиков. Премия — за всех троих."], ["Знахарь", "Лечит своих. Его стоит убить первым."]],
		"route": [
			{"type": "battle", "name": "Брод", "groups": [["bandit", "archer", "healer"], ["bandit", "bandit", "archer"]]},
			{"type": "event", "name": "Пленник у дороги", "event": "captive_one"},
			{"type": "battle", "name": "Посты", "groups": [["bandit", "bandit", "archer"], ["archer", "bandit"]], "ambush": ["wolf", "wolf", "wolf"],
				"champion": {"type": "bandit", "affix": "vampire", "name": "Ждан Кровопийца"}},
			{"type": "camp", "name": "Привал"},
			{"type": "event", "name": "Лагерь банды", "event": "captive_camp"},
			{"type": "battle", "name": "Клетки", "groups": [["bandit", "archer", "bandit"], ["brute", "healer", "bandit", "archer"]], "boss": true},
		],
		"intro": "Выкуп — триста монет. У возчиков таких денег нет. У нас тоже. Значит, придётся иначе.",
		"outro": "Возчики узнали одного из разбойников — его видели у дома Корнелия, когда тот выдавал «займы на охрану»."},
	"c5": {"name": "Ночной дозор", "story": 5, "requires": ["c4"], "level": 5, "night": true, "start_time": "night",
		"desc": "По ночам кто-то жжёт сараи на окраине. Берта просит отряд пройти дозором вдоль Ольхового тракта.",
		"pay": 250, "repeat_pay": 110, "premium": {"name": "Все возвращаются", "check": "no_ko", "coins": 90},
		"jxp": 140, "general": ["few_potions", "thrift"],
		"twists": [["Ночь", "Враги дальше 360 шагов от героев скрыты во тьме: по ним не попасть, а их лучники бьют из темноты. Сблизьтесь: приказ «К цели» (C)."]],
		"route": [
			{"type": "battle", "name": "Окраина", "groups": [["arsonist", "bandit", "bandit"], ["arsonist", "archer"]], "ambush": ["wolf", "wolf"]},
			{"type": "event", "name": "Сарай в огне", "event": "barn_fire"},
			{"type": "battle", "name": "Мельница", "groups": [["wolf", "wolf", "wolf"], ["wolf", "wolf_alpha", "wolf"]], "ambush": ["wolf"],
				"champion": {"type": "wolf", "affix": "swift", "name": "Одноухий"}},
			{"type": "camp", "name": "Ночёвка"},
			{"type": "battle", "name": "Овчарня", "groups": [["arsonist", "archer", "bandit"], ["brute", "archer", "bandit"]], "ambush": ["wolf", "wolf"], "boss": true, "time": "night"},
		],
		"intro": "Ночью лес звучит иначе. Элира говорит, что волки ходят не стаей, а будто по чьей-то указке.",
		"outro": "У поджигателя нашли расписку: «За шум у окраины — 20 монет. К.Г.» Почерк знаком всей деревне."},
	"c6": {"name": "След сборщика", "story": 6, "requires": ["c5"], "level": 6,
		"desc": "Сборщик Корнелия ходит в лес по вторникам. Проследить, куда — и не попасться.",
		"pay": 270, "repeat_pay": 120, "premium": {"name": "Полный кошелёк", "check": "thrift", "coins": 100},
		"jxp": 150, "general": ["no_ko", "helpful"],
		"twists": [],
		"route": [
			{"type": "event", "name": "Следы сапог", "event": "tracks"},
			{"type": "battle", "name": "Чаща", "groups": [["raider", "archer", "healer"], ["raider", "raider", "bandit"]], "ambush": ["wolf", "wolf"]},
			{"type": "shop", "name": "Угольщики"},
			{"type": "battle", "name": "Старый тракт", "groups": [["bandit", "arsonist", "archer"], ["brute", "bandit", "archer", "bandit"]],
				"champion": {"type": "arsonist", "affix": "fiery", "name": "Огнебород"}},
			{"type": "camp", "name": "Привал"},
			{"type": "event", "name": "Тайник", "event": "cache"},
			{"type": "battle", "name": "Ущелье Ганса", "groups": [["raider", "archer", "raider"], ["brute", "healer", "raider", "archer"]], "boss": true},
		],
		"intro": "Если сборщик приведёт нас к логову, мы узнаем, кто платит разбойникам.",
		"outro": "Сборщик передал Гансу Рыжему кошель и сказал: «Книга у тебя, не потеряй — там все наши». Долговая книга."},
	"c7": {"name": "Долговая книга", "story": 7, "requires": ["c6"], "level": 7, "chest": true,
		"desc": "Логово Ганса Рыжего. В его сундуке — долговая книга Корнелия: кому дан заём, кому заплачено за налёты.",
		"pay": 400, "repeat_pay": 150, "premium": {"name": "Книга цела", "check": "chest_safe", "coins": 150},
		"jxp": 180, "general": ["no_ko", "fast_boss"],
		"twists": [["Сундук с книгой", "Поджигатели тянутся к сундуку. Если он сгорит, премии не будет."], ["Главарь", "Ганс Рыжий крутит Вихрь клинков: отводите героев или сбивайте подготовку."]],
		"route": [
			{"type": "battle", "name": "Частокол", "groups": [["bandit", "archer", "arsonist"], ["bandit", "bandit", "archer"]], "ambush": ["wolf", "wolf"]},
			{"type": "event", "name": "Перебежчик", "event": "turncoat"},
			{"type": "battle", "name": "Двор логова", "groups": [["bandit", "raider", "archer"], ["brute", "healer", "bandit", "raider"]]},
			{"type": "camp", "name": "Последний привал"},
			{"type": "battle", "name": "Шатёр главаря", "groups": [["bandit", "archer", "arsonist"], ["captain", "healer", "bandit"]], "boss": true, "chest": true},
		],
		"intro": "Вот и всё. Либо гильдия закроется, либо закроется чья-то лавочка поприбыльнее.",
		"outro": "Книга у нас. Страница за страницей — займы, «охрана», выплаты Гансу. Корнелий Гримм наживался на каждой беде тракта."},
	"c8": {"name": "Слово в столице", "story": 8, "requires": ["c7"], "level": 7, "diplomacy": "capital", "rank": "D", "finale": true,
		"desc": "Книгу Корнелия надо отвезти в столицу и добиться, чтобы её приняли в королевской палате. Едут двое: Эйден и глава гильдии Ортвин Хейл. Боя не будет — только слова.",
		"pay": 200, "repeat_pay": 0, "premium": {"name": "Триумф при дворе", "check": "diplo_triumph", "coins": 150},
		"jxp": 150, "general": [],
		"twists": [["Дипломатия", "Вместо боёв — разговоры. Варианты ответа проверяют социальные черты: d20 + черта против КС.\nЕсли у напарника эта черта 3 и выше, он помогает: бросаются два кубика, берётся лучший."],
			["Двое", "Эйден и глава гильдии Ортвин Хейл. Остальные ждут в Ольховом Броде."]],
		"route": [
			{"type": "talk", "name": "Медные ворота"},
			{"type": "talk", "name": "Канцелярия"},
			{"type": "talk", "name": "Храм"},
			{"type": "talk", "name": "Пир у графа", "time": "night"},
			{"type": "talk", "name": "Палата", "time": "morning"},
		],
		"intro": "Книга у нас. Но пока её не прочтут в столице, это просто тетрадь с цифрами.",
		"outro": "Обратная дорога кажется короче. Ортвин дремлет в телеге, прижимая к груди грамоту."},
	# Побочный
	"s1": {"name": "Оборона лесной заставы", "story": 0, "requires": ["c3"], "level": 4, "outpost": true, "side": true, "start_time": "evening",
		"desc": "Лесная застава у Ущелья осталась без гарнизона. Шесть волн налётчиков; ворота должны устоять.",
		"pay": 220, "repeat_pay": 110, "premium": {"name": "Крепкие ворота", "check": "gate60", "coins": 80},
		"jxp": 120, "general": ["no_ko", "few_potions"], "materials": 4,
		"waves": [
			[["raider", "raider", "raider"]],
			[["wolf", "wolf", "wolf", "arsonist"]],
			[["bandit", "archer", "arsonist"], ["raider", "raider"]],
			[["brute", "raider", "raider"], ["archer", "bandit"]],
			[["healer", "bandit", "arsonist", "archer"], ["raider", "raider"]],
			[["brute", "arsonist", "wolf_alpha", "raider"], ["archer", "healer", "raider"]],
		],
		"intro": "Застава — это частокол, ворота и надежда, что налётчики устанут раньше нас.",
		"outro": "Шесть волн отбиты. Комендант с дальнего поста обещал прислать людей — и не забыть, кто держал ворота."},
}
const STORY_ORDER := ["c1", "c2", "c3", "c4", "c5", "c6", "c7", "c8"]

# ---------------------------------------------------------------- Социальные черты и дипломатия
# Вторичные характеристики для проверок характера (в духе DnD): d20 + значение черты против КС.
# Очки: одно за каждый Job Level героя (Job 1 — уже 1 очко), сброс бесплатный. Открываются после c7.
const SOCIAL_STATS := ["cha", "elo", "app", "lore", "faith", "ins"]
const SOCIAL_NAMES := {"cha": "Харизма", "elo": "Красноречие", "app": "Привлекательность", "lore": "Эрудиция", "faith": "Вера", "ins": "Проницательность"}
const SOCIAL_DESC := {
	"cha": "Напор и уверенность: заставить слушать, не отступить под чужим взглядом.",
	"elo": "Умение говорить: убедить, переспорить, сказать главное вовремя.",
	"app": "Обаяние и внешность: понравиться, расположить, вызвать доверие с первого взгляда.",
	"lore": "Законы, история, этикет, кто кому родня и что где написано.",
	"faith": "Писание, обряды и церковь: говорить со жрецами на их языке.",
	"ins": "Видеть ложь, страх и выгоду за вежливыми словами.",
}
const SOCIAL_MAX := 6          # потолок черты (природное + очки)
const SOCIAL_UNLOCK_STORY := 7 # черты открываются после «Долговой книги»
const SOCIAL_HELP := 3         # напарник с чертой не ниже этого помогает: бросок с преимуществом (2d20, лучший)
## Природные значения черт (характер героя)
const SOCIAL_BASE := {
	"aiden": {"cha": 1, "elo": 2, "app": 1, "lore": 2, "faith": 3, "ins": 1},
	"marek": {"cha": 2, "elo": 0, "app": 1, "lore": 1, "faith": 1, "ins": 2},
	"elira": {"cha": 1, "elo": 0, "app": 3, "lore": 1, "faith": 0, "ins": 3},
	"neris": {"cha": 2, "elo": 2, "app": 2, "lore": 2, "faith": 0, "ins": 1},
}
## Сюжетные спутники в дипломатии (не герои отряда): черты фиксированы
var STORY_NPCS := {
	"ortwin": {"name": "Ортвин", "full": "Ортвин Хейл", "title": "Глава гильдии",
		"bio": "Глава «Последнего гроша» по королевской грамоте. Сорок лет назад основал гильдию вместе с отцом Тибальдом, был писарем королевской палаты и знает законы лучше судей. Подагра давно держит его в кресле, но в столицу без подписи главы не пустят.",
		"social": {"cha": 1, "elo": 2, "app": 0, "lore": 3, "faith": 1, "ins": 2}},
}

## Дипломатические миссии. Сцена (beat): place — пункт маршрута (номер в route поручения), who — собеседник, text.
## Вариант: text, speaker (кто говорит), check {stat, dc} — проверка d20 + черта ≥ КС (20 — всегда успех, 1 — всегда провал);
## без check — ответ без броска (ok: true/false). req {premium: cid} — нужно выполненное условие.
## ok / fail: say — что произошло, favor — расположение двора, coins — деньги в казну, flag — запомнить.
## Сцена может давать бонус к броскам за флаги: bonus {flag: [число, «за что»]}.
var DIPLOMACY := {
	"capital": {
		"party": ["aiden", "ortwin"],
		"beats": [
			{"place": 0, "who": "Сержант Брун, стража Медных ворот",
				"text": "Столица встречает очередью телег и запахом дёгтя. Сержант у Медных ворот стучит алебардой по сундуку с книгой: «Пошлина с груза — двадцать монет. Или открывайте, поглядим, что вы там везёте».",
				"options": [
					{"text": "«Мы везём доказательства для палаты. Задержишь — ответишь сам»", "speaker": "aiden", "check": {"stat": "cha", "dc": 11},
						"ok": {"say": "Сержант мнётся, потом машет рукой: «Проезжайте. Я вас не видел». Слух о гильдии с важным сундуком бежит впереди вас.", "favor": 1},
						"fail": {"say": "«Все так говорят». Пришлось платить пошлину под смешки очереди.", "coins": -20}},
					{"text": "«Статут о гильдиях, статья третья: свои бумаги гильдия везёт без пошлины»", "speaker": "ortwin", "check": {"stat": "lore", "dc": 11},
						"ok": {"say": "Сержант не хочет слушать статью целиком. Он пропускает вас и даже отдаёт старику честь.", "favor": 1},
						"fail": {"say": "Ортвин путает номер статьи. Сержант это замечает и с удовольствием берёт пошлину.", "coins": -20}},
					{"text": "Заплатить пошлину", "answer": true,
						"ok": {"say": "Медяки звякают в кружке сержанта. Ворота открыты.", "coins": -20}},
				]},
			{"place": 1, "who": "Мэтр Флавий, секретарь лорда-казначея",
				"text": "Секретарь не поднимает глаз от бумаг: «„Последний грош“? Ваша грамота подписана покойным королём. Покойным, господа. Прошений от несуществующих гильдий я не принимаю».",
				"options": [
					{"text": "«Грамоту дают на имя главы, а не короля. Глава — я, и я жив»", "speaker": "ortwin", "check": {"stat": "lore", "dc": 13},
						"ok": {"say": "Флавий впервые поднимает глаза. «Хм. Действительно». Прошение ложится в нужную стопку.", "favor": 2},
						"fail": {"say": "Флавий сверяется с тремя томами и откладывает прошение «на рассмотрение». Ждать придётся до вечера."}},
					{"text": "«Пока здесь спорят о печатях, на тракте горят сараи»", "speaker": "aiden", "check": {"stat": "elo", "dc": 13},
						"ok": {"say": "Флавий молча выводит на прошении: «Срочно».", "favor": 2},
						"fail": {"say": "«Трогательно. Следующий». Прошение уходит в общую стопку.", "favor": -1}},
					{"text": "Похвалить безупречный почерк секретаря", "speaker": "aiden", "check": {"stat": "app", "dc": 12},
						"ok": {"say": "Флавий краснеет до ушей: «Тридцать лет никто не замечал…» Прошение он относит сам.", "favor": 1},
						"fail": {"say": "Лесть звучит как лесть. Флавий морщится, но прошение всё же берёт."}},
				]},
			{"place": 1, "who": "Мэтр Флавий, секретарь лорда-казначея",
				"text": "Флавий листает долговую книгу и останавливается на подписи под выплатами: «Две буквы. Чьи?»",
				"options": [
					{"text": "«К.Г. — Корнелий Гримм, ростовщик из Ольхового Брода»", "answer": true,
						"ok": {"say": "«Сходится с его векселями в казне», — бормочет Флавий и делает пометку.", "favor": 1}},
					{"text": "«Ганса Рыжего, главаря разбойников»", "answer": false,
						"fail": {"say": "«Разбойник, который подписывает векселя казны? Не смешите меня».", "favor": -1}},
					{"text": "«Это шифр. Мы надеялись, что вы подскажете»", "answer": false,
						"fail": {"say": "Флавий смотрит на вас, как на школяров, не выучивших урок."}},
				]},
			{"place": 2, "who": "Прелат Аврелия, храм Светлой Матери",
				"text": "Перед аудиенцией вас зовут в храм. Прелат говорит мягко: «Корнелий Гримм отстроил нам колокольню. Зачем жрецу ссорить храм с его благодетелем?»",
				"options": [
					{"text": "«„Не бери с вдовы залога“. Колокольня Гримма звонит на чужие слёзы»", "speaker": "aiden", "check": {"stat": "faith", "dc": 12},
						"ok": {"say": "Аврелия долго молчит. «Я буду в палате. И скажу то же самое».", "favor": 2, "flag": "prelate"},
						"fail": {"say": "Цитата выходит неточной. Аврелия поправляет вас — вежливо и холодно."}},
					{"text": "Понять, чего прелат боится на самом деле", "speaker": "ortwin", "check": {"stat": "ins", "dc": 13},
						"ok": {"say": "Ортвин тихо обещает, что имя храма в деле не прозвучит. «Вы понятливы, мастер Хейл. Храм не будет мешать».", "favor": 1, "flag": "prelate"},
						"fail": {"say": "Аврелия оскорблена намёком и уходит, не попрощавшись.", "favor": -1}},
					{"text": "Оставить пожертвование на нужды храма", "answer": true,
						"ok": {"say": "Монеты звенят о дно чаши. Аврелия благословляет вас — сдержанно.", "favor": 1, "coins": -30}},
				]},
			{"place": 3, "who": "Граф Ланфорд Вирт, покровитель Корнелия",
				"text": "Вечером вас зовут на пир. Граф Вирт с улыбкой отводит Эйдена к камину: «Сто монет гильдии — и книга сгорит прямо здесь. Все останутся при своих. Даже вы».",
				"options": [
					{"text": "Отказать громко, чтобы слышал весь зал", "speaker": "aiden", "check": {"stat": "cha", "dc": 14},
						"ok": {"say": "Зал замолкает. Кто-то из гостей начинает хлопать. Граф улыбается уже не так широко.", "favor": 2},
						"fail": {"say": "Голос срывается на середине фразы. Гости смеются — и не над графом.", "favor": -1}},
					{"text": "«Сжечь? Тогда сгорят и ваши страницы, граф»", "speaker": "ortwin", "check": {"stat": "ins", "dc": 13},
						"ok": {"say": "Граф бледнеет и до конца вечера больше к вам не подходит.", "favor": 1, "flag": "count_named"},
						"fail": {"say": "Граф смеётся: «Старик бредит». Возможно, так оно и есть."}},
					{"text": "Пригласить на танец графиню и расспросить её", "speaker": "aiden", "check": {"stat": "app", "dc": 13},
						"ok": {"say": "Графиня смеётся и шепчет три имени. Одно из них — её собственный муж.", "favor": 1, "flag": "count_named"},
						"fail": {"say": "Вы наступаете ей на ногу. Дважды."}},
					{"text": "Взять деньги и пообещать подумать", "answer": true,
						"ok": {"say": "Кошель тяжёлый. Ортвин отворачивается. Книгу вы, конечно, не отдали, но о взятке к утру знает весь двор.", "favor": -3, "coins": 100, "flag": "bribed"}},
				]},
			{"place": 4, "who": "Лорд-казначей Эдгар Морн, королевская палата",
				"text": "Палата. Лорд-казначей листает книгу, придворные шепчутся за колоннами. «Чем вы докажете, что это книга Гримма, а не ваша подделка?»",
				"bonus": {"prelate": [2, "прелат Аврелия на вашей стороне"], "count_named": [1, "граф Вирт молчит"]},
				"options": [
					{"text": "«Посмотрите сами: каждая страница цела, каждая выплата — его рукой»", "answer": true, "req": {"premium": "c7"},
						"ok": {"say": "Морн листает долго. Придворные перестают шептаться.", "favor": 2}},
					{"text": "«У поджигателя на окраине нашли расписку с той же подписью. Сличите почерк»", "answer": true,
						"ok": {"say": "Писари сличают почерк. Совпадает до завитка.", "favor": 1}},
					{"text": "«Векселя Гримма хранятся в вашей же казне. Сличите печати»", "speaker": "ortwin", "check": {"stat": "lore", "dc": 14},
						"ok": {"say": "Писари приносят векселя. Печать та же. Морн медленно закрывает книгу.", "favor": 2},
						"fail": {"say": "Векселей нужного года в казне не находят. Морн хмурится."}},
				]},
			{"place": 4, "who": "Лорд-казначей Эдгар Морн, королевская палата",
				"text": "Морн откладывает книгу: «Последнее слово, гильдия. Чего вы просите у короны?»",
				"bonus": {"prelate": [2, "прелат Аврелия на вашей стороне"], "count_named": [1, "граф Вирт молчит"]},
				"options": [
					{"text": "«Списать долги Ольхового Брода. Это не милость — это справедливость»", "speaker": "aiden", "check": {"stat": "elo", "dc": 14},
						"ok": {"say": "Тишина. Потом Морн кивает писарю: «Записывайте».", "favor": 2},
						"fail": {"say": "Речь выходит длинной и сбивчивой. Морн терпеливо ждёт, когда вы закончите."}},
					{"text": "«Для себя — ничего. Пусть на тракте снова будет тихо»", "speaker": "aiden", "check": {"stat": "faith", "dc": 13},
						"ok": {"say": "Прелат за колонной склоняет голову. Морн смотрит на вас иначе.", "favor": 2},
						"fail": {"say": "Слова звучат как проповедь. В палате проповеди не любят."}},
					{"text": "Перечислить статьи закона, которые нарушил Гримм", "speaker": "ortwin", "check": {"stat": "elo", "dc": 12},
						"ok": {"say": "Ортвин говорит сухо и долго. Возразить нечего.", "favor": 1},
						"fail": {"say": "Ортвин сбивается со счёта статей. Кто-то из придворных зевает."}},
				]},
		],
		## Итог по расположению двора (от лучшего)
		"outcomes": [
			{"min": 9, "id": "triumph", "name": "Триумф при дворе", "coins": 150,
				"text": "Корнелий Гримм объявлен вне закона, его векселя аннулированы. Гильдии продлена грамота — с печатью нового короля."},
			{"min": 5, "id": "success", "name": "Долги списаны", "coins": 60,
				"text": "Долги Ольхового Брода списаны. Корнелий бежал из столицы, не дождавшись приговора."},
			{"min": -99, "id": "partial", "name": "Дело отложено", "coins": 0,
				"text": "Книгу приняли «к рассмотрению». Долги заморожены, но не списаны, а Корнелий по-прежнему на свободе."},
		],
	},
}

# ---------------------------------------------------------------- Дорожные события
# Каждый выбор: text, effects (понятные последствия), req (требования)
# effects: purse, heal_pct, mana_pct, potion_hp, potion_mp, kit, gift, battle, trust, rel{pair:delta}, flag, helped, item, wagon_pct
var EVENTS := {
	"spring": {"title": "Лесной родник", "text": "Под корнями старого вяза бьёт родник. Вода ледяная и чистая. Неподалёку свежие волчьи следы.",
		"choices": [
			{"text": "Отдохнуть у воды", "fx": {"heal_pct": 20, "mana_pct": 25}, "say": "Все умылись и перевели дух. Элира наполнила фляги."},
			{"text": "Пойти по следам (бой, добыча)", "fx": {"battle": [["wolf", "wolf", "wolf"]], "purse": 25, "potion_hp": 1}, "say": "Следы вывели к разорённому тайнику охотника — и к его прежним гостям."},
			{"text": "Не задерживаться", "fx": {}, "say": "Отряд идёт дальше."}]},
	"wounded_trader": {"title": "Раненый торговец", "text": "У развилки сидит коробейник с перевязанной ногой. Волки загнали его на дерево, и он просидел там ночь.",
		"choices": [
			{"text": "Отдать лечебное зелье", "fx": {"potion_hp": -1, "trust": 3, "helped": true, "rel": {"aiden|elira": 2}}, "req": {"potion_hp": 1}, "say": "Коробейник благодарит и обещает рассказать в деревне, что гильдия ещё жива."},
			{"text": "Перевязать (Эйден тратит 30% маны)", "fx": {"mana_hero": {"aiden": -30}, "trust": 2, "helped": true, "rel": {"aiden|marek": 2}}, "say": "Эйден перевязал рану. Марек молча помог подсадить торговца на попутку."},
			{"text": "Купить у него припасы (15 мон.)", "fx": {"purse": -15, "potion_mp": 1, "gift": "bread"}, "req": {"purse": 15}, "say": "Зелье маны и медовый хлеб. Торговец доволен хотя бы этим."},
			{"text": "Пройти мимо", "fx": {"rel": {"aiden|elira": -1}}, "say": "Элира оглядывается через плечо, но молчит."}]},
	"bridge": {"title": "Сломанный мост", "text": "Мост через Ольшанку провалился. Лесорубы на том берегу кричат, что могут перекинуть бревно — за плату.",
		"choices": [
			{"text": "Заплатить лесорубам (20 мон.)", "fx": {"purse": -20}, "req": {"purse": 20}, "say": "Бревно ложится через реку. Платить неприятно, зато быстро."},
			{"text": "Чинить самим (Марек −15% ОЗ)", "fx": {"hp_hero": {"marek": -15}, "rel": {"aiden|marek": 3, "marek|neris": 1}}, "say": "Марек тащит брёвна, Нэрис неожиданно подставляет плечо. Ни один из них об этом не говорит."},
			{"text": "Искать брод (бой, монеты)", "fx": {"battle": [["bandit", "archer", "bandit"]], "purse": 30}, "say": "У брода прятались двое — с чужими кошельками."}]},
	"stuck_wagon": {"title": "Повозка в ручье", "text": "Колесо обоза увязло в илистом русле. Тимофей ругается, лошади бьются.",
		"choices": [
			{"text": "Вытащить вместе (−10% ОЗ всем)", "fx": {"heal_pct": -10, "wagon_pct": 10, "rel": {"marek|elira": 2}}, "say": "Вытащили! Тимофей подлатал борт — повозке стало лучше."},
			{"text": "Потратить ремкомплект", "fx": {"kit": -1, "wagon_pct": 15}, "req": {"kit": 1}, "say": "Новый обод, и повозка снова на ходу."},
			{"text": "Нэрис: «Я сдвину её магией» (−40% маны Нэрис)", "fx": {"mana_hero": {"neris": -40}, "rel": {"aiden|neris": 2, "marek|neris": 2}}, "say": "Фиолетовые нити обвивают колесо. Тимофей крестится, но благодарит."}]},
	"captive_one": {"title": "Пленник у дороги", "text": "Возчик Савва привязан к сосне — приманка. В кустах поблёскивают наконечники стрел.",
		"choices": [
			{"text": "Элира подкрадётся (−20% ОЗ Элиры)", "fx": {"hp_hero": {"elira": -20}, "flag": "carter1", "helped": true, "rel": {"aiden|elira": 3}}, "say": "Элира перерезала верёвки до того, как засада поняла, что приманки уже нет."},
			{"text": "Ворваться в засаду (бой)", "fx": {"battle": [["archer", "archer", "bandit", "bandit"]], "flag": "carter1", "helped": true}, "say": "Засаду разогнали. Савва жив."},
			{"text": "Не рисковать", "fx": {}, "say": "Савву уводят вглубь леса. Возможно, его ещё удастся найти в лагере."}]},
	"captive_camp": {"title": "Лагерь банды", "text": "За частоколом — клетки. Двое возчиков. Часовой пересчитывает монеты и явно не прочь заработать ещё.",
		"choices": [
			{"text": "Подкупить часового (40 мон.)", "fx": {"purse": -40, "flag": "carter2", "flag2": "carter3", "helped": true}, "req": {"purse": 40}, "say": "Ключ поворачивается тихо. Двое возчиков уходят в темноту."},
			{"text": "Нэрис наведёт сон (−50% маны Нэрис)", "fx": {"mana_hero": {"neris": -50}, "flag": "carter2", "rel": {"aiden|neris": 2, "marek|neris": 2}, "helped": true}, "say": "Часовой засыпает. Одного возчика успели вывести, второй слишком слаб — придётся отбивать."},
			{"text": "Отбить силой (бой)", "fx": {"battle": [["bandit", "bandit", "healer", "bandit"]], "flag": "carter2", "flag2": "carter3", "helped": true}, "say": "Жарко, но клетки открыты."}]},
	"barn_fire": {"title": "Сарай в огне", "text": "На окраине полыхает сарай. Внутри мычит корова, хозяйка в слезах.",
		"choices": [
			{"text": "Тушить (−15% ОЗ всем)", "fx": {"heal_pct": -15, "trust": 4, "helped": true, "rel": {"marek|elira": 2, "elira|neris": 2}}, "say": "Сарай не спасти, но корову и сено — да. Хозяйка обещает пирогов."},
			{"text": "Догнать поджигателя (бой)", "fx": {"battle": [["arsonist", "bandit", "bandit"]], "purse": 20}, "say": "Поджигатель бежал недалеко. В его котомке — монеты и чужая расписка."},
			{"text": "Отдать хозяйке зелье", "fx": {"potion_hp": -1, "trust": 3, "helped": true}, "req": {"potion_hp": 1}, "say": "Ожоги у неё на руках затягиваются. «Гильдия? Та самая, нищая? Храни вас свет»."}]},
	"tracks": {"title": "Следы сапог", "text": "Подкованные сапоги, глубокий след — человек нёс что-то тяжёлое. Элира присматривается.",
		"choices": [
			{"text": "Довериться Элире (тише, дольше)", "fx": {"mana_pct": 15, "rel": {"aiden|elira": 2}, "fact": "elira_tracks"}, "say": "«Сундучок. Окованный. Он ходит здесь каждую неделю», — шепчет Элира."},
			{"text": "Срезать путь через бурелом (бой)", "fx": {"battle": [["wolf", "wolf", "wolf", "wolf"]], "purse": 15}, "say": "Короче — да. Спокойнее — нет."}]},
	"cache": {"title": "Тайник", "text": "Под корнями дуба — тайник разбойников: монеты, бинты, бутылки с мутной жидкостью.",
		"choices": [
			{"text": "Забрать монеты (+45 мон.)", "fx": {"purse": 45}, "say": "Украденное у тракта вернётся тракту — через казну гильдии."},
			{"text": "Забрать снадобья (+2 зелья)", "fx": {"potion_hp": 1, "potion_mp": 1}, "say": "Бутылки оказались вполне сносными зельями."},
			{"text": "Оставить метку для стражи", "fx": {"trust": 4, "helped": true, "rel": {"marek|elira": 2, "aiden|marek": 2}}, "say": "Марек кивает: «Правильно. Пусть всё увидят законно»."}]},
	"turncoat": {"title": "Перебежчик", "text": "Молодой разбойник выходит с поднятыми руками. «Я знаю, где Ганс держит книгу. Только отпустите»",
		"choices": [
			{"text": "Отпустить и выслушать", "fx": {"trust": 2, "helped": true, "flag": "turncoat", "rel": {"aiden|neris": 2}}, "say": "Он рассказывает про сундук в шатре и про поджигателя, который сожжёт книгу при первой тревоге."},
			{"text": "Отдать стражникам (+30 мон. награды)", "fx": {"purse": 30, "rel": {"aiden|marek": 1, "aiden|neris": -1}}, "say": "Марек связывает парня. Нэрис отворачивается."},
			{"text": "Подкрепиться его припасами", "fx": {"heal_pct": 15, "mana_pct": 15}, "say": "Он делится хлебом и водой. Хватит на последний рывок."}]},
}

# ---------------------------------------------------------------- Разговоры на привале
# topics: условия (friend — дружба с Эйденом, story — число сюжетных контрактов), реплики, выбор.
# Выбор: friend/romance — изменения отношений с Эйденом; fact — открыть факт; status assumed/confirmed;
# pref — подсказка о предпочтении; pair — изменения между спутниками.
var FACTS := {
	"marek_guard": {"hero": "marek", "text": "Служил сержантом пограничной стражи."},
	"marek_orchard": {"hero": "marek", "text": "У матери Марека был яблоневый сад в Вальдхейме."},
	"marek_ash": {"hero": "marek", "text": "Винит себя в том, что случилось с деревней Ясеневка.", "assumed": "Кажется, Марек винит себя в чём-то из прошлого."},
	"marek_commander": {"hero": "marek", "text": "Ясеневку сдал разбойникам его командир за взятку; Марек ослушался приказа, но опоздал."},
	"elira_clan": {"hero": "elira", "text": "Родом из клана Зелёного Вереска, ушла сама."},
	"elira_mentor": {"hero": "elira", "text": "Её наставник Тавиэль погиб от капкана браконьеров.", "assumed": "Элира ищет кого-то — или что-то — на тракте."},
	"elira_tracks": {"hero": "elira", "text": "Сборщик Корнелия носит тяжёлый окованный сундучок по одной и той же тропе."},
	"elira_marks": {"hero": "elira", "text": "Метки на ошейниках волков — те же, что на капканах, убивших Тавиэля."},
	"neris_pact": {"hero": "neris", "text": "Заключила договор с «Тихим Голосом» ребёнком, чтобы пережить лихорадку."},
	"neris_money": {"hero": "neris", "text": "Отправляет почти всё жалованье в приют Святой Ивы.", "assumed": "Нэрис куда-то тратит почти всё жалованье."},
	"neris_fear": {"hero": "neris", "text": "Боится, что однажды Голос заговорит её устами при людях."},
	"neris_orphan": {"hero": "neris", "text": "Сама выросла в приюте Святой Ивы."},
}

var TOPICS := {
	"marek": [
		{"id": "m1", "title": "Почему ты остался?", "friend": -100, "story": 0,
			"lines": ["Эйден: Марек, гильдия платит медью. Почему ты не ушёл в городскую стражу?", "Марек: Я двенадцать лет был сержантом на границе. Стража — это приказы. Здесь — люди."],
			"fact": "marek_guard",
			"choices": [
				{"text": "Спасибо, что ты с нами.", "friend": 6, "say": "Марек кивает и, кажется, впервые за вечер улыбается краем губ."},
				{"text": "Нам нужен твой щит, а не сантименты.", "friend": 3, "say": "«Честно. Это я уважаю», — хмыкает он."},
				{"text": "Ты мог бы найти место лучше.", "friend": 1, "say": "«Мог бы. Не хочу», — отрезает Марек."}]},
		{"id": "m2", "title": "Запах яблок", "friend": 8, "story": 1,
			"lines": ["Марек вертит в руках дичок, сорванный у дороги.", "Марек: У матери был сад под Вальдхеймом. Осенью весь дом пах яблоками. Я на заставе по этому запаху скучал больше, чем по людям."],
			"fact": "marek_orchard", "pref": ["marek", "apple"],
			"choices": [
				{"text": "Расскажи про сад.", "friend": 5, "say": "Он рассказывает про антоновку и про то, как воровал яблоки у собственной матери."},
				{"text": "Когда-нибудь у гильдии будет свой сад.", "friend": 4, "romance": 0, "say": "«Тогда я буду его сторожить», — серьёзно отвечает Марек."}]},
		{"id": "m3", "title": "Ясеневка", "friend": 18, "story": 2,
			"lines": ["Элира упомянула сожжённую деревню у границы. Марек замолчал на весь вечер.", "Марек: Ясеневка. Не надо, Эйден. Не сейчас."],
			"fact_assumed": "marek_ash",
			"choices": [
				{"text": "Я не стану давить. Я рядом, если захочешь.", "friend": 6, "say": "Марек долго смотрит в огонь. «Спасибо»."},
				{"text": "Ты должен рассказать — мы отряд.", "friend": -2, "say": "«Должен?» Он встаёт и уходит в дозор раньше смены."}]},
		{"id": "m4", "title": "Правда о Ясеневке", "friend": 30, "story": 4,
			"lines": ["Марек: Мой командир взял деньги у разбойников и увёл заставу. Я ослушался, побежал к Ясеневке. Опоздал на час.", "Марек: Когда я вижу, как кто-то наживается на страхе людей, — это снова та ночь."],
			"fact": "marek_commander", "confirm": "marek_ash",
			"choices": [
				{"text": "Ты не опоздал сегодня. И не опоздаешь завтра.", "friend": 7, "say": "«Я держусь за эту мысль», — тихо отвечает он."},
				{"text": "Я рядом не как командир. Как тот, кому ты дорог.", "friend": 4, "romance": 8, "say": "Марек замирает, потом осторожно кладёт ладонь на твоё плечо. «Я… подумаю над этим. По-хорошему подумаю»."},
				{"text": "Корнелий ответит и за это.", "friend": 4, "say": "«Не месть, Эйден. Суд». Но кулаки у него сжаты."}]},
		{"id": "m5", "title": "Кем мы стали", "friend": 42, "story": 6,
			"lines": ["Марек: Знаешь, на заставе меня звали «Стеной». Здесь зовут по имени. Это… лучше.", "Марек: После книги что будет с гильдией?"],
			"choices": [
				{"text": "Будем жить. Вместе.", "friend": 6, "say": "«Вместе», — повторяет он, как клятву."},
				{"text": "Останься со мной, когда всё кончится.", "friend": 3, "romance": 10, "req_romance": 6, "say": "Марек не отвечает словами. Но утром у твоего мешка лежит самое красное яблоко."}]},
	],
	"elira": [
		{"id": "e1", "title": "Сколько волков?", "friend": -100, "story": 0,
			"lines": ["Элира чертит на коре зарубки.", "Элира: Двадцать три волка с весны! Раньше столько за пять лет не набиралось. Лес болен — или кто-то его травит."],
			"fact": "elira_clan",
			"choices": [
				{"text": "Ты считаешь каждого?", "friend": 4, "say": "«Каждого. Они не виноваты, что голодны. Но и люди не виноваты»."},
				{"text": "Ты лучшая охотница, что я видел.", "friend": 3, "romance": 3, "say": "Элира фыркает, но уши у неё розовеют."},
				{"text": "Почему ты ушла из клана?", "friend": 2, "say": "«Скучно сидеть в лесу, когда лес горит снаружи», — отшучивается она."}]},
		{"id": "e2", "title": "Земляника", "friend": 8, "story": 1,
			"lines": ["Элира возвращается из кустов с пригоршней ягод и измазанными пальцами.", "Элира: В клане меня звали Земляничкой. Не смейся! За лесную ягоду я продам и лук, и стрелы."],
			"pref": ["elira", "berries"],
			"choices": [
				{"text": "Земляничка. Тебе идёт.", "friend": 3, "romance": 4, "say": "«Только попробуй сказать это при Мареке», — грозит она, улыбаясь."},
				{"text": "Поделишься?", "friend": 5, "say": "Она высыпает тебе в ладонь половину. Самую спелую оставляет себе."}]},
		{"id": "e3", "title": "Кого ты ищешь?", "friend": 16, "story": 2,
			"lines": ["Элира проверяет каждый капкан на тракте, ломает и бросает в ручей.", "Элира: Это не охотничьи. Это… неважно."],
			"fact_assumed": "elira_mentor",
			"choices": [
				{"text": "Важно. Но расскажешь, когда захочешь.", "friend": 6, "say": "Элира кивает и чуть дольше обычного сидит рядом."},
				{"text": "Не трать время на железки.", "friend": -3, "say": "«Не тебе решать, на что мне тратить время», — резко отвечает она."}]},
		{"id": "e4", "title": "Тавиэль", "friend": 28, "story": 3,
			"lines": ["Элира: Мой наставник, Тавиэль, погиб в таком капкане. Не звериный — для людей. На скобах была метка: три зарубки и круг.", "Элира: Сегодня я видела ту же метку на ошейнике волка."],
			"fact": "elira_marks", "confirm": "elira_mentor",
			"choices": [
				{"text": "Мы найдём того, кто ставит эти метки.", "friend": 7, "say": "«Вместе — найдём», — твёрдо говорит Элира."},
				{"text": "Ты не одна. Я хочу быть рядом — не только в походе.", "friend": 4, "romance": 9, "say": "Элира долго молчит, а потом прячет лицо у тебя на плече. «Тогда не отставай»."},
				{"text": "Месть не вернёт Тавиэля.", "friend": 2, "say": "«Я знаю. Но она вернёт сон», — отвечает она."}]},
		{"id": "e5", "title": "После охоты", "friend": 40, "story": 6,
			"lines": ["Элира: Когда всё кончится, я покажу тебе Вересковую поляну. Туда не водят чужих.", "Элира: Ты уже не чужой. Наверное."],
			"choices": [
				{"text": "Для меня это честь.", "friend": 6, "say": "«Честь — это для рыцарей. Для меня — радость», — улыбается она."},
				{"text": "Я пойду с тобой куда угодно.", "friend": 3, "romance": 10, "req_romance": 6, "say": "Элира смеётся и целует тебя в щёку. Быстро, пока никто не видит. Нэрис, конечно, видит."}]},
	],
	"neris": [
		{"id": "n1", "title": "Рога и слухи", "friend": -100, "story": 0,
			"lines": ["Нэрис: Ну что, жрец, тоже будешь брызгать на меня святой водой? В деревне уже спорят, сколько лет мне гореть.", "Нэрис: Голос во мне — договор. Я была ребёнком, умирала от лихорадки. Он предложил. Я согласилась."],
			"fact": "neris_pact",
			"choices": [
				{"text": "Ты в отряде. Остальное — их проблема.", "friend": 6, "say": "Нэрис приподнимает бровь. «Какая неожиданная ересь»."},
				{"text": "Свет не отворачивается от тех, кто хотел жить.", "friend": 4, "romance": 2, "say": "«Красиво сказано. Почти поверила», — но голос у неё мягче."},
				{"text": "Голос опасен. Я буду следить.", "friend": -1, "say": "«Следи. Только не пугайся того, что увидишь»."}]},
		{"id": "n2", "title": "Бокал у костра", "friend": 8, "story": 1,
			"lines": ["Нэрис крутит в пальцах пустую кружку.", "Нэрис: Знаешь, чего не хватает походу? Вина. Красного, терпкого. Пусть дешёвого — главное, честного."],
			"pref": ["neris", "wine"],
			"choices": [
				{"text": "Учту. Для отчётности гильдии.", "friend": 4, "romance": 2, "say": "«Обожаю, когда со мной говорят как с расходной статьёй», — смеётся она."},
				{"text": "Тебе бы не помешало и поспать.", "friend": 2, "say": "«Сон — для тех, кому не снятся голоса»."}]},
		{"id": "n3", "title": "Куда уходят деньги", "friend": 16, "story": 2,
			"lines": ["Нэрис снова отказалась от своей доли в новых сапогах. Её подошвы прохудились насквозь.", "Нэрис: Мне хватает. Отстань."],
			"fact_assumed": "neris_money",
			"choices": [
				{"text": "Хорошо. Но если нужна помощь — скажи.", "friend": 6, "say": "Она ничего не отвечает. Но утром благодарит за кашу — впервые."},
				{"text": "Ты играешь в кости? Должна кому-то?", "friend": -3, "say": "«Должна. Всему миру», — шипит она и уходит."}]},
		{"id": "n4", "title": "Приют Святой Ивы", "friend": 26, "story": 3,
			"lines": ["Нэрис: Ладно. Я выросла в приюте Святой Ивы. Туда и отправляю жалованье. Корнелий купил их долг этой весной.", "Нэрис: Если гильдия закроется, приют закроется следом. Так что — не смей проиграть."],
			"fact": "neris_orphan", "confirm": "neris_money",
			"choices": [
				{"text": "Мы не проиграем. Ни гильдия, ни приют.", "friend": 7, "say": "«Обещания жрецов, — хмыкает Нэрис. — Ладно. Твоему верю»."},
				{"text": "Ты лучше, чем хочешь казаться.", "friend": 4, "romance": 7, "say": "«Не говори так — привыкну», — шепчет она и не отводит взгляд."},
				{"text": "Почему ты скрывала это?", "friend": 3, "say": "«Потому что добрая ведьма — это смешно, Эйден»."}]},
		{"id": "n5", "title": "Голос молчит", "friend": 38, "story": 6,
			"lines": ["Нэрис: Странно. Рядом с вами Голос тише. Я боюсь, что однажды он заговорит моим ртом при всех.", "Нэрис: Если это случится — останови меня."],
			"fact": "neris_fear",
			"choices": [
				{"text": "Я не остановлю. Я дотянусь.", "friend": 6, "say": "Нэрис смеётся — тихо, впервые без яда."},
				{"text": "Я останусь рядом, даже если он заговорит.", "friend": 3, "romance": 10, "req_romance": 6, "say": "Нэрис касается твоей руки кончиками когтей. «Опасно так говорить ведьме. Она может поверить»."}]},
	],
}

# Сцены между спутниками у костра (влияют на пары)
var PAIR_SCENES := [
	{"id": "p_marek_neris", "story": 1, "title": "Марек и Нэрис",
		"lines": ["Марек: Твоё «пламя бездны» опалило мне плащ.", "Нэрис: Ты стоял в нём. Добровольно. Как всегда."],
		"choices": [
			{"text": "Встать на сторону Марека", "pair": {"marek|neris": -2, "aiden|marek": 2, "aiden|neris": -1}, "say": "Нэрис закатывает глаза, но в следующий раз целится аккуратнее."},
			{"text": "Встать на сторону Нэрис", "pair": {"marek|neris": -1, "aiden|neris": 2, "aiden|marek": -1}, "say": "Марек ворчит, но молча штопает плащ."},
			{"text": "«Вы оба спасли друг другу жизнь сегодня»", "pair": {"marek|neris": 4}, "say": "Они переглядываются. Нэрис первой протягивает кружку."}]},
	{"id": "p_elira_neris", "story": 2, "title": "Элира и Нэрис",
		"lines": ["Элира: Нэрис, а рога у тебя тёплые? Можно потрогать?", "Нэрис: Можно. Если я потрогаю твои уши."],
		"choices": [
			{"text": "Посмеяться вместе с ними", "pair": {"elira|neris": 4, "aiden|elira": 1, "aiden|neris": 1}, "say": "Весь лагерь смеётся. Даже Марек."},
			{"text": "«Девочки, спать — завтра дозор»", "pair": {"elira|neris": 1, "aiden|marek": 1}, "say": "Марек одобрительно кивает. Девушки шепчутся до полуночи."}]},
	{"id": "p_marek_elira", "story": 3, "title": "Марек и Элира",
		"lines": ["Элира: Ты стоишь впереди, как дуб. Тебя хоть иногда кто-нибудь прикрывает?", "Марек: Ты. Каждый раз. Я слышу, как поют твои стрелы у меня над ухом."],
		"choices": [
			{"text": "«Вы лучшая пара на тракте»", "pair": {"marek|elira": 4}, "say": "Марек смущённо кашляет. Элира хлопает его по плечу: «Боевая пара, жрец!»"},
			{"text": "Промолчать и слушать", "pair": {"marek|elira": 2}, "say": "Они продолжают говорить о засадах и ветре до самой смены дозора."}]},
	{"id": "p_trio", "story": 5, "title": "Кто мы друг другу",
		"lines": ["Нэрис: Признайтесь, никто из нас не собирался задерживаться в нищей гильдии.", "Марек: Не собирался. Задержался.", "Элира: Значит, это уже не гильдия. Это… стая."],
		"choices": [
			{"text": "«Это семья»", "pair": {"marek|elira": 3, "marek|neris": 3, "elira|neris": 3}, "say": "Никто не спорит. Костёр трещит, и вечер кажется длиннее ночи."},
			{"text": "«Это гильдия. И она выстоит»", "pair": {"marek|elira": 2, "marek|neris": 2, "elira|neris": 2, "aiden|marek": 2}, "say": "Марек поднимает кружку: «За гильдию»."}]},
]

# Реакции на личный вечер
var EVENING_LINES := {
	"marek": {"love": "Марек берёт яблоко, нюхает и смеётся — по-настоящему. «Как дома». Вы говорите до рассвета о садах и заставах.",
		"ok": "Марек благодарит и делится с тобой. Тихий, спокойный вечер.",
		"meh": "Марек вежливо принимает подарок. «Спасибо. Не стоило»."},
	"elira": {"love": "«Земляника! Где ты её нашёл в такую пору?!» Элира сияет и кормит тебя ягодами с ладони, отпуская шутки про Марека.",
		"ok": "Элира с удовольствием угощается и рассказывает о лесных приметах.",
		"meh": "Элира крутит подарок в руках. «Мило. Наверное»."},
	"neris": {"love": "Нэрис разливает вино и впервые садится не напротив, а рядом. «За нищую гильдию, жрец. И за тех, кто в ней»",
		"ok": "Нэрис усмехается: «Неожиданно со вкусом». Вечер выходит тёплым.",
		"meh": "«Это… забота? Ладно, приму», — Нэрис откладывает подарок в сторону."},
}

func friend_stage(v: int) -> String:
	if v < 0: return "Холодно"
	if v < 10: return "Знакомые"
	if v < 25: return "Товарищи"
	if v < 45: return "Друзья"
	return "Близкие друзья"

func romance_stage(v: int) -> String:
	if v <= 0: return "Нет"
	if v < 8: return "Искра"
	if v < 18: return "Влечение"
	return "Влюблённость"

func hero_name(id: String) -> String:
	return HEROES[id]["name"] if HEROES.has(id) else id

func pair_key(a: String, b: String) -> String:
	var order := HERO_IDS
	if order.find(a) <= order.find(b):
		return "%s|%s" % [a, b]
	return "%s|%s" % [b, a]

func all_pairs() -> Array:
	var res := []
	for i in HERO_IDS.size():
		for j in range(i + 1, HERO_IDS.size()):
			res.append("%s|%s" % [HERO_IDS[i], HERO_IDS[j]])
	return res

func xp_to_next(level: int) -> int:
	return 50 + 45 * level

func jxp_to_next(job: int) -> int:
	return 80 + 60 * job

func consumable_name(id: String) -> String:
	if CONSUMABLES.has(id): return CONSUMABLES[id]["name"]
	if GIFTS.has(id): return GIFTS[id]["name"]
	return id
