# Лесная ель (`pine_tree`)

Референс и промпт: `outputs/game-asset-kit-2026-10-26/Окружение/…/pine_tree.png|.md`.
Происхождение: смоделировано процедурно в Blender 5.2.0 LTS по PNG и MD-промпту; Tripo/high-poly не использовался, bake не делался.

## Файлы
- Runtime: `assets/models/environment/vegetation/pine_tree.glb` (422 КБ, текстуры встроены)
- Исходник: `generated-models/pine_tree/pine_tree.blend` (сцена `ENV_pine_tree`, коллекция `pine_tree`, текстуры упакованы)
- Превью: `generated-models/pine_tree/pine_tree_preview.png`, данные проверки: `pine_tree_report.json`

## Факт после повторного импорта GLB
| | |
|---|---|
| Габариты X×Y×Z, м | 2.9 × 2.8 × 6.5 (цель 2.9 × 2.8 × 6.5, макс. отклонение 0%) |
| Треугольники | 2692 (визуальные меши, без коллизий) |
| Меши / узлы | 2 мешей, 2 визуальных узлов, 4 узлов в GLB |
| Материалы | env_leaves_pine, env_bark_dark |
| Коллизии | pine_tree_trunk_col-convcolonly |
| Части | branch_tiers, trunk |
| Подвижные части | нет подвижных частей |
| Проблемы сетки | нет (вырожденных граней, висячих вершин, отрицательного масштаба нет) |
| Границы исходник = GLB | да |

## Решения и ограничения
Ствол виден до ~1.2 м, 9 ярусов из пониклых зубчатых лап и конуса в центре яруса, верхушка. Коллизия — ствол.

Оси: Blender Z-up, front −Y; экспорт glTF с штатным +Y-up (front модели в Godot +Z). Origin — на опоре.
