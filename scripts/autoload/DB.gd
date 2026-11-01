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
const WEAPON_TYPE_NAMES := {"sword": "меч", "mace": "булава", "dagger": "кинжал", "bow": "лук", "staff": "посох", "shield": "щит", "axe": "топор"}

# ---------------------------------------------------------------- Герои
var HEROES := {
	"aiden": {
		"name": "Эйден", "full": "Эйден", "cls": "Жрец", "role": "Целитель, щиты света",
		"color": Color(0.95, 0.85, 0.55),
		"base": {"sta": 10, "str": 6, "agi": 7, "int": 16},
		"grow": {"sta": 4.2, "str": 0.8, "agi": 1.0, "int": 5.2},
		"weapons": ["staff"], "armors": ["cloth"],
		"affix_w": {"int": 5, "sp": 5, "sta": 3, "crit": 1.5, "dodge": 1, "armor": 1, "res_shadow": 1, "res_fire": 1, "res_nature": 1},
		"school": "holy",
		"bio": "Молодой жрец, унаследовавший от наставника, отца Тибальда, дом гильдии, долги и упрямую веру в то, что людям надо помогать — даже за медяки.",
		"likes_hint": "",
	},
	"marek": {
		"name": "Марек", "full": "Марек Вальд", "cls": "Воин", "role": "Защитник: меч и щит",
		"color": Color(0.35, 0.45, 0.75),
		"base": {"sta": 16, "str": 14, "agi": 8, "int": 5},
		"grow": {"sta": 5.4, "str": 4.6, "agi": 1.2, "int": 0.4},
		"weapons": ["sword", "mace", "axe", "shield"], "armors": ["mail", "plate"], "one_hand": true,
		"affix_w": {"str": 5, "sta": 5, "agi": 2, "armor": 3, "parry": 2.5, "block": 3, "hit": 1.5, "crit": 1, "dodge": 1.5, "res_shadow": 1, "res_fire": 1, "res_nature": 1},
		"school": "phys",
		"bio": "Бывший сержант пограничной стражи. Немногословен, встаёт первым под удар и последним садится к костру.",
	},
	"elira": {
		"name": "Элира", "full": "Элира", "cls": "Охотница", "role": "Лучница против опасных целей",
		"color": Color(0.35, 0.65, 0.35),
		"base": {"sta": 11, "str": 7, "agi": 16, "int": 7},
		"grow": {"sta": 3.2, "str": 0.8, "agi": 6.2, "int": 0.8},
		"weapons": ["bow"], "armors": ["leather"],
		"affix_w": {"agi": 5, "sta": 3, "crit": 3, "hit": 3, "str": 1, "dodge": 1.5, "armor": 1, "res_shadow": 1, "res_fire": 1, "res_nature": 1},
		"school": "phys",
		"bio": "Эльфийская охотница из лесов за Ольховым Бродом. Смеётся громко, стреляет тихо и считает каждого волка на тракте.",
	},
	"neris": {
		"name": "Нэрис", "full": "Нэрис Вейль", "cls": "Чернокнижница", "role": "Проклятия и тёмная магия",
		"color": Color(0.6, 0.35, 0.7),
		"base": {"sta": 9, "str": 5, "agi": 7, "int": 17},
		"grow": {"sta": 3.0, "str": 0.4, "agi": 1.0, "int": 6.4},
		"weapons": ["staff"], "armors": ["cloth"],
		"affix_w": {"int": 5, "sp": 5, "sta": 3, "crit": 2, "hit": 2, "dodge": 1, "armor": 1, "res_shadow": 1, "res_fire": 1, "res_nature": 1},
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
# Основы: тип, слот, базовые параметры, цена (требуемый уровень — от уровня предмета, Items.req_level). Числа масштабируются уровнем предмета.
var BASES := {
	# Оружие
	"sword_rusty": {"name": "Ржавый меч", "slot": "main", "wtype": "sword", "hands": 1, "dmg": [8, 12], "interval": 2.0, "range": 75, "price": 30, "minlvl": 1},
	"sword_watch": {"name": "Меч дозорного", "slot": "main", "wtype": "sword", "hands": 1, "dmg": [11, 16], "interval": 2.0, "range": 75, "price": 70, "minlvl": 2},
	"sword_knight": {"name": "Рыцарский клинок", "slot": "main", "wtype": "sword", "hands": 1, "dmg": [14, 20], "interval": 2.1, "range": 80, "price": 140, "minlvl": 5},
	"mace_iron": {"name": "Железная булава", "slot": "main", "wtype": "mace", "hands": 1, "dmg": [11, 17], "interval": 2.4, "range": 70, "price": 55, "minlvl": 1},
	"dagger_skin": {"name": "Свежевальный нож", "slot": "main", "wtype": "dagger", "hands": 1, "dmg": [6, 9], "interval": 1.5, "range": 65, "price": 35, "minlvl": 1},
	"bow_hunt": {"name": "Охотничий лук", "slot": "main", "wtype": "bow", "hands": 2, "dmg": [9, 14], "interval": 2.4, "range": 620, "price": 40, "minlvl": 1},
	"bow_long": {"name": "Длинный тисовый лук", "slot": "main", "wtype": "bow", "hands": 2, "dmg": [13, 19], "interval": 2.6, "range": 700, "price": 110, "minlvl": 3},
	"staff_novice": {"name": "Посох послушника", "slot": "main", "wtype": "staff", "hands": 2, "dmg": [7, 11], "interval": 2.8, "range": 360, "price": 35, "sp": 4, "minlvl": 1},
	"staff_sun": {"name": "Солнечный посох", "slot": "main", "wtype": "staff", "hands": 2, "dmg": [9, 13], "interval": 2.8, "range": 370, "price": 120, "sp": 10, "minlvl": 3},
	"staff_amethyst": {"name": "Посох с аметистом", "slot": "main", "wtype": "staff", "hands": 2, "dmg": [10, 14], "interval": 2.8, "range": 370, "price": 120, "sp": 10, "minlvl": 3},
	"shield_wood": {"name": "Деревянный щит", "slot": "off", "wtype": "shield", "armor": 70, "block": 12, "block_val": 8, "price": 30, "minlvl": 1},
	"shield_iron": {"name": "Окованный щит", "slot": "off", "wtype": "shield", "armor": 120, "block": 16, "block_val": 14, "price": 90, "minlvl": 3},
	# Украшения
	"amulet_bone": {"name": "Костяной амулет", "slot": "neck", "atype": "jewel", "price": 40, "minlvl": 1},
	"amulet_sun": {"name": "Солнечный медальон", "slot": "neck", "atype": "jewel", "price": 80, "minlvl": 3},
	"ring_copper": {"name": "Медное кольцо", "slot": "ring", "atype": "jewel", "price": 30, "minlvl": 1},
	"ring_silver": {"name": "Серебряное кольцо", "slot": "ring", "atype": "jewel", "price": 70, "minlvl": 3},
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
const ARMOR_PRICE := {"cloth": 18, "leather": 24, "mail": 34, "plate": 44}

func _init() -> void:
	_add_shades()
	_add_obelisks()
	for t in ARMOR_NAMES.keys():
		for s in ARMOR_NAMES[t].keys():
			var id: String = "%s_%s" % [t, s]
			BASES[id] = {"name": ARMOR_NAMES[t][s], "slot": s, "atype": t,
				"armor_t": ARMOR_BASE[t] * SLOT_ARMOR_MULT[s], "price": int(ARMOR_PRICE[t] * (1.0 + SLOT_ARMOR_MULT[s])),
				"minlvl": 1 if t != "plate" else 2}

## Духи зверей: те же звери, но подчинённые друиду — тёмные, с красными глазами, после гибели рассыпаются пеплом
## (тег phantom). Монет с них вдвое меньше: тела не остаётся.
const SHADES := {
	"shade_wolf": ["wolf", ["Призрачный волк", "Пепельный волк", "Тень стаи"]],
	"shade_alpha": ["wolf_alpha", ["Призрачный вожак", "Пепельный вожак", "Вожак теней"]],
	"shade_boar": ["boar", ["Призрачный кабан", "Пепельный секач", "Тень секача"]],
	"shade_lynx": ["lynx", ["Призрачная рысь", "Пепельная рысь", "Тень чащи"]],
	"shade_spider": ["spider", ["Призрачный паук", "Пепельный тенетник", "Тень гнезда"]],
	"shade_bear": ["bear", ["Призрачный медведь", "Пепельный медведь", "Тень хозяина леса"]],
}

## Обелиски пещер: неподвижные, тянут тёмную силу друида и выпускают духов своего зверя (приём «Тёмный импульс»).
## Стоят на месте 3D-обелиска уровня (fixed_x — экранный x пункта), гибель обелиска рассыпает всех духов боя.
const OBELISKS := {"obelisk_wolf": "shade_wolf", "obelisk_spider": "shade_spider", "obelisk_bear": "shade_wolf"}

func _add_obelisks() -> void:
	for id in OBELISKS.keys():
		ENEMIES[id] = {"name": "Обелиск", "names": ["Обелиск", "Древний обелиск", "Обелиск друида"], "wow": "Корень скверны (сюжетный)",
			"rank": "elite", "hp_k": 5.0, "dmg_k": 0.4, "armor_k": 1.5, "interval": 99.0, "range": 0, "speed": 0, "xp": 40, "coins": 20,
			"tags": ["object", "phantom", "elite"], "dodge": 0, "look": "obelisk", "fixed_x": 1150.0, "summon": OBELISKS[id], "story": true,
			"skills": [{"id": "pulse", "name": "Тёмный импульс", "tier": 1, "cast": 2.0, "cd": 9.0, "desc": "Выпускает двух духов."}]}

func _add_shades() -> void:
	for id in SHADES.keys():
		var e: Dictionary = ENEMIES[SHADES[id][0]].duplicate(true)
		e["names"] = SHADES[id][1]
		e["name"] = SHADES[id][1][0]
		e["tags"].append("phantom")
		e["coins"] = max(1, int(e["coins"]) / 2)
		e.erase("biome")
		ENEMIES[id] = e

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
## Ступени: тот же тип врага с уровнем становится опаснее — меняется имя и добавляется приём.
## Ступень считается по уровню самого врага (не поручения): I — ур. 1–2, II — ур. 3–4, III — ур. 5+.
const TIER_FROM := [1, 3, 5]
## biome: 1 — зелёный лес (глава 1), 2 — глухая чаща (будущий биом). Без поля — 1.
## names — имена по ступеням; skills — приёмы с полем tier (с какой ступени есть).
## У приёма cast > 0 — подготовка (её видно и можно сбить); passive — свойство, работает само.
var ENEMIES := {
	"wolf": {"name": "Волк", "names": ["Волк", "Матёрый волк", "Седой волк"], "wow": "Prowler / Timber Wolf", "rank": "normal", "hp_k": 0.9, "dmg_k": 1.0, "armor_k": 0.8,
		"interval": 1.6, "range": 60, "speed": 170, "xp": 6, "coins": 2, "tags": ["beast"], "dodge": 8, "look": "wolf",
		"skills": [
			{"id": "hamstring", "name": "Подрезать сухожилия", "tier": 2, "passive": true, "desc": "Укус иногда замедляет цель."},
			{"id": "rend", "name": "Рваная рана", "tier": 3, "passive": true, "desc": "Укус иногда вызывает кровотечение."}]},
	"wolf_alpha": {"name": "Вожак стаи", "names": ["Вожак", "Вожак стаи", "Волчий вождь"], "wow": "Coyote Packleader (элитный)", "rank": "elite", "hp_k": 1.0, "dmg_k": 1.2, "armor_k": 1.2,
		"interval": 1.7, "range": 65, "speed": 160, "xp": 24, "coins": 8, "tags": ["beast", "elite"], "dodge": 8, "look": "wolf_alpha",
		"skills": [
			{"id": "howl", "name": "Вой стаи", "tier": 1, "cast": 2.2, "cd": 14.0},
			{"id": "call", "name": "Созыв", "tier": 2, "cast": 2.5, "cd": 99.0, "once": true, "desc": "Раз за бой зовёт двух волков."},
			{"id": "packhaste", "name": "Гон", "tier": 3, "passive": true, "desc": "Вой ещё и ускоряет атаки стаи."}]},
	# Сюжетный враг кат-сцены c1: первый встреченный дух, крепче обычного. phantom — гибнет без тела, рассыпаясь пеплом.
	"red_wolf": {"name": "Красноглазый волк", "names": ["Красноглазый волк", "Красноглазый волк", "Красноглазый волк"], "wow": "Shadow Wolf (сюжетный)", "rank": "normal", "hp_k": 1.6, "dmg_k": 0.9, "armor_k": 0.8,
		"interval": 1.5, "range": 60, "speed": 190, "xp": 10, "coins": 0, "tags": ["beast", "phantom"], "dodge": 8, "look": "wolf", "story": true,
		"skills": []},
	"boar": {"name": "Кабан", "names": ["Кабан", "Секач", "Старый секач"], "wow": "Thistle Boar", "rank": "normal", "hp_k": 1.7, "dmg_k": 1.2, "armor_k": 1.6,
		"interval": 2.2, "range": 65, "speed": 120, "xp": 12, "coins": 4, "tags": ["beast"], "dodge": 3, "look": "boar",
		"skills": [
			{"id": "charge", "name": "Таран", "tier": 1, "cast": 1.1, "cd": 11.0, "desc": "Разбегается и сбивает с ног."},
			{"id": "bristle", "name": "Щетина", "tier": 2, "passive": true, "desc": "Часть урона в ближнем бою возвращается бьющему."},
			{"id": "frenzy", "name": "Ярость раненого", "tier": 3, "passive": true, "desc": "Раненый бьёт чаще."}]},
	"spider": {"biome": 2, "name": "Лесной паук", "names": ["Лесной паук", "Паук-тенетник", "Паучиха-матка"], "wow": "Forest Spider", "rank": "normal", "hp_k": 0.8, "dmg_k": 0.8, "armor_k": 0.9,
		"interval": 2.2, "range": 260, "speed": 130, "xp": 9, "coins": 3, "tags": ["beast", "ranged"], "dodge": 6, "look": "spider", "school": "nature",
		"skills": [
			{"id": "web", "name": "Паутина", "tier": 1, "cast": 1.4, "cd": 10.0, "desc": "Опутывает героя: тот не может сойти с места."},
			{"id": "venom", "name": "Яд", "tier": 2, "passive": true, "desc": "Плевки отравляют (урон природой)."},
			{"id": "brood", "name": "Кладка", "tier": 3, "passive": true, "desc": "Погибая, выпускает двух паучков."}]},
	"spiderling": {"biome": 2, "name": "Паучок", "names": ["Паучок", "Паучок", "Паучок"], "wow": "Spiderling", "rank": "normal", "hp_k": 0.3, "dmg_k": 0.45, "armor_k": 0.5,
		"interval": 1.4, "range": 55, "speed": 170, "xp": 1, "coins": 0, "tags": ["beast", "minion"], "dodge": 10, "look": "spiderling", "school": "nature",
		"skills": []},
	"lynx": {"biome": 2, "name": "Рысь", "names": ["Рысь", "Матёрая рысь", "Тень чащи"], "wow": "Prowler", "rank": "normal", "hp_k": 0.85, "dmg_k": 1.2, "armor_k": 1.0,
		"interval": 1.5, "range": 60, "speed": 190, "xp": 10, "coins": 3, "tags": ["beast"], "dodge": 12, "look": "lynx",
		"skills": [
			{"id": "stalk", "name": "Подкрадывание", "tier": 1, "passive": true, "desc": "Невидима до первого удара, бросается на задний ряд."},
			{"id": "claws", "name": "Двойной удар", "tier": 2, "passive": true, "desc": "Иногда бьёт дважды."},
			{"id": "fade", "name": "В кусты", "tier": 3, "passive": true, "desc": "После нескольких ударов снова прячется."}]},
	"bear": {"biome": 2, "name": "Медведь", "names": ["Медведь", "Бурый медведь", "Хозяин леса"], "wow": "Mangy Bear (элитный)", "rank": "elite", "hp_k": 1.15, "dmg_k": 1.05, "armor_k": 1.6,
		"interval": 2.6, "range": 75, "speed": 95, "xp": 26, "coins": 6, "tags": ["beast", "elite"], "dodge": 2, "look": "bear",
		"skills": [
			{"id": "maul", "name": "Удар лапой", "tier": 1, "cast": 1.6, "cd": 9.0, "desc": "Сильный удар, отбрасывает и оглушает."},
			{"id": "roar", "name": "Рёв", "tier": 2, "cast": 1.8, "cd": 16.0, "desc": "Герои рядом теряют ATB и слабеют."},
			{"id": "rear", "name": "На дыбы", "tier": 3, "cast": 2.2, "cd": 14.0, "desc": "Обрушивается на всех рядом."}]},
	"bandit": {"name": "Разбойник", "names": ["Разбойник", "Головорез", "Старый волк тракта"], "wow": "Defias Bandit", "rank": "normal", "hp_k": 1.0, "dmg_k": 1.0, "armor_k": 1.8,
		"interval": 2.0, "range": 70, "speed": 105, "xp": 8, "coins": 4, "tags": ["human"], "parry": 5, "look": "bandit",
		"skills": [
			{"id": "dirty", "name": "Подлый удар", "tier": 2, "cast": 1.5, "cd": 12.0, "desc": "Оглушает героя."},
			{"id": "sand", "name": "Горсть песка", "tier": 3, "cast": 1.2, "cd": 14.0, "desc": "Ослеплённый герой часто промахивается."}]},
	"raider": {"name": "Налётчик", "names": ["Налётчик", "Лихой налётчик", "Тень тракта"], "wow": "Defias Footpad", "rank": "normal", "hp_k": 0.9, "dmg_k": 1.0, "armor_k": 1.4,
		"interval": 1.8, "range": 70, "speed": 120, "xp": 8, "coins": 4, "tags": ["human", "raider"], "look": "raider",
		"skills": [
			{"id": "leap", "name": "Рывок", "tier": 2, "cast": 0.8, "cd": 14.0, "desc": "Перепрыгивает к стрелку или магу."},
			{"id": "vanish", "name": "Уход в тень", "tier": 3, "passive": true, "desc": "Раненый исчезает на несколько секунд."}]},
	"archer": {"name": "Лучник-разбойник", "names": ["Лучник-разбойник", "Стрелок", "Охотник за головами"], "wow": "Defias Smuggler", "rank": "normal", "hp_k": 0.85, "dmg_k": 0.9, "armor_k": 1.0,
		"interval": 2.4, "range": 380, "speed": 95, "xp": 9, "coins": 4, "tags": ["human", "ranged"], "look": "archer",
		"skills": [
			{"id": "volley", "name": "Залп", "tier": 1, "cast": 2.0, "cd": 12.0},
			{"id": "snipe", "name": "Прицельный выстрел", "tier": 2, "cast": 2.0, "cd": 13.0, "desc": "Сильный выстрел по самому слабо одетому герою."},
			{"id": "firearrows", "name": "Огненные стрелы", "tier": 3, "passive": true, "desc": "Залп поджигает."}]},
	"brute": {"name": "Громила", "names": ["Громила", "Кулачный боец", "Вышибала"], "wow": "Defias Enforcer (элитный)", "rank": "elite", "hp_k": 1.0, "dmg_k": 1.0, "armor_k": 2.4,
		"interval": 2.6, "range": 75, "speed": 85, "xp": 18, "coins": 8, "tags": ["human", "elite"], "look": "brute",
		"skills": [
			{"id": "smash", "name": "Сокрушающий удар", "tier": 1, "cast": 2.4, "cd": 10.0},
			{"id": "shieldbash", "name": "Удар щитом", "tier": 2, "cast": 1.0, "cd": 12.0, "desc": "Сбивает подготовку героя и оглушает."},
			{"id": "frenzy", "name": "Ярость", "tier": 3, "passive": true, "desc": "Раненый бьёт чаще."}]},
	"healer": {"biome": 2, "name": "Знахарь банды", "names": ["Знахарь банды", "Травник", "Лесной ведун"], "wow": "Riverpaw Mystic", "rank": "normal", "hp_k": 0.85, "dmg_k": 0.6, "armor_k": 0.9,
		"interval": 2.6, "range": 320, "speed": 90, "xp": 11, "coins": 5, "tags": ["human", "ranged", "caster"], "look": "healer", "school": "nature",
		"skills": [
			{"id": "mend", "name": "Перевязка", "tier": 1, "cast": 2.2, "cd": 9.0},
			{"id": "ward", "name": "Оберег", "tier": 2, "cast": 1.8, "cd": 14.0, "desc": "Щит на раненого союзника."},
			{"id": "smoke", "name": "Дурман-дым", "tier": 3, "cast": 2.2, "cd": 15.0, "desc": "Ядовитый дым по площади."}]},
	"arsonist": {"name": "Поджигатель", "names": ["Поджигатель", "Факельщик", "Красный петух"], "wow": "Defias Pillager", "rank": "normal", "hp_k": 0.9, "dmg_k": 0.8, "armor_k": 1.2,
		"interval": 2.0, "range": 70, "speed": 110, "xp": 11, "coins": 5, "tags": ["human", "arsonist"], "look": "arsonist",
		"skills": [
			{"id": "ignite", "name": "Поджог", "tier": 1, "cast": 3.0, "cd": 12.0},
			{"id": "oil", "name": "Бутыль масла", "tier": 2, "cast": 1.6, "cd": 13.0, "desc": "Огонь по площади."},
			{"id": "firepot", "name": "Горшок с маслом", "tier": 3, "passive": true, "desc": "Погибая, поджигает всех рядом."}]},
	"captain": {"name": "Ганс Рыжий", "names": ["Ганс Рыжий", "Ганс Рыжий", "Ганс Рыжий"], "wow": "Mr. Smite (босс Мертвых копей)", "rank": "boss", "hp_k": 1.0, "dmg_k": 1.0, "armor_k": 2.4,
		"interval": 2.0, "range": 80, "speed": 100, "xp": 90, "coins": 45, "tags": ["human", "boss"], "parry": 8, "look": "captain",
		"skills": [{"id": "whirl", "name": "Вихрь клинков", "tier": 1, "cast": 2.6, "cd": 13.0},
			{"id": "call", "name": "Зов чащи", "tier": 1, "cast": 2.5, "cd": 99.0, "once": true, "desc": "Раз за бой зовёт двух духов-волков."}]},
}

## Ступень врага (1–3) по его уровню
func enemy_tier(lvl: int) -> int:
	var t := 1
	for i in TIER_FROM.size():
		if lvl >= int(TIER_FROM[i]):
			t = i + 1
	return t

## Имя врага на его ступени
func enemy_name(t: String, lvl: int) -> String:
	var e: Dictionary = ENEMIES[t]
	var ns: Array = e.get("names", [])
	var ti := enemy_tier(lvl)
	return str(ns[min(ti, ns.size()) - 1]) if not ns.is_empty() else str(e["name"])

## Приёмы врага, доступные на его уровне
func enemy_skills(t: String, lvl: int) -> Array:
	var out := []
	var ti := enemy_tier(lvl)
	for sk in ENEMIES[t].get("skills", []):
		if int(sk.get("tier", 1)) <= ti:
			out.append(sk)
	return out

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
# nodes: тип узла и данные. battle.groups — массив волн-групп. ambush — звери из кустов в спину.
# Враг в группе — "wolf" (уровень поручения) или ["wolf", 3] (свой уровень). hp_pct / dmg_pct — множители точки, %.
# Волны, уровни и множители переопределяются файлом data/balance.json (меню баланса F10, см. scripts/core/Balance.gd).
var CONTRACTS := {
	"c1": {"name": "Тревожные вести", "story": 1, "requires": [], "level": 1,
		"desc": "Лес вокруг гильдии стал опасен: звери выходят к дорогам, хутора замолчали. Тимофей, что возит гильдии хлеб и молоко, не приехал на торг. Нужно расчистить тропу в его сторону.",
		"pay": 110, "repeat_pay": 55, "premium": {"name": "Все возвращаются", "check": "no_ko", "coins": 60},
		"jxp": 100, "general": ["helpful", "few_potions"], "night": false,
		"twists": [["Красные глаза", "Некоторые звери — духи: сильнее обычных и после гибели рассыпаются пеплом."], ["Засада с тыла", "Волки выскакивают из кустов и бьют задний ряд."]],
		"route": [
			{"type": "battle", "name": "Опушка", "groups": [["wolf", "wolf"], ["wolf", "shade_wolf", "wolf"]]},
			{"type": "event", "name": "Волчий родник", "event": "spring"},
			{"type": "battle", "name": "Бурелом", "groups": [["wolf", "wolf", "shade_wolf"], ["boar"], [["wolf", 2], ["wolf", 2]]], "ambush": [["wolf", 2], ["wolf", 2], ["wolf", 1]]},
			{"type": "camp", "name": "Привал"},
			{"type": "event", "name": "Развилка", "event": "wounded_trader"},
			{"type": "battle", "name": "Логово", "groups": [["wolf", "wolf", "shade_wolf"], [["wolf", 2], "shade_wolf", ["wolf", 2]], [["shade_wolf", 2], ["shade_alpha", 2], ["wolf", 2]]], "boss": true},
		],
		"intro": "Лес, что кормил гильдию, вдруг стал чужим. Сначала тропа, потом Тимофей.",
		"outro": "Вожак стаи рассыпался пеплом, как и первый волк. Тропа к хутору Тимофея свободна, но лес дальше темнее."},
	"c2": {"name": "Дорога к хутору", "story": 2, "requires": ["c1"], "level": 2,
		"desc": "Хутор Тимофея стоит в глубине леса. Звери-духи там гуще, а тропа заросла. Дойти до фермера и узнать, жив ли он.",
		"pay": 150, "repeat_pay": 70, "premium": {"name": "Бережливость", "check": "few_potions", "coins": 60},
		"jxp": 110, "general": ["thrift", "no_ko"], "night": false,
		"twists": [["Глубокий лес", "Рыси подкрадываются невидимыми, пауки опутывают паутиной. Духов здесь больше, чем живых зверей."]],
		"route": [
			{"type": "battle", "name": "Тёмный ельник", "groups": [["shade_wolf", "wolf", "wolf"], ["shade_boar"]]},
			{"type": "event", "name": "Дикий улей", "event": "hive"},
			{"type": "shop", "name": "Придорожная лавка"},
			{"type": "battle", "name": "Ручей", "groups": [["lynx", "shade_wolf"], ["shade_spider", "shade_spider"]], "ambush": ["shade_wolf", "wolf"]},
			{"type": "camp", "name": "Привал"},
			{"type": "event", "name": "Мёртвый охотник", "event": "dead_merc"},
			{"type": "battle", "name": "Хутор Тимофея", "groups": [["shade_wolf", "shade_lynx", "wolf"], ["shade_wolf", "shade_wolf"]], "boss": true,
				"champion": {"type": "shade_boar", "affix": "stone", "name": "Старый секач"}},
		],
		"intro": "Тимофей кормил нас всю зиму. Теперь наша очередь.",
		"outro": "Тимофей с дочерью Асей живы: заперлись в доме и ждали. Звери обходили хутор, но вчера к воротам приходили люди с рогатыми амулетами."},
	"c3": {"name": "Оборона хутора", "story": 3, "requires": ["c2"], "level": 3, "outpost": true, "outpost_name": "Хутор", "start_time": "evening",
		"desc": "К хутору Тимофея идут бандиты. Звери их не трогают и, похоже, идут с ними заодно. Ворота хутора должны устоять.",
		"pay": 200, "repeat_pay": 90, "premium": {"name": "Крепкие ворота", "check": "gate60", "coins": 80},
		"jxp": 120, "general": ["no_ko", "few_potions"], "materials": 4, "gate_hp": 800, "outpost_ambush": ["shade_wolf"],
		"twists": [["Оборона", "Пять волн. Бандиты и духи зверей идут вместе. Чините ворота и тушите пожары между волнами."]],
		"waves": [
			[["bandit", "bandit", "archer"]],
			[["shade_wolf", "shade_wolf", "wolf"]],
			[["bandit", "archer", "arsonist"], ["raider", "raider"]],
			[["shade_boar", "shade_wolf"], ["bandit", "bandit", "archer"]],
			[["brute", "bandit", "archer"], ["shade_wolf", "shade_wolf", "arsonist"]],
		],
		"intro": "Звери не трогают бандитов. Значит, это не просто лес сошёл с ума.",
		"outro": "Хутор отбит. Уходя, бандиты кричали, что лес сам выгонит «тёмных» — и тех, кто их прячет."},
	"c4": {"name": "Обоз Тимофея", "story": 4, "requires": ["c3"], "level": 4, "escort": true,
		"desc": "На хуторе оставаться нельзя. Тимофей грузит повозку, и отряд ведёт её к дому гильдии через лес, где ждут и бандиты, и духи.",
		"pay": 230, "repeat_pay": 100, "premium": {"name": "Обоз ≥80%", "check": "wagon80", "coins": 90},
		"jxp": 130, "general": ["helpful", "no_ko"], "night": false, "kits": 2,
		"twists": [["Обоз", "Налётчики бегут к повозке, поджигатели жгут её. Чините и тушите — повозка должна дойти."]],
		"route": [
			{"type": "battle", "name": "Лес", "groups": [["raider", "shade_wolf", "raider"], ["shade_boar"]], "ambush": ["shade_wolf", "shade_wolf"]},
			{"type": "event", "name": "Кузня", "event": "stuck_wagon"},
			{"type": "battle", "name": "Развилка", "groups": [["raider", "raider", "archer"], ["raider", "bandit", "shade_lynx"]]},
			{"type": "camp", "name": "Лагерь"},
			{"type": "shop", "name": "Застава"},
			{"type": "event", "name": "Телега в кювете", "event": "ditch_cart"},
			{"type": "battle", "name": "Ущелье", "groups": [["raider", "arsonist", "shade_wolf"], ["brute", "archer", "raider"], ["shade_alpha", "shade_wolf"]], "boss": true},
		],
		"intro": "Повозка, две лошади, Тимофей, Ася и всё, что они нажили. До гильдии — день пути.",
		"outro": "Обоз во дворе гильдии. Ася впервые за неделю смеётся. А на опушке Элира заметила чужого разведчика — он видел, куда мы пришли."},
	"c5": {"name": "Штурм на закате", "story": 5, "requires": ["c4"], "level": 5, "outpost": true, "outpost_name": "Ворота гильдии", "start_time": "evening",
		"desc": "Бандиты пришли по следу обоза. На закате они штурмуют дом гильдии: люди, лучники, поджигатели и двое главарей.",
		"pay": 250, "repeat_pay": 110, "premium": {"name": "Крепкие ворота", "check": "gate60", "coins": 90},
		"jxp": 140, "general": ["few_potions", "no_ko"], "materials": 5, "gate_hp": 1000, "outpost_ambush": [["bandit", 4]],
		"twists": [["Штурм", "Пять волн, только люди. На третьей и пятой — чемпионы. Поджигатели метят в ворота."]],
		"waves": [
			[[["bandit", 4], ["bandit", 4], ["archer", 4]]],
			[[["raider", 4], ["raider", 4], ["bandit", 4]]],
			{"groups": [[["brute", 4], ["raider", 4], ["raider", 4]], [["archer", 4], ["bandit", 4]]], "champion": {"type": "archer", "affix": "swift", "name": "Сова"}},
			{"groups": [[["brute", 4], ["bandit", 4], ["archer", 4]], [["bandit", 4], ["bandit", 4]]], "hp_pct": 90},
			{"groups": [[["brute", 4], ["arsonist", 4], ["bandit", 4]], [["archer", 4], ["bandit", 4]]], "hp_pct": 90, "champion": {"type": "brute", "affix": "stone", "name": "Ольгерд Бычья Шея"}},
		],
		"intro": "Солнце садится, в лесу загораются факелы. Их много. Тимофей с Асей — в погребе, мы — у ворот.",
		"outro": "К ночи штурм отбит. Раненый бандит рассказал, где их посёлок и кому они там молятся."},
	"c6": {"name": "Контратака", "story": 6, "requires": ["c5"], "level": 6,
		"desc": "Пока бандиты зализывают раны, отряд идёт к их посёлку. По дороге — их дозоры, духи зверей и люди, которых вожаки держат в страхе.",
		"pay": 270, "repeat_pay": 120, "premium": {"name": "Полный кошелёк", "check": "thrift", "coins": 100},
		"jxp": 150, "general": ["no_ko", "helpful"],
		"twists": [["Чужая земля", "Дозоры бандитов ходят вместе с духами. В событиях можно помочь жителям посёлка."]],
		"route": [
			{"type": "event", "name": "Охотничья вышка", "event": "tracks"},
			{"type": "battle", "name": "Чаща", "groups": [["raider", "archer", "shade_wolf"], ["raider", "raider", "bandit"]], "ambush": ["shade_boar", "shade_wolf"]},
			{"type": "event", "name": "Часовня", "event": "chapel"},
			{"type": "shop", "name": "Угольщики"},
			{"type": "battle", "name": "Старый тракт", "groups": [["bandit", "arsonist", "archer"], ["brute", "bandit", "shade_lynx", "bandit"]],
				"champion": {"type": "arsonist", "affix": "fiery", "name": "Огнебород"}},
			{"type": "camp", "name": "Привал"},
			{"type": "event", "name": "Тайник", "event": "cache"},
			{"type": "battle", "name": "Овраг у посёлка", "groups": [["raider", "archer", "raider"], ["brute", "arsonist", "shade_wolf", "archer"]], "boss": true},
		],
		"intro": "Пленный сказал: там не столько бандиты, сколько голодные. Командуют ими те, кто слышит лес.",
		"outro": "Мальчишка из посёлка вызвался провести к помосту вожака. «Ганс Рыжий говорит, что лес выбрал его. И лес его слушается»."},
	"c7": {"name": "Пепелище", "story": 7, "requires": ["c6"], "level": 7,
		"desc": "Посёлок бандитов разорён и наполовину сгорел. На помосте среди пепла — Ганс Рыжий, вожак, которому подчиняются звери. Короткий путь и тяжёлый бой.",
		"pay": 400, "repeat_pay": 150, "premium": {"name": "Быстрая расправа", "check": "fast_boss", "coins": 150},
		"jxp": 180, "general": ["no_ko", "helpful"],
		"twists": [["Вожак", "Ганс Рыжий крутит Вихрь клинков и зовёт духов-волков. Отводите героев или сбивайте подготовку."]],
		"route": [
			{"type": "battle", "name": "Частокол", "groups": [["bandit", "archer", "arsonist"], ["bandit", "bandit", "shade_wolf"]], "ambush": ["shade_wolf", "shade_wolf"]},
			{"type": "event", "name": "Перебежчик", "event": "turncoat"},
			{"type": "event", "name": "Рогатый идол", "event": "idol"},
			{"type": "battle", "name": "Помост вожака", "groups": [["bandit", "archer", "arsonist"], ["captain", "archer", "shade_alpha"]], "boss": true},
		],
		"intro": "Здесь кончается лес и начинается пепел.",
		"outro": "Ганс Рыжий мёртв. Но над пепелищем мы видели того, кто держит лес в кулаке, — друида Морвена. И он обещал вернуться."},
	"c8": {"name": "Слово в столице", "story": 8, "requires": ["c7"], "level": 7, "diplomacy": "capital", "rank": "D", "finale": true,
		"desc": "О друиде, что подчинил себе лесную живность, должны узнать при дворе. Едут двое: Эйден и глава гильдии Ортвин Хейл. Боя не будет — только слова.",
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
		"intro": "У нас есть пепел, рогатая корона Ганса и рассказ, в который трудно поверить.",
		"outro": "Обратная дорога кажется короче. Ортвин дремлет в телеге, прижимая к груди грамоту."},
	# Побочные: пещеры с обелисками
	"sc1": {"name": "Волчья нора", "story": 0, "side": true, "cave": true, "requires": ["c2"], "level": 3, "start_time": "night",
		"desc": "Элира нашла нору, из которой выходят духи-волки. В глубине — что-то, от чего у Нэрис ноют рога. Найти источник и разбить его.",
		"pay": 140, "repeat_pay": 60, "premium": {"name": "Все возвращаются", "check": "no_ko", "coins": 50},
		"jxp": 90, "general": ["no_ko", "few_potions"],
		"twists": [["Обелиск", "В глубине пещеры стоит обелиск. Он не ходит и не бьёт, но выпускает духов. Разбейте его — и все духи рассыплются."], ["Тьма", "В пещере темно: враги дальше 360 шагов от героев не видны."]],
		"route": [
			{"type": "battle", "name": "Вход в нору", "time": "night", "groups": [["shade_wolf", "shade_wolf"], ["shade_wolf", "wolf", "shade_wolf"]]},
			{"type": "battle", "name": "Кости", "time": "night", "groups": [["shade_wolf", "shade_alpha"]], "ambush": ["shade_wolf"]},
			{"type": "battle", "name": "Обелиск", "time": "night", "groups": [["obelisk_wolf", "shade_wolf", "shade_wolf"]], "boss": true},
		],
		"intro": "Нора уходит под корни старого дуба. Оттуда тянет холодом и пеплом.",
		"outro": "Обелиск рассыпался. Волки у норы больше не горят красным: живые разбежались, тени истаяли."},
	"sc2": {"name": "Паучий грот", "story": 0, "side": true, "cave": true, "requires": ["c4"], "level": 5, "start_time": "night",
		"desc": "Тимофей рассказал про грот у ручья: туда ушли пауки, а вернулись тени. Второй обелиск должен быть там.",
		"pay": 200, "repeat_pay": 80, "premium": {"name": "Бережливость", "check": "few_potions", "coins": 70},
		"jxp": 110, "general": ["no_ko", "few_potions"],
		"twists": [["Обелиск", "Обелиск выпускает духов-пауков. Разбейте его — и все духи рассыплются."], ["Тьма", "В гроте темно, рыси подкрадываются невидимыми."]],
		"route": [
			{"type": "battle", "name": "Паутина", "time": "night", "groups": [["shade_spider", "shade_spider"], ["shade_lynx", "shade_spider"]]},
			{"type": "battle", "name": "Гнездо", "time": "night", "groups": [["shade_spider", "spider", "shade_spider"], ["shade_lynx", "shade_lynx"]]},
			{"type": "battle", "name": "Обелиск", "time": "night", "groups": [["obelisk_spider", "shade_spider", "shade_lynx"]], "boss": true},
		],
		"intro": "Стены грота затянуты паутиной, в ней светятся грибы. И что-то пульсирует красным.",
		"outro": "Второй обелиск разбит. Пауки в гроте снова просто пауки — злые, но свои."},
	"sc3": {"name": "Медвежий разлом", "story": 0, "side": true, "cave": true, "requires": ["c6"], "level": 7, "start_time": "night",
		"desc": "Мальчишка из посёлка показал расщелину, куда вожаки водили людей «к хозяину леса». Там третий обелиск и тот, кто его стережёт.",
		"pay": 260, "repeat_pay": 100, "premium": {"name": "Все возвращаются", "check": "no_ko", "coins": 90},
		"jxp": 130, "general": ["no_ko", "few_potions"],
		"twists": [["Обелиск", "Обелиск выпускает духов-волков. Его стережёт призрачный медведь."], ["Тьма", "В разломе темно."]],
		"route": [
			{"type": "battle", "name": "Разлом", "time": "night", "groups": [["shade_alpha", "shade_wolf", "shade_wolf"], ["shade_bear"]]},
			{"type": "battle", "name": "Логово хозяина", "time": "night", "groups": [["shade_bear", "shade_lynx"]], "ambush": ["shade_wolf", "shade_wolf"]},
			{"type": "battle", "name": "Обелиск", "time": "night", "groups": [["obelisk_bear", "shade_wolf", "shade_wolf"]], "boss": true},
		],
		"intro": "Разлом дышит теплом, как зверь во сне. На камнях — рогатые знаки культа.",
		"outro": "Третий обелиск рассыпался. Где-то далеко в лесу кто-то закричал от злости — и голос был знаком."},
}
const STORY_ORDER := ["c1", "c2", "c3", "c4", "c5", "c6", "c7", "c8"]
## Побочные поручения: три пещеры с обелисками друида, открываются по ходу сюжета.
## Каждый разбитый обелиск ослабляет духов зверей во всех походах (Game.shade_k).
const SIDE_ORDER: Array = ["sc1", "sc2", "sc3"]

# ---------------------------------------------------------------- Кат-сцены
## Короткие сюжетные сцены прямо на дороге (проигрывает scenes/expedition/Cutscene.tscn).
## contract — поручение; node — перед каким пунктом маршрута (сцена идёт на отрезке пути к нему);
## at — доля этого отрезка, на которой отряд останавливается. Сцена показывается один раз за игру
## (Game.state.cutscenes_seen); на повторных прохождениях поручения её нет.
## Шаги (steps), по порядку:
##   {"say": "elira", "text": "…"}            — реплика над героем или актёром; "" — текст рассказчика внизу. Ждёт щелчка.
##   {"enter": "wolf", "look": "wolf_shade", "name": "…", "x": 1180, "speed": 520}
##                                             — актёр выбегает справа и встаёт в x (пиксели экрана). Ждёт, пока добежит.
##   {"anim": "aiden", "kind": "cast_release", "fx": "ward", "at": "wolf"}
##                                             — движение героя (в 3D/2D-виде) и вспышка над целью; у актёра — выпад.
##   {"wait": 0.8}                             — пауза.
##   {"cam": 1.25} / {"cam": 0}                — наезд камеры на отряд и актёров / обычный вид.
##   {"fight": [["shade_wolf"]], "actors": ["wolf"]}
##                                             — настоящий бой: актёры становятся врагами там, где стоят. После победы сцена идёт дальше.
##   {"banner": "…"}                           — крупная надпись по центру.
## Пропуск сцены проматывает шаги до ближайшего боя (бой не пропускается) или до конца.
var CUTSCENES := {
	"c1_red_eyes": {"contract": "c1", "node": 0, "at": 0.55, "steps": [
		{"say": "", "text": "Лес вокруг гильдии. Тропа в сторону хутора Тимофея."},
		{"say": "elira", "text": "Стойте. Лес замолчал. Ни птиц, ни белок."},
		{"enter": "wolf", "look": "wolf_shade", "name": "Волк", "x": 1190, "speed": 560},
		{"cam": 1.22},
		{"say": "marek", "text": "Всего лишь волк. Один. Отойдёт."},
		{"say": "elira", "text": "Посмотри на глаза. У волков таких не бывает."},
		{"say": "aiden", "text": "Тише, серый. Мы тебе не враги. Ступай своей дорогой."},
		{"anim": "aiden", "kind": "cast_release", "fx": "ward", "at": "wolf"},
		{"wait": 0.9},
		{"say": "wolf", "text": "Р-р-р-р…"},
		{"say": "neris", "text": "Не слушает. Он смотрит не на нас, а сквозь нас."},
		{"anim": "wolf"},
		{"say": "marek", "text": "Щиты! Он бросается!"},
		{"fight": [["red_wolf"]], "actors": ["wolf"]},
		{"wait": 0.8},
		{"cam": 1.22},
		{"say": "marek", "text": "Волки так не умирают."},
		{"say": "elira", "text": "Ни крови, ни шерсти. И следов на тропе нет, будто он не пришёл, а появился."},
		{"say": "neris", "text": "Это не зверь. Проекция, тень, которую кто-то отбросил на лес. И натравил её на нас."},
		{"say": "aiden", "text": "Значит, у этой беды есть хозяин. Тем важнее дойти до Тимофея."},
		{"say": "marek", "text": "Тогда держимся тропы и смотрим в оба."},
		{"cam": 0},
	]},
	"c1_end": {"contract": "c1", "node": "end", "steps": [
		{"cam": 1.2},
		{"say": "elira", "text": "Вожак тоже рассыпался. Половина этой стаи была не живой."},
		{"say": "neris", "text": "Кто-то лепит их из тени и злобы. Много и быстро."},
		{"say": "aiden", "text": "Хутор Тимофея ещё глубже в лесу. Если здесь так, что же там?"},
		{"say": "marek", "text": "Значит, завтра идём к нему."},
		{"cam": 0},
	]},
	"c2_watchers": {"contract": "c2", "node": 0, "at": 0.5, "steps": [
		{"say": "", "text": "Чем дальше от гильдии, тем темнее лес. Птиц здесь нет совсем."},
		{"enter": "w1", "look": "wolf_shade", "name": "Волк", "x": 1230, "speed": 420},
		{"enter": "w2", "look": "wolf_shade", "name": "Волк", "x": 1360, "speed": 420, "dy": -18},
		{"cam": 1.2},
		{"say": "elira", "text": "Двое. Стоят и смотрят."},
		{"say": "marek", "text": "Не нападают?"},
		{"say": "neris", "text": "Им не велели. Пока."},
		{"exit": "w1"},
		{"exit": "w2"},
		{"say": "aiden", "text": "Будто убежали кому-то сказать, что мы идём."},
		{"cam": 0},
	]},
	"c2_end": {"contract": "c2", "node": "end", "steps": [
		{"enter": "tim", "look": "farmer", "name": "Тимофей", "x": 1120, "speed": 240},
		{"cam": 1.2},
		{"say": "tim", "text": "Гильдия! Свет вас храни, я уж думал — всё."},
		{"say": "aiden", "text": "Живы? А Ася?"},
		{"say": "tim", "text": "В погребе. Звери нас не трогали, только кружили. А вчера пришли люди с рогатыми амулетами."},
		{"say": "tim", "text": "Звери перед ними расступались, как собаки перед хозяином. Сказали: к вечеру хутор должен опустеть."},
		{"say": "marek", "text": "К вечеру они и вернутся. Готовим ворота."},
		{"cam": 0},
	]},
	"c3_bandits": {"contract": "c3", "node": 0, "at": 0.55, "steps": [
		{"say": "", "text": "Вечер у хутора Тимофея. Из леса выходят люди."},
		{"enter": "b1", "look": "bandit", "name": "Бандит с амулетом", "x": 1140, "speed": 300},
		{"enter": "b2", "look": "archer", "name": "Лучница", "x": 1280, "speed": 300, "dy": -18},
		{"enter": "wolf", "look": "wolf_shade", "name": "Волк", "x": 1390, "speed": 300, "dy": 16},
		{"cam": 1.2},
		{"say": "b1", "text": "Гильдейские? Уходите. Лес не хочет вас здесь."},
		{"say": "aiden", "text": "Лес? Звери с красными глазами — это не лес."},
		{"say": "b1", "text": "Это его сила. Вы — зараза, и природа сама вас выталкивает. А нас она бережёт."},
		{"say": "neris", "text": "Бережёт, пока вы полезны. Вы просто удобные пешки в чужой игре."},
		{"say": "b2", "text": "Пешки? А вы видели, что с вашими волками? Не умирают — сгорают в пепел."},
		{"say": "b1", "text": "Это ваша тёмная сила. Она не убивает, а изгоняет из мира живых. Как в старой легенде о Пепельных."},
		{"say": "neris", "text": "Меня ещё ни разу не называли легендой. Даже приятно."},
		{"say": "b1", "text": "Хутор будет наш. А вы ляжете в пепел вместе со своими волками."},
		{"exit": "b1"},
		{"exit": "b2"},
		{"exit": "wolf"},
		{"say": "marek", "text": "К воротам. Сейчас начнётся."},
		{"cam": 0},
	]},
	"c3_end": {"contract": "c3", "node": "end", "steps": [
		{"enter": "tim", "look": "farmer", "name": "Тимофей", "x": 1080, "speed": 240},
		{"cam": 1.2},
		{"say": "tim", "text": "Ушли… Грозились, что вернутся вместе с лесом."},
		{"say": "elira", "text": "Вернутся. Оставаться здесь нельзя, Тимофей."},
		{"say": "tim", "text": "Значит, грузим повозку. Всё, что увезём."},
		{"cam": 0},
	]},
	"c4_farewell": {"contract": "c4", "node": 0, "at": 0.45, "steps": [
		{"say": "", "text": "Утро. Повозка Тимофея скрипит на лесной дороге."},
		{"say": "aiden", "text": "Тимофей, держись ближе к повозке. Ася — внутри, под мешками."},
		{"say": "marek", "text": "Тридцать лет хутору, сказал он. Дед ещё ставил."},
		{"say": "aiden", "text": "Вернётся. Когда лес снова станет лесом."},
		{"say": "elira", "text": "Впереди и люди, и звери. Глядите за повозкой, они пойдут к ней."},
	]},
	"c4_end": {"contract": "c4", "node": "end", "steps": [
		{"enter": "tim", "look": "farmer", "name": "Тимофей", "x": 1080, "speed": 240},
		{"cam": 1.2},
		{"say": "tim", "text": "Дошли! Ася, гляди — дом гильдии."},
		{"say": "marek", "text": "Элира, ты что?"},
		{"say": "elira", "text": "На опушке человек. Смотрел, куда мы свернули, и ушёл в лес."},
		{"say": "neris", "text": "Значит, скоро у нас гости."},
		{"cam": 0},
	]},
	"c5_torches": {"contract": "c5", "node": 0, "at": 0.5, "steps": [
		{"say": "", "text": "Закат. В лесу один за другим загораются факелы."},
		{"say": "marek", "text": "Ворота заперты. Тимофей с Асей в погребе."},
		{"say": "neris", "text": "Их много. И ни одного зверя рядом. Странно."},
		{"say": "aiden", "text": "Звери — для леса. А дом гильдии они хотят взять своими руками."},
		{"say": "elira", "text": "Тогда пусть попробуют."},
	]},
	"c5_end": {"contract": "c5", "node": "end", "steps": [
		{"say": "", "text": "К ночи штурм отбит."},
		{"enter": "pr", "look": "bandit", "name": "Пленный", "x": 1060, "speed": 160},
		{"cam": 1.2},
		{"say": "pr", "text": "Не убивайте! Нас гонят вожаки… Ганс Рыжий говорит, что лес выбрал его."},
		{"say": "marek", "text": "Где ваш посёлок?"},
		{"say": "pr", "text": "За Чёрным оврагом. Там голод, а вожаки молятся рогатому идолу."},
		{"say": "aiden", "text": "Значит, идём туда. Не за местью — за ответом."},
		{"cam": 0},
	]},
	"c6_boy": {"contract": "c6", "node": 0, "at": 0.5, "steps": [
		{"say": "", "text": "Земля бандитов. Пни вместо деревьев, пустые силки."},
		{"enter": "boy", "look": "farmer", "name": "Мальчишка", "x": 1130, "speed": 320},
		{"cam": 1.2},
		{"say": "boy", "text": "Вы из гильдии? Вы правда тёмные?"},
		{"say": "aiden", "text": "Мы лечим людей, а не изгоняем."},
		{"say": "boy", "text": "У нас все голодают. Вожаки забирают еду для идола. Кто спорит — того в лес, к зверям."},
		{"say": "elira", "text": "А звери?"},
		{"say": "boy", "text": "Слушаются Ганса. А Ганс — кого-то в чаще. Ночью он ходит туда один."},
		{"exit": "boy"},
		{"say": "neris", "text": "Кого-то в чаще. Вот и нить, Эйден."},
		{"cam": 0},
	]},
	"c6_end": {"contract": "c6", "node": "end", "steps": [
		{"say": "marek", "text": "Овраг взят. Дальше — их посёлок."},
		{"say": "elira", "text": "Пахнет гарью. Там что-то горело, и недавно."},
		{"say": "aiden", "text": "Пойдём, пока Ганс не собрал людей."},
	]},
	"c7_hans": {"contract": "c7", "node": 0, "at": 0.5, "steps": [
		{"say": "", "text": "Посёлок наполовину сгорел. Пепел лежит, как снег."},
		{"enter": "hans", "look": "captain", "name": "Ганс Рыжий", "x": 1230, "speed": 220},
		{"cam": 1.2},
		{"say": "hans", "text": "Пришли, тёмные! Смотрите, люди: вот кто жжёт лес и изгоняет его детей!"},
		{"say": "aiden", "text": "Твои люди голодают, Ганс. А ты отдаёшь их хлеб идолу."},
		{"say": "hans", "text": "Лес дал мне силу. Звери ложатся у моих ног. А вам он даст только пепел!"},
		{"say": "neris", "text": "Сила не твоя. Тебя держат на поводке, просто поводок длинный."},
		{"say": "hans", "text": "Хватит! На помосте и поговорим."},
		{"exit": "hans"},
		{"cam": 0},
	]},
	"c7_druid": {"contract": "c7", "node": "end", "steps": [
		{"say": "", "text": "Пепел над помостом закручивается вихрем."},
		{"enter": "druid", "look": "druid", "name": "Морвен", "x": 1180, "speed": 140},
		{"cam": 1.25},
		{"say": "druid", "text": "Ганс был полезен. Глуп, но полезен."},
		{"say": "aiden", "text": "Так это ты держишь лес."},
		{"say": "druid", "text": "Я его хозяин. Каждый зверь, каждый корень. А вы — гниль в его теле."},
		{"say": "elira", "text": "Ты травишь лес, а не бережёшь."},
		{"say": "druid", "text": "Убить меня? Попробуйте."},
		{"anim": "druid"},
		{"say": "marek", "text": "Щиты!"},
		{"vanish": "druid"},
		{"wait": 1.0},
		{"say": "", "text": "Голос звучит отовсюду: «Я не оставлю вас в покое. Ни вас, ни ваших детей. До скончания веков»."},
		{"say": "neris", "text": "Он не ушёл. Он просто стал лесом."},
		{"say": "aiden", "text": "Об этом должны узнать в столице."},
		{"cam": 0},
	]},
	"sc1_start": {"contract": "sc1", "node": 0, "at": 0.5, "steps": [
		{"say": "", "text": "Нора под корнями старого дуба. Внутри темно и пахнет пеплом."},
		{"say": "neris", "text": "Чувствуете? Как будто зуб ноет, только во всём теле. Здесь что-то тянет силу."},
		{"say": "elira", "text": "Следов много, а живых зверей ни одного."},
		{"say": "aiden", "text": "Держимся вместе. Свет — впереди."},
	]},
	"sc1_end": {"contract": "sc1", "node": "end", "steps": [
		{"say": "", "text": "Осколки обелиска гаснут один за другим."},
		{"enter": "wolf", "look": "wolf", "name": "Волк", "x": 1250, "speed": 300},
		{"cam": 1.2},
		{"say": "elira", "text": "Смотрите. Глаза обычные. Живой волк."},
		{"say": "wolf", "text": "…"},
		{"exit": "wolf", "speed": 500},
		{"say": "aiden", "text": "Его просто отпустило. Значит, зверей можно вылечить — если ломать эти камни."},
		{"say": "neris", "text": "Один из трёх. Я слышу ещё два, далеко."},
		{"cam": 0},
	]},
	"sc2_start": {"contract": "sc2", "node": 0, "at": 0.5, "steps": [
		{"say": "", "text": "Грот у ручья. Паутина от стены до стены, в ней светятся грибы."},
		{"say": "marek", "text": "Ненавижу пауков."},
		{"say": "neris", "text": "Это не пауки, Марек. Это тени пауков. Так легче?"},
		{"say": "marek", "text": "Нет."},
	]},
	"sc2_end": {"contract": "sc2", "node": "end", "steps": [
		{"say": "", "text": "Второй обелиск трескается и осыпается пеплом."},
		{"say": "elira", "text": "Паутина больше не светится. Грот стал просто гротом."},
		{"say": "aiden", "text": "Друид почувствует это. Пусть знает, что мы идём."},
	]},
	"sc3_start": {"contract": "sc3", "node": 0, "at": 0.5, "steps": [
		{"say": "", "text": "Разлом в скале. На камнях — рогатые знаки, как на тотемах бандитов."},
		{"say": "elira", "text": "Медвежьи следы. Огромные. И пепел в них."},
		{"say": "marek", "text": "Щиты вперёд. Если это медведь, он будет первым."},
	]},
	"sc3_end": {"contract": "sc3", "node": "end", "steps": [
		{"say": "", "text": "Последний обелиск рассыпается. Где-то далеко в лесу кто-то кричит от злости."},
		{"say": "neris", "text": "Он это почувствовал. И ему больно."},
		{"say": "aiden", "text": "Три из трёх. Лес снова может дышать — хотя бы здесь."},
	]},
}

## Длина маршрута поручения (у обороны — один пункт).
func route_len(cid: String) -> int:
	var c: Dictionary = CONTRACTS[cid]
	return 1 if c.get("outpost", false) else c.get("route", []).size()

## Кат-сцена, которая должна идти на отрезке пути к пункту node поручения cid ("" — нет).
## node = длина маршрута — сцена-итог после последнего пункта ("node": "end").
func cutscene_for(cid: String, node: int) -> String:
	for id in CUTSCENES.keys():
		var cs: Dictionary = CUTSCENES[id]
		var n = cs["node"]
		if typeof(n) == TYPE_STRING:
			n = route_len(cid) if n == "end" else -1
		if cs["contract"] == cid and int(n) == node:
			return id
	return ""

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
const SOCIAL_UNLOCK_STORY := 7 # черты открываются после «Пепелища»
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
				"text": "Столица встречает очередью телег и запахом дёгтя. Сержант у Медных ворот стучит алебардой по сундуку: «Пошлина с груза — двадцать монет. Или открывайте, поглядим, что вы там везёте».",
				"options": [
					{"text": "«Мы везём вести для палаты. Задержишь — ответишь сам»", "speaker": "aiden", "check": {"stat": "cha", "dc": 11},
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
					{"text": "«Пока здесь спорят о печатях, лес у Ольхового Брода сходит с ума»", "speaker": "aiden", "check": {"stat": "elo", "dc": 13},
						"ok": {"say": "Флавий молча выводит на прошении: «Срочно».", "favor": 2},
						"fail": {"say": "«Трогательно. Следующий». Прошение уходит в общую стопку.", "favor": -1}},
					{"text": "Похвалить безупречный почерк секретаря", "speaker": "aiden", "check": {"stat": "app", "dc": 12},
						"ok": {"say": "Флавий краснеет до ушей: «Тридцать лет никто не замечал…» Прошение он относит сам.", "favor": 1},
						"fail": {"say": "Лесть звучит как лесть. Флавий морщится, но прошение всё же берёт."}},
				]},
			{"place": 1, "who": "Мэтр Флавий, секретарь лорда-казначея",
				"text": "Флавий разглядывает рогатую корону Ганса и склянку с серым пеплом: «Звери, что сгорают в пепел. Вы понимаете, как это звучит? Кто, по-вашему, за этим стоит?»",
				"options": [
					{"text": "«Друид. Он зовёт себя Морвеном и говорит, что лес — его»", "answer": true,
						"ok": {"say": "Флавий бледнеет и выписывает имя на отдельный лист. «В архиве есть похожее. Очень старое».", "favor": 1}},
					{"text": "«Бандиты Ганса Рыжего. Они приручили зверей»", "answer": false,
						"fail": {"say": "«Приручили зверей, которые сгорают в пепел? Не смешите меня».", "favor": -1}},
					{"text": "«Мы надеялись, что вы подскажете»", "answer": false,
						"fail": {"say": "Флавий смотрит на вас, как на школяров, не выучивших урок."}},
				]},
			{"place": 2, "who": "Прелат Аврелия, храм Светлой Матери",
				"text": "Перед аудиенцией вас зовут в храм. Прелат говорит мягко: «Рассказы о проклятом лесе пугают паству. Зачем жрецу сеять страх, если можно молиться?»",
				"options": [
					{"text": "«Молитва не остановит зверей у порога. Остановят люди, которым поверили»", "speaker": "aiden", "check": {"stat": "faith", "dc": 12},
						"ok": {"say": "Аврелия долго молчит. «Я буду в палате. И скажу то же самое».", "favor": 2, "flag": "prelate"},
						"fail": {"say": "Слова выходят резкими. Аврелия поправляет вас — вежливо и холодно."}},
					{"text": "Понять, чего прелат боится на самом деле", "speaker": "ortwin", "check": {"stat": "ins", "dc": 13},
						"ok": {"say": "Ортвин тихо обещает, что храм не назовут виноватым в панике. «Вы понятливы, мастер Хейл. Храм не будет мешать».", "favor": 1, "flag": "prelate"},
						"fail": {"say": "Аврелия оскорблена намёком и уходит, не попрощавшись.", "favor": -1}},
					{"text": "Оставить пожертвование на нужды храма", "answer": true,
						"ok": {"say": "Монеты звенят о дно чаши. Аврелия благословляет вас — сдержанно.", "favor": 1, "coins": -30}},
				]},
			{"place": 3, "who": "Граф Ланфорд Вирт, владелец лесных угодий",
				"text": "Вечером вас зовут на пир. Граф Вирт с улыбкой отводит Эйдена к камину: «Мои леса, мои охотничьи угодья. Если пойдут слухи о проклятии, их никто не купит. Сто монет гильдии — и вы рассказываете о бандитах. Только о бандитах».",
				"options": [
					{"text": "Отказать громко, чтобы слышал весь зал", "speaker": "aiden", "check": {"stat": "cha", "dc": 14},
						"ok": {"say": "Зал замолкает. Кто-то из гостей начинает хлопать. Граф улыбается уже не так широко.", "favor": 2},
						"fail": {"say": "Голос срывается на середине фразы. Гости смеются — и не над графом.", "favor": -1}},
					{"text": "«Если лес не остановить, продавать будет нечего, граф»", "speaker": "ortwin", "check": {"stat": "ins", "dc": 13},
						"ok": {"say": "Граф бледнеет, долго молчит и наконец кивает: в палате он мешать не станет.", "favor": 1, "flag": "count_named"},
						"fail": {"say": "Граф смеётся: «Старик бредит». Возможно, так оно и есть."}},
					{"text": "Пригласить на танец графиню и расспросить её", "speaker": "aiden", "check": {"stat": "app", "dc": 13},
						"ok": {"say": "Графиня смеётся и шепчет: граф сам видел зверя с красными глазами, но молчит из-за денег.", "favor": 1, "flag": "count_named"},
						"fail": {"say": "Вы наступаете ей на ногу. Дважды."}},
					{"text": "Взять деньги и пообещать подумать", "answer": true,
						"ok": {"say": "Кошель тяжёлый. Ортвин отворачивается. Молчать вы, конечно, не будете, но о взятке к утру знает весь двор.", "favor": -3, "coins": 100, "flag": "bribed"}},
				]},
			{"place": 4, "who": "Лорд-казначей Эдгар Морн, королевская палата",
				"text": "Палата. Лорд-казначей вертит в руках рогатую корону, придворные шепчутся за колоннами. «Чем вы докажете, что это не сказка для выпрашивания денег?»",
				"bonus": {"prelate": [2, "прелат Аврелия на вашей стороне"], "count_named": [1, "граф Вирт молчит"]},
				"options": [
					{"text": "«Ганс пал за минуты. Без друида за спиной он был просто разбойником»", "answer": true, "req": {"premium": "c7"},
						"ok": {"say": "Морн долго смотрит на корону. Придворные перестают шептаться.", "favor": 2}},
					{"text": "«Вот пепел зверя. Пусть его осмотрят ваши маги»", "answer": true,
						"ok": {"say": "Придворный маг растирает пепел в пальцах и хмурится: «Это не горело. Это… развеялось».", "favor": 1}},
					{"text": "«В архиве палаты есть хроники о Пепельных. Поднимите их»", "speaker": "ortwin", "check": {"stat": "lore", "dc": 14},
						"ok": {"say": "Писари приносят пыльный том. Двести лет назад в тех же лесах было то же самое. Морн медленно откладывает корону.", "favor": 2},
						"fail": {"say": "Нужного тома в архиве не находят. Морн хмурится."}},
				]},
			{"place": 4, "who": "Лорд-казначей Эдгар Морн, королевская палата",
				"text": "Морн откладывает корону: «Последнее слово, гильдия. Чего вы просите у короны?»",
				"bonus": {"prelate": [2, "прелат Аврелия на вашей стороне"], "count_named": [1, "граф Вирт молчит"]},
				"options": [
					{"text": "«Признать угрозу и прислать к Ольховому Броду королевских егерей»", "speaker": "aiden", "check": {"stat": "elo", "dc": 14},
						"ok": {"say": "Тишина. Потом Морн кивает писарю: «Записывайте».", "favor": 2},
						"fail": {"say": "Речь выходит длинной и сбивчивой. Морн терпеливо ждёт, когда вы закончите."}},
					{"text": "«Для себя — ничего. Пусть люди в лесу снова спят спокойно»", "speaker": "aiden", "check": {"stat": "faith", "dc": 13},
						"ok": {"say": "Прелат за колонной склоняет голову. Морн смотрит на вас иначе.", "favor": 2},
						"fail": {"say": "Слова звучат как проповедь. В палате проповеди не любят."}},
					{"text": "Перечислить, во что обойдётся короне бездействие", "speaker": "ortwin", "check": {"stat": "elo", "dc": 12},
						"ok": {"say": "Ортвин говорит сухо и долго: хутора, торговля, лесная подать. Возразить нечего.", "favor": 1},
						"fail": {"say": "Ортвин сбивается в подсчётах. Кто-то из придворных зевает."}},
				]},
		],
		## Итог по расположению двора (от лучшего)
		"outcomes": [
			{"min": 9, "id": "triumph", "name": "Триумф при дворе", "coins": 150,
				"text": "Корона признала угрозу. К Ольховому Броду отправят королевских егерей, а гильдии продлена грамота и выдано жалованье на поиски друида."},
			{"min": 5, "id": "success", "name": "Угроза признана", "coins": 60,
				"text": "Палата выделила гильдии деньги на поиски источника скверны. Остальным при дворе пока не до леса."},
			{"min": -99, "id": "partial", "name": "Дело отложено", "coins": 0,
				"text": "Рассказ о друиде сочли байкой. Гильдии придётся справляться самой."},
		],
	},
}

