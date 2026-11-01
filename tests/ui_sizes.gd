extends Node
## Проверка «окна не меняют размер»: каждое окно открывается во всех вариантах (каждый герой,
## вкладки, выбранные вещи, поручения, события…), и прямоугольники всех панелей и контейнеров
## из сцены окна сравниваются с первым вариантом. Любое расширение, сужение или сдвиг — ошибка.
## Запуск: GUILD_UITEST=sizes (код выхода 1, если что-то «скачет»).
##
## Сравниваются рамки окна: корень, панели (PanelContainer) и области прокрутки, заданные в .tscn
## окна (не созданные кодом строки списков) и не внутри прокрутки. Строки внутри панели могут
## перестраиваться под содержимое, но сама рамка — нет.

var main
var fails := 0
var checks := 0

func wait(n := 3) -> void:
	for i in n:
		await get_tree().process_frame

## Узел задан в сцене окна: цепочка владельцев доходит до корня окна, нигде не прерываясь
## (у созданных через instantiate() строк списков владелец корня — null).
func _static(n: Node, root: Node) -> bool:
	var cur := n
	while cur != root:
		if cur.owner == null:
			return false
		cur = cur.owner
	return true

func _in_scroll(n: Node, root: Node) -> bool:
	var p := n.get_parent()
	while p != null and p != root:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false

func snapshot(root: Control) -> Dictionary:
	var out := {}
	_walk(root, root, out)
	return out

func _walk(n: Node, root: Control, out: Dictionary) -> void:
	if n is Control:
		var c: Control = n
		if not c.is_visible_in_tree():
			return
		if (c == root or c is PanelContainer or c is ScrollContainer) and _static(c, root) and not _in_scroll(c, root):
			out[str(root.get_path_to(c))] = c.get_global_rect()
	for ch in n.get_children():
		_walk(ch, root, out)

## Открыть окно в каждом варианте и сравнить. variants: [[название, Callable], ...];
## get_root — Callable, возвращающий корень окна (окна пересоздаются при переключении).
func check_window(title: String, get_root: Callable, variants: Array) -> void:
	if stage != "":
		title = "%s [%s]" % [title, stage]
	var base := {}        # путь узла -> первый замеренный прямоугольник
	var base_from := {}   # путь узла -> вариант, в котором он замерен
	var bad := 0
	var seen := {}
	var screen := get_viewport().get_visible_rect()
	windows += 1
	for v in variants:
		await v[1].call()
		await wait(3)
		var root: Control = get_root.call()
		var snap := snapshot(root)
		checks += 1
		if OS.get_environment("SIZES_SHOTS") != "":
			var img := get_viewport().get_texture().get_image()
			img.save_png("%s/%s_%s.png" % [OS.get_environment("SIZES_SHOTS"), title, String(v[0]).replace("/", "_")])
		if OS.get_environment("SIZES_DUMP") != "":
			for k in snap.keys():
				print("[DUMP] %s | %s | %s | %s" % [title, v[0], k, _r(snap[k])])
		for k in snap.keys():
			var r: Rect2 = snap[k]
			# Рамка окна не вылезает за экран
			if not screen.grow(0.5).encloses(r) and not seen.has("screen:" + k):
				seen["screen:" + k] = true
				print("[SIZES] FAIL %s «%s»: %s выходит за экран %s" % [title, v[0], k, _r(r)])
				bad += 1
			if not base.has(k):
				base[k] = r
				base_from[k] = v[0]
			elif not r.is_equal_approx(base[k]) and not seen.has(k):
				seen[k] = true
				print("[SIZES] FAIL %s: «%s» vs «%s»: %s  %s -> %s" % [title, base_from[k], v[0], k, _r(base[k]), _r(r)])
				bad += 1
	if bad == 0:
		print("[SIZES] OK   %s (%d вариантов)" % [title, variants.size()])
	fails += bad

func _r(r: Rect2) -> String:
	return "(%d,%d %dx%d)" % [r.position.x, r.position.y, r.size.x, r.size.y]

