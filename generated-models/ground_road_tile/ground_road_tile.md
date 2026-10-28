# Модуль земли и лесной дороги (`ground_road_tile`)

Референс и промпт: `outputs/game-asset-kit-2026-10-26/Окружение/…/ground_road_tile.png|.md`.
Происхождение: смоделировано процедурно в Blender 5.2.0 LTS по PNG и MD-промпту; Tripo/high-poly не использовался, bake не делался.

## Файлы
- Runtime: `assets/models/environment/landscape/ground_road_tile.glb` (1113 КБ, текстуры встроены)
- Исходник: `generated-models/ground_road_tile/ground_road_tile.blend` (сцена `ENV_ground_road_tile`, коллекция `ground_road_tile`, текстуры упакованы)
- Превью: `generated-models/ground_road_tile/ground_road_tile_preview.png`, данные проверки: `ground_road_tile_report.json`

## Факт после повторного импорта GLB
| | |
|---|---|
| Габариты X×Y×Z, м | 6.0 × 6.029 × 0.385 (цель 6 × 6 × 0.2, макс. отклонение 92%) |
| Треугольники | 9166 (визуальные меши, без коллизий) |
| Меши / узлы | 2 мешей, 2 визуальных узлов, 6 узлов в GLB |
| Материалы | env_fern (2-sided), env_road_top, env_soil |
| Коллизии | ground_road_tile_ground_col-convcolonly |
| Части | edge_vegetation_cards, ground_surface |
| Подвижные части | нет подвижных частей |
| Проблемы сетки | нет (вырожденных граней, висячих вершин, отрицательного масштаба нет) |
| Границы исходник = GLB | да |

## Решения и ограничения
Плита 6×6×0.2 м, верх дороги на Z=0, origin в центре верхней плоскости. Рельеф по X периодичен, по краям Y обнулён — тайлы стыкуются в цепочку. Дорога и обочина — регионы одной текстуры `road_tile_top` (бесшовна по X). Папоротники обочины собраны в один меш (1 draw call) внутри границ тайла; из-за них общая высота 0.39 м. Пустышки `snap_west/east` — точки стыка.

Оси: Blender Z-up, front −Y; экспорт glTF с штатным +Y-up (front модели в Godot +Z). Origin — на опоре.