# ---------------------------------------------------------------- Дорожные события
# Каждый выбор: text, effects (понятные последствия), req (требования)
# effects: purse, heal_pct, mana_pct, potion_hp, potion_mp, kit, gift, battle, trust, rel{pair:delta}, flag, helped, item, wagon_pct
var EVENTS := {
	"spring": {"title": "Волчий родник", "text": "Тропинка уходит к старому вязу. Под ним в каменной чаше бьёт ледяной родник. На мокрой глине волчьи следы и обглоданная кость.",
		"choices": [
			{"text": "Отдохнуть у воды", "fx": {"heal_pct": 25, "mana_pct": 25}, "say": "Все умылись и перевели дух."},
			{"text": "Наполнить фляги", "fx": {"potion_hp": 1}, "say": "Элира наполняет фляги. Говорят, вода из этого родника затягивает раны."},
			{"text": "Дождаться волков у водопоя (бой)", "fx": {"battle": [["wolf", "wolf", "wolf"]], "purse": 25}, "say": "Стая пришла на закате. На дне чаши блестят монеты, брошенные путниками на удачу."}]},
	"wounded_trader": {"title": "Раненый коробейник", "text": "Под указателем развилки сидит коробейник с перевязанной ногой. Короб раскрыт, на нём следы когтей. Волки загнали его на дерево, и он просидел там всю ночь.",
		"choices": [
			{"text": "Отдать лечебное зелье", "fx": {"potion_hp": -1, "trust": 3, "helped": true, "rel": {"aiden|elira": 2}}, "req": {"potion_hp": 1}, "say": "«Я теперь ваш должник». Коробейник обещает рассказать в деревне, что гильдия ещё жива."},
			{"text": "Эйден перевяжет (−30% маны Эйдена)", "fx": {"mana_hero": {"aiden": -30}, "trust": 2, "helped": true, "rel": {"aiden|marek": 2}}, "say": "Эйден перевязал рану. Марек молча помог подсадить торговца на попутку."},
			{"text": "Купить со скидкой (15 мон.)", "fx": {"purse": -15, "potion_mp": 1, "gift": "bread"}, "req": {"purse": 15}, "say": "Зелье маны и медовый хлеб. Торговец доволен хотя бы этим."},
			{"text": "Забрать товар «за спасение»", "fx": {"purse": 40, "gift": "wine", "trust": -4, "rel": {"aiden|elira": -3}}, "say": "Коробейник не спорит. Элира отводит взгляд и долго молчит."},
			{"text": "Пройти мимо", "fx": {"rel": {"aiden|elira": -1}}, "say": "Элира оглядывается через плечо, но молчит."}]},
	"bridge": {"title": "Сборщик у моста", "text": "У моста через Ольшанку поставили будку. Толстый сборщик с кружкой в руке требует плату, за его спиной двое подручных с дубинками.",
		"choices": [
			{"text": "Заплатить (20 мон.)", "fx": {"purse": -20}, "req": {"purse": 20}, "say": "Сборщик пересчитывает монеты и машет: проезжайте."},
			{"text": "Поторговаться", "chance": 60, "req": {"purse": 30}, "fx": {"purse": -10}, "fail_fx": {"purse": -30},
				"say": "Сошлись на десяти. Сборщик ворчит, но берёт.", "fail_say": "Сборщик обиделся и поднял цену до тридцати."},
			{"text": "Марек: «Покажи грамоту графа»", "chance": 50, "fx": {"purse": 30, "trust": 2}, "fail_fx": {"battle": [["bandit", "bandit", "brute"]], "purse": 30},
				"say": "Грамоты нет. Сборщик возвращает путникам всё, что собрал за день, и исчезает.", "fail_say": "Вместо грамоты подручные достают дубинки."},
			{"text": "Нэрис зачарует кружку (−25% маны Нэрис)", "fx": {"mana_hero": {"neris": -25}, "rel": {"marek|neris": -1, "aiden|neris": 1}}, "say": "Сборщик смотрит в кружку, бледнеет и поднимает шлагбаум. Марек недоволен, Эйден прячет улыбку."}]},
	"stuck_wagon": {"title": "Придорожная кузня", "text": "У дороги кузнечный навес, в горне тлеют угли. Тимофей показывает на колесо обоза: обод треснул и скоро рассыплется.",
		"choices": [
			{"text": "Перековать обод (20 мон.)", "fx": {"purse": -20, "wagon_pct": 20}, "req": {"purse": 20}, "say": "Кузнец перековал обод. Колесо как новое."},
			{"text": "Марек встанет к мехам (−15% ОЗ Марека)", "fx": {"hp_hero": {"marek": -15}, "wagon_pct": 10, "kit": 1, "rel": {"aiden|marek": 1}}, "say": "Марек весь в саже, зато кузнец отдал запасной обод даром."},
			{"text": "Наточить оружие (15 мон.)", "fx": {"purse": -15, "mana_pct": 20}, "req": {"purse": 15}, "say": "Клинки звенят, стрелы с новыми наконечниками. Отряд идёт дальше бодрее."},
			{"text": "Ехать дальше", "fx": {"wagon_pct": -10}, "say": "Колесо скрипит всё громче. Тимофей ругается себе под нос."}]},
	"captive_one": {"title": "Пленник у дороги", "text": "Возчик Савва привязан к сосне у обочины. Это приманка: в кустах поблёскивают наконечники стрел.",
		"choices": [
			{"text": "Элира подкрадётся", "chance": 70, "fx": {"flag": "carter1", "helped": true, "rel": {"aiden|elira": 3}}, "fail_fx": {"hp_hero": {"elira": -30}, "battle": [["archer", "bandit", "bandit"]], "flag": "carter1", "helped": true},
				"say": "Элира перерезала верёвки раньше, чем засада поняла, что приманки уже нет.", "fail_say": "Хрустнула ветка. Стрела задела Элиру, и засада бросилась в атаку."},
			{"text": "Выманить засаду на себя (бой)", "fx": {"battle": [["archer", "archer", "bandit", "bandit"]], "flag": "carter1", "helped": true}, "say": "Засаду разогнали. Савва жив."},
			{"text": "Не рисковать", "fx": {}, "say": "Савву уводят вглубь леса. Возможно, его ещё удастся найти в лагере."}]},
	"captive_camp": {"title": "Клетка на колёсах", "text": "У обочины стоит повозка с клеткой, в ней двое возчиков. Часовой на бочке пересчитывает монеты и явно не прочь заработать ещё.",
		"choices": [
			{"text": "Подкупить часового (40 мон.)", "fx": {"purse": -40, "flag": "carter2", "flag2": "carter3", "helped": true}, "req": {"purse": 40}, "say": "Ключ поворачивается тихо. Пленники уходят в лес."},
			{"text": "Нэрис наведёт сон (−50% маны Нэрис)", "chance": 60, "fx": {"mana_hero": {"neris": -50}, "flag": "carter2", "flag2": "carter3", "helped": true, "rel": {"aiden|neris": 2, "marek|neris": 2}},
				"fail_fx": {"mana_hero": {"neris": -50}, "battle": [["bandit", "bandit", "archer"]], "flag": "carter2", "flag2": "carter3", "helped": true},
				"say": "Часовой засыпает над монетами. Клетку открыли без единого звука.", "fail_say": "Часовой зевнул, но успел крикнуть своих."},
			{"text": "Отбить силой (бой)", "fx": {"battle": [["bandit", "bandit", "archer", "bandit"]], "purse": 20, "flag": "carter2", "flag2": "carter3", "helped": true}, "say": "Жарко, но клетка открыта. У часового нашёлся и кошель."}]},
	"barn_fire": {"title": "Сарай в огне", "text": "В ночи полыхает сарай на отшибе. Внутри мычит корова, хозяйка в слезах. В темноте у плетня мелькнула чья-то тень.",
		"choices": [
			{"text": "Тушить всем отрядом (−10% ОЗ всем)", "fx": {"heal_pct": -10, "trust": 4, "helped": true, "rel": {"marek|elira": 2, "elira|neris": 2}}, "say": "Сарай не спасти, но корову и сено удалось. Хозяйка обещает пирогов."},
			{"text": "Марек выведет корову (−25% ОЗ Марека)", "fx": {"hp_hero": {"marek": -25}, "trust": 2, "helped": true, "rel": {"aiden|marek": 2}}, "say": "Марек выходит из дыма с коровой на поводу и в тлеющем плаще."},
			{"text": "Дождаться поджигателя (бой)", "fx": {"battle": [["arsonist", "bandit", "bandit"]], "purse": 20, "trust": -2}, "say": "Поджигатель вернулся полюбоваться. В его котомке монеты и чужая расписка. А сарай догорел."},
			{"text": "Отдать хозяйке зелье", "fx": {"potion_hp": -1, "trust": 3, "helped": true}, "req": {"potion_hp": 1}, "say": "Ожоги у неё на руках затягиваются. «Гильдия? Та самая, нищая? Храни вас свет»."}]},
	"tracks": {"title": "Охотничья вышка", "text": "На старой охотничьей вышке прячутся двое детей из посёлка бандитов. Худые, в рваных плащах. Увидев оружие, они замирают.",
		"choices": [
			{"text": "Элира поговорит с ними", "fx": {"rel": {"aiden|elira": 2}, "fact": "elira_tracks", "helped": true}, "say": "«Вожаки носят рогатые амулеты. Звери их не трогают, а нас — едят», — шепчет старший."},
			{"text": "Отдать им еду (−15 мон.)", "req": {"purse": 15}, "fx": {"purse": -15, "trust": 3, "helped": true, "rel": {"aiden|marek": 2}}, "say": "Дети едят молча и быстро. Потом младший показывает тропу в обход дозора."},
			{"text": "Передохнуть под вышкой", "fx": {"heal_pct": 15, "mana_pct": 15}, "say": "Полчаса тишины. Дети так и не спустились."}]},
	"cache": {"title": "Тайник с данью", "text": "Под корнями дуба яма, в ней мешки с зерном и кошели. Это дань, которую вожаки отобрали у жителей посёлка для идола. Вокруг каркают вороны, похоже, стоит ловушка.",
		"choices": [
			{"text": "Вернуть дань жителям посёлка", "fx": {"trust": 4, "helped": true, "rel": {"marek|elira": 2, "aiden|marek": 2}}, "say": "К вечеру о гильдии в посёлке говорят шёпотом — но уже не как о «тёмных»."},
			{"text": "Взять кошели сверху", "chance": 75, "fx": {"purse": 30}, "fail_fx": {"hp_hero": {"marek": -20}},
				"say": "Тридцать монет. Зерно остаётся в яме.", "fail_say": "Щёлкнул капкан. Марек выдернул руку, но поранился."},
			{"text": "Перерыть всё", "chance": 40, "fx": {"purse": 45, "potion_hp": 1}, "fail_fx": {"hp_hero": {"marek": -20}, "battle": [["bandit", "bandit", "archer", "shade_wolf"]]},
				"say": "Монеты и склянка с зельем на самом дне.", "fail_say": "Возня затянулась. Сторожа тайника вернулись вместе с духом-волком."},
			{"text": "Уйти", "fx": {}, "say": "Отряд оставляет тайник воронам."}]},
	"turncoat": {"title": "Перебежчик", "text": "Из-за обгоревшего забора выходит молодой бандит с поднятыми руками, рогатый амулет он бросил в пепел. «Я больше не хочу. Ганс говорит с лесом, а лес жрёт наших. Отпустите»",
		"choices": [
			{"text": "Отпустить и выслушать", "fx": {"trust": 2, "helped": true, "flag": "turncoat", "rel": {"aiden|neris": 2}}, "say": "Он рассказывает: каждую ночь Ганс уходит к идолу, и оттуда звучит второй голос."},
			{"text": "Связать и оставить страже (+30 мон.)", "fx": {"purse": 30, "rel": {"aiden|marek": 1, "aiden|neris": -1}}, "say": "Марек связывает парня. Нэрис отворачивается."},
			{"text": "Взять проводником", "chance": 60, "fx": {"flag": "turncoat", "purse": 20, "trust": 1}, "fail_fx": {"battle": [["raider", "bandit", "shade_wolf"]]},
				"say": "Парень ведёт через пепелище и показывает схрон Ганса.", "fail_say": "Тропа привела прямо в засаду. Перебежчик исчез первым."},
			{"text": "Забрать его припасы", "fx": {"heal_pct": 15, "mana_pct": 15}, "say": "Хлеба и воды хватит на последний рывок."}]},
	"hive": {"title": "Дикий улей", "text": "В конце тропинки старая липа. В дупле гудит дикий улей, по коре стекает мёд, а внизу в траве дремлет объевшийся барсук.",
		"choices": [
			{"text": "Взять мёд", "fx": {"gift": "bread"}, "say": "Элира ловко срезает соты. Мёд с хлебом пригодится как подарок."},
			{"text": "Взять воск", "fx": {"kit": 1}, "say": "Марек обмазывает воском ремни и колёсную ось. Почти ремкомплект."},
			{"text": "Поесть мёда на месте", "fx": {"heal_pct": 30}, "say": "Липкие пальцы, довольные лица. Барсук смотрит с завистью."},
			{"text": "Забрать всё (пчёлы ужалят)", "fx": {"gift": "bread", "kit": 1, "heal_pct": 10}, "say": "Рой взлетает тучей. Добычу унесли, но опухшие носы будут болеть до вечера."}]},
	"dead_merc": {"title": "Мёртвый охотник", "text": "У поваленного дерева лежит охотник с соседнего хутора. Рядом сломанный лук и дорожный мешок. На земле следы огромных когтей и пятна серого пепла.",
		"choices": [
			{"text": "Обыскать мешок (звери могут вернуться)", "chance": 50, "fx": {"purse": 35, "potion_hp": 1}, "fail_fx": {"purse": 35, "battle": [["shade_alpha", "shade_wolf", "wolf"]]},
				"say": "Кошель, зелье, ничего лишнего. Чаща молчит.", "fail_say": "Едва Марек развязал мешок, из кустов выходит призрачный вожак. Глаза горят красным."},
			{"text": "Проститься с ним", "fx": {"rel": {"aiden|marek": 2, "aiden|elira": 2, "aiden|neris": 2}}, "say": "Эйден читает молитву и накрывает тело плащом. Даже Нэрис молчит."},
			{"text": "Уйти", "fx": {}, "say": "Отряд обходит поваленное дерево стороной."}]},
	"dice": {"title": "Кости у костра", "text": "Трое охранников купца играют в кости на перевёрнутом бочонке. Рядом кучка монет и кружки. «Сыграете, гильдейские?»",
		"choices": [
			{"text": "Сыграть честно (ставка 20 мон.)", "chance": 50, "req": {"purse": 20}, "fx": {"purse": 20}, "fail_fx": {"purse": -20},
				"say": "Две шестёрки! Охранники хлопают Марека по плечу.", "fail_say": "Кости легли не в нашу пользу. Охранники вежливо сгребают монеты."},
			{"text": "Элира сжульничает (ставка 20 мон.)", "chance": 75, "req": {"purse": 20}, "fx": {"purse": 40}, "fail_fx": {"purse": -20, "battle": [["bandit", "bandit", "bandit"]], "rel": {"marek|elira": -2}},
				"say": "Элира подменяет кость так, что не заметил даже Марек.", "fail_say": "Кость выскальзывает из рукава. Начинается драка, а Марек смотрит на Элиру очень тяжело."},
			{"text": "Марек выйдет на кулаках", "fx": {"hp_hero": {"marek": -25}, "purse": 30}, "say": "Три раунда, разбитая губа и уважение всего каравана."},
			{"text": "Расспросить о дороге", "fx": {"mana_pct": 10}, "say": "Охранники рассказывают, где дальше на тракте стоят засады."}]},
	"ditch_cart": {"title": "Телега в кювете", "text": "В кювете лежит на боку телега, верхнее колесо ещё крутится. Из-под борта торчит рука и слышен стон: возницу придавило.",
		"choices": [
			{"text": "Марек подопрёт борт плечом", "fx": {"hp_hero": {"marek": -25}, "trust": 3, "helped": true, "potion_hp": 1}, "say": "Возница выползает и суёт Мареку зелье: «Больше у меня ничего не осталось»."},
			{"text": "Нэрис поднимет борт магией", "fx": {"mana_hero": {"neris": -40}, "trust": 3, "helped": true, "rel": {"aiden|neris": 2}}, "say": "Телега на миг повисает в воздухе. Возница смотрит на Нэрис с ужасом и благодарностью."},
			{"text": "Сначала заглянуть в ящики", "chance": 50, "fx": {"purse": 25, "trust": 2, "helped": true}, "fail_fx": {"purse": 25, "trust": -3, "rel": {"aiden|marek": -2}},
				"say": "Пока Элира перебирала ящики, Марек всё же вытащил возницу.", "fail_say": "Пока все копались в ящиках, стон под бортом стих."},
			{"text": "Снять ценное и уйти", "fx": {"kit": 1, "purse": 15, "trust": -3, "rel": {"aiden|marek": -2, "aiden|elira": -2}}, "say": "Эйден долго не может смотреть никому в глаза."}]},
	"chapel": {"title": "Придорожная часовня", "text": "У дороги маленькая часовня Солнца: внутри лампада и кружка для пожертвований. Старик-служка подметает порог.",
		"choices": [
			{"text": "Помолиться", "fx": {"heal_pct": 20}, "say": "Лампада вспыхивает ярче. На душе становится тихо."},
			{"text": "Пожертвовать 30 мон.", "req": {"purse": 30}, "fx": {"purse": -30, "heal_pct": 40, "mana_pct": 20, "trust": 2}, "say": "Служка кланяется до земли. Старые раны будто перестают ныть."},
			{"text": "Эйден поможет служке", "fx": {"mana_hero": {"aiden": -30}, "potion_mp": 1, "rel": {"aiden|marek": 1}}, "say": "Эйден подправил крышу и починил скамью. Служка дарит склянку освящённой воды."},
			{"text": "Обчистить кружку", "fx": {"purse": 40, "trust": -5, "rel": {"aiden|marek": -3}}, "say": "Лампада гаснет. Служка ничего не говорит, только смотрит вслед."}]},
	"idol": {"title": "Рогатый идол", "text": "Посреди пепелища — идол из коряг и оленьих рогов, увешанный красными лентами. У подножия миски с последним зерном посёлка.",
		"choices": [
			{"text": "Раздать зерно голодным", "fx": {"trust": 3, "helped": true, "rel": {"aiden|elira": 2}}, "say": "Люди выходят из-за развалин по одному. Идол смотрит пустыми глазницами."},
			{"text": "Нэрис изучит руны", "fx": {"mana_hero": {"neris": -20}, "rel": {"aiden|neris": 2, "elira|neris": 1}}, "say": "«Друидские знаки. Это не молитва, это поводок. Идол передаёт чью-то волю»."},
			{"text": "Повалить идола", "fx": {"mana_pct": -15, "purse": 20, "rel": {"aiden|marek": 1}}, "say": "Рога трещат, ленты вспыхивают красным. До вечера у всех тяжёлые головы."},
			{"text": "Пройти мимо", "fx": {}, "say": "Отряд идёт дальше."}]},
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
	"elira_tracks": {"hero": "elira", "text": "Вожаки бандитов носят рогатые амулеты — звери их не трогают."},
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
				{"text": "Тот, кто натравил зверей, ответит и за это.", "friend": 4, "say": "«Не месть, Эйден. Суд». Но кулаки у него сжаты."}]},
		{"id": "m5", "title": "Кем мы стали", "friend": 42, "story": 6,
			"lines": ["Марек: Знаешь, на заставе меня звали «Стеной». Здесь зовут по имени. Это… лучше.", "Марек: После всего этого что будет с гильдией?"],
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
			"lines": ["Нэрис: Ладно. Я выросла в приюте Святой Ивы. Туда и отправляю жалованье. Столичный ростовщик купил их долг этой весной.", "Нэрис: Если гильдия закроется, приют закроется следом. Так что — не смей проиграть."],
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

## Доля опыта за врага, который ниже уровнем, чем отряд (как в WoW: «серые» враги почти ничего не дают).
const XP_LEVEL_FACTOR := [1.0, 0.8, 0.5, 0.25, 0.1]

func xp_factor(party_level: float, enemy_level: int) -> float:
	var diff := int(floor(party_level + 0.01)) - enemy_level
	if diff <= 0:
		return 1.0
	return XP_LEVEL_FACTOR[mini(diff, XP_LEVEL_FACTOR.size() - 1)]

func jxp_to_next(job: int) -> int:
	return 80 + 60 * job

func consumable_name(id: String) -> String:
	if CONSUMABLES.has(id): return CONSUMABLES[id]["name"]
	if GIFTS.has(id): return GIFTS[id]["name"]
	return id
