# wooden_crate

- Исходник: `generated-models/wooden_crate/wooden_crate.blend`, сборка: `_tools/build_town_kit.py` → `run(["wooden_crate"])`
- Runtime: `assets/models/town/props/wooden_crate.glb`
- Габариты GLB (Ш×Г×В, м): 0.71 × 0.65 × 0.662; цель из набора: 0.7 × 0.6 × 0.65
- Треугольники: 1532; материалы: wood_light, wood_mid
- Части: frame_braces, lid, planked_body
- Подвижные части: lid (local X (hinge))
- Коллизии (`-convcolonly`): crate
- Проверка: повторный импорт GLB в Blender, границы совпали (True); замечания по сетке: нет
- Происхождение: процедурная геометрия Blender по PNG-референсу и MD-заданию набора, без Tripo high-poly.
