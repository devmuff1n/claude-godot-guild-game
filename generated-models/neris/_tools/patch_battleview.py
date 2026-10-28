import sys
p=sys.argv[1]
s=open(p,encoding="utf-8").read()
if "MODEL_LOOKS" in s: print("already"); sys.exit()
def rep(a,b):
    global s
    assert s.count(a)==1, a
    s=s.replace(a,b)
rep('''var stars: Array = []
''','''var stars: Array = []

## Герои, которых вместо рисованной фигурки показывает 3D-модель (Hero3DSprite).
const MODEL_LOOKS := {"neris": "res://scenes/characters/Neris3D.tscn"}
## Чем 3D-модель отвечает на обычную атаку: Нэрис бьёт магией из посоха.
const MODEL_ATTACK := {"neris": "cast_release"}
const ROAD_SPEED_MPS := 1.7  # отряд на дороге идёт со скоростью прокрутки (260 px/с)
var use_3d_models := true
var models := {}             # ключ юнита -> Hero3DSprite
''')
rep('''	for k in vis.keys():
		var v: Dictionary = vis[k]
		v["swing"] = max(0.0, v["swing"] - delta * 3.5)
	queue_redraw()''','''	for k in vis.keys():
		var v: Dictionary = vis[k]
		v["swing"] = max(0.0, v["swing"] - delta * 3.5)
	for k in models.keys():
		var m: Hero3DSprite = models[k]
		m.render_target_update_mode = SubViewport.UPDATE_ALWAYS if m.used else SubViewport.UPDATE_DISABLED
		m.unused_t = 0.0 if m.used else m.unused_t + delta
		m.used = false
		if m.unused_t > 3.0:
			m.queue_free()
			models.erase(k)
	queue_redraw()''')
rep('''			"swing":
				_v(int(e["uid"]))["swing"] = 1.0''','''			"swing":
				_v(int(e["uid"]))["swing"] = 1.0
				_model_event(int(e["uid"]), "attack")''')
rep('''				if u2 != null:
					fx.append({"pos": Vector2(u2["x"], GROUND - 55), "kind": e["ab"], "t": 0.0, "dur": 0.6})''','''				if u2 != null:
					fx.append({"pos": Vector2(u2["x"], GROUND - 55), "kind": e["ab"], "t": 0.0, "dur": 0.6})
					_model_event(int(e["uid"]), "cast_release")''')
rep('''func _v(uid: int) -> Dictionary:''','''func _model_event(uid: int, kind: String) -> void:
	if sim == null:
		return
	var u = sim.unit(uid)
	if u == null or not models.has("u%d" % uid):
		return
	models["u%d" % uid].one_shot(MODEL_ATTACK.get(u["look"], "attack") if kind == "attack" else kind)


## Нарисовать юнита 3D-моделью, если для его облика она есть. false — рисовать как раньше.
func _draw_model(key: String, look: String, pos: Vector2, facing: int, st: Dictionary) -> bool:
	if not use_3d_models or not MODEL_LOOKS.has(look):
		return false
	var m: Hero3DSprite = models.get(key)
	if m == null:
		var scene := load(MODEL_LOOKS[look]) as PackedScene
		if scene == null:
			return false
		m = Hero3DSprite.new(scene)
		m.name = "Model_" + key
		add_child(m)
		models[key] = m
	m.drive(st, facing)
	if not st.get("dead", false):
		_ell(pos, 30 * SC, 7 * SC, Color(0, 0, 0, 0.35))
	draw_texture(m.get_texture(), pos - m.anchor(), Color(1, 1, 1, 0.8 if st.get("dead", false) else 1.0))
	return true


func _v(uid: int) -> Dictionary:''')
rep('''	for w in walk_units:
		Art.draw_unit(self, Vector2(w["x"], GROUND), w["look"], 1, {"t": time + w["x"] * 0.01, "moving": walking}, SC)''','''	for w in walk_units:
		var wpos := Vector2(w["x"], GROUND)
		var wst := {"moving": walking, "x": w["x"], "speed_mps": ROAD_SPEED_MPS if walking else 0.0}
		if not _draw_model("w_" + w["look"], w["look"], wpos, 1, wst):
			Art.draw_unit(self, wpos, w["look"], 1, {"t": time + w["x"] * 0.01, "moving": walking}, SC)''')
rep('''		Art.draw_unit(self, pos, u["look"], int(u["facing"]) if u["facing"] != 0 else (1 if u["side"] == "hero" else -1), stt, sc)''','''		var facing := int(u["facing"]) if u["facing"] != 0 else (1 if u["side"] == "hero" else -1)
		stt["x"] = u["x"]
		if not _draw_model("u%d" % u["uid"], u["look"], pos, facing, stt):
			Art.draw_unit(self, pos, u["look"], facing, stt, sc)''')
open(p,"w",encoding="utf-8").write(s); print("patched")
