# Деревянная ограда (`wooden_garden_fence`)

Референс и промпт: `outputs/game-asset-kit-2026-10-26/Окружение/…/wooden_garden_fence.png|.md`.
Происхождение: смоделировано процедурно в Blender 5.2.0 LTS по PNG и MD-промпту; Tripo/high-poly не использовался, bake не делался.

## Файлы
- Runtime: `assets/models/environment/road_defense/wooden_garden_fence.glb` (245 КБ, текстуры встроены)
- Исходник: `generated-models/wooden_garden_fence/wooden_garden_fence.blend` (сцена `ENV_wooden_garden_fence`, коллекция `wooden_garden_fence`, текстуры упакованы)
- Превью: `generated-models/wooden_garden_fence/wooden_garden_fence_preview.png`, данные проверки: `wooden_garden_fence_report.json`

## Факт после повторного импорта GLB
| | |
|---|---|
| Габариты X×Y×Z, м | 3.0 × 0.275 × 1.016 (цель 3 × 0.28 × 1.0, макс. отклонение 2%) |
| Треугольники | 544 (визуальные меши, без коллизий) |
| Меши / узлы | 3 мешей, 4 визуальных узлов, 8 узлов в GLB |
| Материалы | env_wood_mid, env_wood_light |
| Коллизии | wooden_garden_fence_fence_col-convcolonly |
| Части | post_L, post_R, rail_lower, rail_upper |
| Подвижные части | нет подвижных частей |
| Проблемы сетки | нет (вырожденных граней, висячих вершин, отрицательного масштаба нет) |
| Границы исходник = GLB | да |

## Решения и ограничения
Два столба (один меш, второй — экземпляр с поворотом на 180°) и две слегка волнистые жерди с выступающими шипами-шкантами. Модуль 3 м.

Оси: Blender Z-up, front −Y; экспорт glTF с штатным +Y-up (front модели в Godot +Z). Origin — на опоре.
