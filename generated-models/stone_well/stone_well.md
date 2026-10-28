# stone_well

- Исходник: `generated-models/stone_well/stone_well.blend`, сборка: `_tools/build_town_kit.py` → `run(["stone_well"])`
- Runtime: `assets/models/town/props/stone_well.glb`
- Габариты GLB (Ш×Г×В, м): 2.54 × 2.038 × 2.92; цель из набора: 2.4 × 2.2 × 2.7
- Треугольники: 3394; материалы: brass, eye, iron, roof_red, rope, stone_block, timber, water, wood_dark, wood_mid
- Части: posts, roof, rope_bucket, stone_ring, water_surface, windlass
- Подвижные части: windlass (local X (windlass))
- Коллизии (`-convcolonly`): post_0, post_1, ring
- Проверка: повторный импорт GLB в Blender, границы совпали (True); замечания по сетке: stone_well_rope_bucket: 1 degenerate faces
- Происхождение: процедурная геометрия Blender по PNG-референсу и MD-заданию набора, без Tripo high-poly.
