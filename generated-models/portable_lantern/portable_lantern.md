# portable_lantern

- Исходник: `generated-models/portable_lantern/portable_lantern.blend`, сборка: `_tools/build_town_kit.py` → `run(["portable_lantern"])`
- Runtime: `assets/models/town/props/portable_lantern.glb`
- Габариты GLB (Ш×Г×В, м): 0.3 × 0.3 × 0.552; цель из набора: 0.3 × 0.3 × 0.46
- Треугольники: 318; материалы: iron, lantern_glow
- Части: cap, frame, glass_insert, handle_ring
- Подвижные части: handle_ring (local X (handle swing))
- Коллизии (`-convcolonly`): lantern
- Проверка: повторный импорт GLB в Blender, границы совпали (True); замечания по сетке: нет
- Происхождение: процедурная геометрия Blender по PNG-референсу и MD-заданию набора, без Tripo high-poly.
