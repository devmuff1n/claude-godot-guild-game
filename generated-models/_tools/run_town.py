"""Blender batch runner: blender -b --factory-startup --python run_town.py -- <out.json> id1 id2 ..."""
import sys, json, os
argv = sys.argv[sys.argv.index("--") + 1:]
out, ids = argv[0], argv[1:]
ns = {}
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "build_town_kit.py"), encoding="utf-8").read(), ns)
if ids == ["ALL"]:
    ids = ns["TOWN_IDS"]
steps = tuple(os.environ.get("TOWN_STEPS", "build,export,verify,preview").split(","))
res = ns["run"](ids, steps=steps)
json.dump(res, open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=1, default=str)
print("DONE", out)
