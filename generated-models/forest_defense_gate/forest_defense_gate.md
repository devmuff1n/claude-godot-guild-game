# Деревянные ворота заставы (`forest_defense_gate`)

Референс и промпт: `outputs/game-asset-kit-2026-10-26/Окружение/…/forest_defense_gate.png|.md`.
Происхождение: смоделировано процедурно в Blender 5.2.0 LTS по PNG и MD-промпту; Tripo/high-poly не использовался, bake не делался.

## Файлы
- Runtime: `assets/models/environment/road_defense/forest_defense_gate.glb` (359 КБ, текстуры встроены)
- Исходник: `generated-models/forest_defense_gate/forest_defense_gate.blend` (сцена `ENV_forest_defense_gate`, коллекция `forest_defense_gate`, текстуры упакованы)
- Превью: `generated-models/forest_defense_gate/forest_defense_gate_preview.png`, данные проверки: `forest_defense_gate_report.json`

## Факт после повторного импорта GLB
| | |
|---|---|
| Габариты X×Y×Z, м | 2.28 × 0.448 × 2.805 (цель 2.3 × 0.45 × 2.8, макс. отклонение 1%) |
| Треугольники | 872 (визуальные меши, без коллизий) |
| Меши / узлы | 5 мешей, 5 визуальных узлов, 14 узлов в GLB |
| Материалы | env_wood_dark, env_iron, env_plaque, env_wood_light |
| Коллизии | forest_defense_gate_gate_leaf_col-convcolonly, forest_defense_gate_post_L_col-convcolonly, forest_defense_gate_post_R_col-convcolonly |
| Части | cross_braces, gate_leaf, metal_fittings, shield_plaque, side_posts |
| Подвижные части | forest_defense_gate_gate_leaf: ось local Z (hinge on left stile), pivot [-0.7, 0.0, 0.0], движется=True |
| Проблемы сетки | нет (вырожденных граней, висячих вершин, отрицательного масштаба нет) |
| Границы исходник = GLB | да |

## Решения и ограничения
Стойки с пирамидальными шапками и светлыми вставками; створка `gate_leaf` с pivot на линии петель (левая обвязка), к ней привязаны поперечины, железо, щиток-эмблема и якоря эффектов `vfx_damage_0..2`, `vfx_fire_0..1`. Тест поворота пройден.

Оси: Blender Z-up, front −Y; экспорт glTF с штатным +Y-up (front модели в Godot +Z). Origin — на опоре.