## Состояние с разнообразным содержимым: разные уровни, очки, выгорание, вещи в кладовой.
func _setup_state() -> void:
	Game.slot = -1
	Game.state = Game._fresh_state()
	Game.state["intro_seen"] = true
	var k := 5
	for i in k:
		Game.state["completed"][DB.STORY_ORDER[i]] = 1
	Game.state["story_stage"] = k
	Game.state["treasury"] = 1234
	var lv := {"aiden": 6, "marek": 9, "elira": 4, "neris": 7}
	var bo := {"aiden": 0, "marek": 7, "elira": 4, "neris": 10}
	for id in DB.HERO_IDS:
		var h := Game.hero(id)
		h["level"] = lv.get(id, 5)
		h["job"] = 3
		h["burnout"] = bo.get(id, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bases: Array = DB.BASES.keys()
	var rar := ["common", "uncommon", "rare", "epic"]
	for i in 24:
		Game.state["storage"][i] = Items.make(bases[(i * 7) % bases.size()], 2 + i % 8, rar[i % rar.size()], rng)

## Экипировать всех: вещи с бонусами дают длинные значения «43  +12» в характеристиках.
func _gear_up() -> void:
	for id in DB.HERO_IDS:
		var st := Game.storage()
		for i in st.size():
			if st[i] != null and Game.equip_problem(id, st[i], Game.auto_slot(id, st[i])) == "":
				Game.equip_from_storage(id, i)

func _host(scene: PackedScene) -> Control:
	for c in host.get_children():
		host.remove_child(c)
		c.queue_free()
	var d: Control = scene.instantiate()
	host.add_child(d)
	return d

var host: Control
var vs

func _ready() -> void:
	main = get_parent()
	await wait(5)
	# Начало игры: первый уровень, пустая кладовая
	Game.slot = -1
	Game.state = Game._fresh_state()
	Game.state["intro_seen"] = true
	main.goto("village")
	await wait(5)
	vs = main.current
	stage = "начало игры"
	await _village()
	# Середина главы: разные уровни, очки атрибутов, выгорание, вещи
	_setup_state()
	main.goto("village")
	await wait(5)
	vs = main.current
	stage = "середина главы"
	await _village()
	stage = ""
	await _village_dialogs()
	await _expedition_dialogs()
	await _diplomacy()
	print("[SIZES] done windows_checked=%d variants=%d fails=%d" % [windows, checks, fails])
	get_tree().quit(1 if fails > 0 else 0)

var windows := 0
var stage := ""

func _tab(id: String) -> Control:
	if vs.tab != id or vs.content.get_child_count() == 0:
		vs.show_tab(id)
		await wait(3)
	return vs.content.get_child(vs.content.get_child_count() - 1)

func _tab_root() -> Control:
	return vs.content.get_child(vs.content.get_child_count() - 1)

func _village() -> void:
	# Отряд: каждый герой × вкладки справа × выбранная вещь в кладовой × очки атрибутов
	var party := []
	for gear in [false, true]:
		for id in DB.HERO_IDS:
			for side in ["skills", "perks", "social"]:
				var hid: String = id
				var sd: String = side
				var g: bool = gear
				party.append(["%s/%s%s" % [hid, sd, "/снаряжён" if g else ""], func():
					if g and not Game.state.get("_geared", false):
						Game.state["_geared"] = true
						_gear_up()
					if g and Game.storage_count() == 0:
						return
					var pv = await _tab("party")
					pv.sub = "heroes"
					pv.hero_id = hid
					pv.side_tab = sd
					pv.sel_storage = -1
					pv.refresh()
					if OS.get_environment("SIZES_DUMP") != "":
						await wait(2)
						var eq := 0
						for sl in Game.hero(hid)["equip"].keys():
							if Game.hero(hid)["equip"][sl] != null:
								eq += 1
						print("[DBG] %s equip=%d stats_min=%s body=%s" % [hid, eq, pv.get_node("%Stats").get_combined_minimum_size(), pv.get_node("%Stats").get_parent().get_combined_minimum_size()])])
	for i in 6:
		var idx := i
		party.append(["вещь %d выбрана" % idx, func():
			var pv = await _tab("party")
			var st := Game.storage()
			var k := -1
			var n := 0
			for j in st.size():
				if st[j] != null and Items.hero_can_use_type(pv.hero_id, st[j]):
					if n == idx:
						k = j
					n += 1
			pv.sel_storage = k
			pv.refresh()])
	party.append(["очки вложены", func():
		var pv = await _tab("party")
		for k in ["sta", "str", "agi", "int"]:
			for t in 5:
				Game.add_stat_point(pv.hero_id, k)
		pv.refresh()])
	# Крайний случай: огромные числа (уровень 60, все очки вложены) не должны расширять панель
	for id in DB.HERO_IDS:
		var hid: String = id
		party.append(["%s: большие числа" % hid, func():
			var pv = await _tab("party")
			var h := Game.hero(hid)
			var keep_lv: int = h["level"]
			var keep_alloc: Dictionary = h.get("alloc", {}).duplicate()
			h["level"] = 60
			h["alloc"] = {"sta": 120, "str": 60, "agi": 30, "int": 26}
			pv.hero_id = hid
			pv.sel_storage = -1
			pv.side_tab = "skills"
			pv.refresh()
			await wait(3)
			h["level"] = keep_lv
			h["alloc"] = keep_alloc])
	await check_window("Отряд: герои", _tab_root, party)
	# Отряд: журнал
	var journal := []
	for id in DB.COMPANIONS + ["aiden", "pairs"]:
		var jid: String = id
		journal.append([jid, func():
			var pv = await _tab("party")
			pv.sub = "journal"
			pv.refresh()
			pv.get_node("%Journal").sel = jid
			pv.get_node("%Journal").refresh()])
	await check_window("Отряд: журнал", _tab_root, journal)
	# Доска поручений: каждое поручение × герой личного задания
	var board := []
	for cid in DB.STORY_ORDER + DB.SIDE_ORDER:
		for ph in DB.COMPANIONS:
			var c: String = cid
			var h: String = ph
			board.append(["%s/%s" % [c, h], func():
				var bv = await _tab("board")
				bv.sel = c
				bv.general = ""
				bv.pers_hero = h
				bv.pers_obj = ""
				bv.refresh()])
	await check_window("Поручения", _tab_root, board)
	# Лавка: без выбора и с выбранной вещью на продажу
	var shop := [["без выбора", func():
		var sv = await _tab("shop")
		sv.sel_sell = -1
		sv.refresh()]]
	for i in 4:
		var idx := i
		shop.append(["продать %d" % idx, func():
			var sv = await _tab("shop")
			var n := 0
			for j in Game.storage().size():
				if Game.storage()[j] != null:
					if n == idx:
						sv.sel_sell = j
					n += 1
			sv.refresh()])
	await check_window("Лавка", _tab_root, shop)
	# Арена: каждый набор врагов
	var arena := []
	for i in 7:
		var idx := i
		arena.append(["набор %d" % idx, func():
			var av = await _tab("arena")
			av.preset = idx
			av.refresh()])
	await check_window("Арена", _tab_root, arena)
	# Дом гильдии: с очередью выдачи и без
	var home := []
	for st in DB.STORY_ORDER.size() + 1:
		var sst := st
		home.append(["хроника %d" % sst, func():
			var keep: int = Game.state["story_stage"]
			Game.state["story_stage"] = sst
			var hv = await _tab("home")
			hv.refresh()
			Game.state["story_stage"] = keep])
	home.append(["награда на выбор", func():
		var rng := RandomNumberGenerator.new()
		Game.state["pending_choice"] = [Items.make(DB.BASES.keys()[2], 5, "rare", rng), Items.make(DB.BASES.keys()[5], 5, "epic", rng), Items.make(DB.BASES.keys()[9], 5, "uncommon", rng)]
		var hv = await _tab("home")
		hv.refresh()
		await wait(3)
		Game.state["pending_choice"] = []])
	home.append(["полный рюкзак", func():
		var keep: Dictionary = Game.state["backpack"].duplicate()
		for g in DB.GIFTS.keys():
			Game.state["backpack"][g] = 9
		var hv = await _tab("home")
		hv.refresh()
		await wait(3)
		Game.state["backpack"] = keep])
	await check_window("Дом гильдии", _tab_root, home + [
		["обычный", func():
			Game.state["queue"] = []
			var hv = await _tab("home")
			hv.refresh()],
		["очередь", func():
			var rng := RandomNumberGenerator.new()
			Game.state["queue"] = [Items.make(DB.BASES.keys()[0], 5, "rare", rng)]
			var hv = await _tab("home")
			hv.refresh()],
	])

func _ov() -> Control:
	return vs.overlay.get_child(0)

func _village_dialogs() -> void:
	await _tab("town")
	var victory := {"kind": "victory", "name": "Первый лесной тракт", "outro": "Дорога снова открыта, а у вожака стаи на ошейнике была бирка «К.Г.».",
		"lines": ["Награда за поручение: +120 мон.", "Доп. поручение «Без потерь»: выполнено, +40 мон.", "Личное поручение Элиры: упущена", "Кошелёк: возвращено 35 мон.", "Опыт: +340"],
		"coins": 160, "purse_return": 35, "items": [], "choice": false,
		"levels": [{"hero": "aiden", "from": 3, "to": 4, "abilities": ["Щит веры"]}, {"hero": "marek", "from": 3, "to": 4, "abilities": []}],
		"jobs": [["elira", 2], ["neris", 2]],
		"unlocks": [{"kind": "perks", "title": "Перки: этап II", "tip": "…"}, {"kind": "skills", "title": "Новые умения", "tip": "…"}],
		"next": [{"icon": "event", "title": "Возможны опасные враги", "tip": "…"}]}
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 3:
		victory["items"].append(Items.make(DB.BASES.keys()[i * 3], 6, "epic", rng))
	var defeat := {"kind": "defeat", "name": "Ночь у Чёрного ручья", "lines": ["Наград за победу нет"], "coins": 0, "purse_return": 0,
		"items": [], "levels": [], "jobs": []}
	var abandon := {"kind": "abandon", "name": "Обоз в Ольховку", "lines": ["Опыт этой попытки: отменяется", "Кошелёк: возвращено 12 мон."],
		"coins": 0, "purse_return": 12, "items": [], "levels": [], "jobs": []}
	await check_window("Итоги похода", _ov, [
		["победа", func(): vs.show_result(victory)],
		["поражение", func(): vs.show_result(defeat)],
		["прерван", func(): vs.show_result(abandon)],
	])
	await check_window("Меню деревни", _ov, [
		["без итогов", func():
			Game.state["last_result"] = {}
			vs.show_menu()],
		["с итогами", func():
			Game.state["last_result"] = victory
			vs.show_menu()],
	])
	await check_window("Сюжетное окно", _ov, [
		["вступление", func(): vs._show_intro()],
		["концовка", func(): vs._show_ending()],
	])
	vs.close_modal()

func _expedition_dialogs() -> void:
	host = Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.add_child(host)
	host.size = get_viewport().get_visible_rect().size
	Game.state["treasury"] = 999
	Game.start_expedition("c3", {"purse": 80, "general": "", "personal": {}})
	Game.state["backpack"] = {"wine": 2, "tea": 1, "berries": 3}
	var get_d := func(): return host.get_child(host.get_child_count() - 1)
	# Дорожные события: варианты выбора и итог каждого события
	var ev := []
	for eid in DB.EVENTS.keys():
		var id: String = eid
		ev.append([id + "/выбор", func():
			var d: EventDialog = _host(preload("res://scenes/expedition/EventDialog.tscn"))
			d.show_choices(DB.EVENTS[id], 80, 3, 2)])
		ev.append([id + "/итог", func():
			var d: EventDialog = _host(preload("res://scenes/expedition/EventDialog.tscn"))
			var say := ""
			for ch in DB.EVENTS[id]["choices"]:
				if str(ch.get("say", "")).length() > say.length():
					say = ch["say"]
			d.show_result(DB.EVENTS[id], say, false)])
	await check_window("Дорожное событие", get_d, ev)
	# Придорожная лавка
	await check_window("Придорожная лавка", get_d, [
		["зелья", func():
			var d: RoadShopDialog = _host(preload("res://scenes/expedition/RoadShopDialog.tscn"))
			d.refresh("Корчма", ["potion_hp", "potion_mp"])],
		["всё", func():
			var d: RoadShopDialog = _host(preload("res://scenes/expedition/RoadShopDialog.tscn"))
			d.refresh("Придорожный торговец с телегой", ["potion_hp", "potion_mp", "kit", "wine", "tea", "berries"])],
	])
	# Окно подтверждения
	await check_window("Подтверждение", get_d, [
		["прервать поход", func():
			var d: ConfirmDialog = _host(preload("res://scenes/ui/ConfirmDialog.tscn"))
			d.setup("ПОХОД", "Прервать поход?", "", ["Опыт этой попытки: отменяется", "Вернётся в казну: 80 мон.", "Дорожный заработок: 0 мон. — не вернётся", "Покупки и расходы: не возвращаются"], [["Остаться", false], ["Прервать поход", true]])],
		["поражение", func():
			var d: ConfirmDialog = _host(preload("res://scenes/ui/ConfirmDialog.tscn"))
			d.setup("ПОРАЖЕНИЕ", "Отряд отступает", "Все герои без сознания.", [], [["Вернуться в деревню", true]])],
		["арена", func():
			var d: ConfirmDialog = _host(preload("res://scenes/ui/ConfirmDialog.tscn"))
			d.setup("ИСПЫТАНИЕ ОКОНЧЕНО", "Победа", "Время: 48 с", [], [["Повторить", false], ["В деревню", true]])],
	])
	# Меню паузы
	await check_window("Меню паузы", get_d, [
		["поход", func():
			var m: SystemMenu = _host(preload("res://scenes/ui/SystemMenu.tscn"))
			m.setup("Пауза", ["resume", "save", "abandon", "main_menu"], true)],
		["арена", func():
			var m: SystemMenu = _host(preload("res://scenes/ui/SystemMenu.tscn"))
			m.setup("Пауза", ["resume", "abandon"], true)],
		["деревня", func():
			var m: SystemMenu = _host(preload("res://scenes/ui/SystemMenu.tscn"))
			m.setup("Меню", ["resume", "save", "last_result", "main_menu"])],
		["настройки", func():
			var m: SystemMenu = _host(preload("res://scenes/ui/SystemMenu.tscn"))
			m.setup("Настройки", [])],
	])
	# Привал: без разговора, разговор с каждым, сцена у костра, личный вечер
	var camp := [["пусто", func():
		Game.ex()["camp"] = {}
		_camp()]]
	for hid in DB.COMPANIONS:
		var h: String = hid
		camp.append(["разговор " + h, func():
			var t = Game.next_topic(h)
			Game.ex()["camp"] = {}
			if t != null and not t.get("locked", false):
				Game.ex()["camp"] = {"dialog": {"kind": "topic", "hero": h, "topic": t["id"]}}
			_camp()])
		camp.append(["вечер " + h, func():
			Game.ex()["camp"] = {}
			var cp: CampPanel = _camp()
			cp.evening_pick = h
			cp.refresh()])
	camp.append(["у костра", func():
		var ps = Game.next_pair_scene()
		Game.ex()["camp"] = {"dialog": {"kind": "pair", "scene": ps["id"]}} if ps != null else {}
		_camp()])
	camp.append(["итог разговора", func():
		Game.ex()["camp"] = {"dialog": {"kind": "result", "hero": "neris", "title": "Итог", "text": "Нэрис долго молчит, потом кивает."}}
		_camp()])
	await check_window("Привал", get_d, camp)
	host.queue_free()
	Game.state["expedition"] = null

func _camp() -> CampPanel:
	var cp: CampPanel = preload("res://scenes/ui/CampPanel.tscn").instantiate()
	cp.screen = self
	for c in host.get_children():
		host.remove_child(c)
		c.queue_free()
	host.add_child(cp)
	return cp

func _diplomacy() -> void:
	Game.state["expedition"] = null
	for cid in DB.STORY_ORDER:
		Game.state["completed"][cid] = 1 if cid != "c8" else 0
	Game.state["completed"].erase("c8")
	Game.state["story_stage"] = 7
	var err := Game.start_diplomacy("c8")
	if err != "":
		print("[SIZES] SKIP дипломатия: ", err)
		return
	main.goto("diplomacy")
	await wait(5)
	var beats: Array = Game.dip_scenario()["beats"]
	var vars := []
	for i in beats.size():
		var bi := i
		vars.append(["сцена %d" % bi, func():
			Game.dip()["beat"] = bi
			Game.dip()["last"] = {}
			main.current.refresh(false)])
		vars.append(["сцена %d/итог" % bi, func():
			Game.dip()["beat"] = bi
			Game.dip()["last"] = {}
			for k in Game.dip_beat()["options"].size():
				if Game.dip_option_problem(Game.dip_beat()["options"][k]) == "":
					Game.dip_choose(k)
					break
			Game.dip()["beat"] = bi
			main.current.refresh(false)])
	await check_window("Дипломатия", func(): return main.current, vars)
