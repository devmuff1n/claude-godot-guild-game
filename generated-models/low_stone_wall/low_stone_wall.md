# Низкая каменная ограда (`low_stone_wall`)

Референс и промпт: `outputs/game-asset-kit-2026-10-26/Окружение/…/low_stone_wall.png|.md`.
Происхождение: смоделировано процедурно в Blender 5.2.0 LTS по PNG и MD-промпту; Tripo/high-poly не использовался, bake не делался.

## Файлы
- Runtime: `assets/models/environment/road_defense/low_stone_wall.glb` (289 КБ, текстуры встроены)
- Исходник: `generated-models/low_stone_wall/low_stone_wall.blend` (сцена `ENV_low_stone_wall`, коллекция `low_stone_wall`, текстуры упакованы)
- Превью: `generated-models/low_stone_wall/low_stone_wall_preview.png`, данные проверки: `low_stone_wall_report.json`

## Факт после повторного импорта GLB
| | |
|---|---|
| Габариты X×Y×Z, м | 3.024 × 0.55 × 1.198 (цель 3 × 0.55 × 1.2, макс. отклонение 1%) |
| Треугольники | 1156 (визуальные меши, без коллизий) |
| Меши / узлы | 3 мешей, 3 визуальных узлов, 8 узлов в GLB |
| Материалы | env_stone, env_moss |
| Коллизии | low_stone_wall_pillar_col-convcolonly, low_stone_wall_wall_col-convcolonly |
| Части | cap_stones, end_pillar, wall_section |
| Подвижные части | нет подвижных частей |
| Проблемы сетки | нет (вырожденных граней, висячих вершин, отрицательного масштаба нет) |
| Границы исходник = GLB | да |

## Решения и ограничения
Три ряда блоков вперевязку, верхние камни, торцевой столб с шапкой; мох материалом в нижнем ряду. Модуль 3 м; `snap_west/east` — стыки, столб остаётся на восточном конце.

Оси: Blender Z-up, front −Y; экспорт glTF с штатным +Y-up (front модели в Godot +Z). Origin — на опоре.
