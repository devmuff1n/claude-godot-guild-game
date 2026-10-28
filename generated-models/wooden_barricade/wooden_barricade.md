# Подготовленное заграждение (`wooden_barricade`)

Референс и промпт: `outputs/game-asset-kit-2026-10-26/Окружение/…/wooden_barricade.png|.md`.
Происхождение: смоделировано процедурно в Blender 5.2.0 LTS по PNG и MD-промпту; Tripo/high-poly не использовался, bake не делался.

## Файлы
- Runtime: `assets/models/environment/road_defense/wooden_barricade.glb` (331 КБ, текстуры встроены)
- Исходник: `generated-models/wooden_barricade/wooden_barricade.blend` (сцена `ENV_wooden_barricade`, коллекция `wooden_barricade`, текстуры упакованы)
- Превью: `generated-models/wooden_barricade/wooden_barricade_preview.png`, данные проверки: `wooden_barricade_report.json`

## Факт после повторного импорта GLB
| | |
|---|---|
| Габариты X×Y×Z, м | 1.673 × 0.688 × 0.905 (цель 1.7 × 0.65 × 0.9, макс. отклонение 6%) |
| Треугольники | 412 (визуальные меши, без коллизий) |
| Меши / узлы | 4 мешей, 4 визуальных узлов, 6 узлов в GLB |
| Материалы | env_wood_light, env_iron, env_wood_mid |
| Коллизии | wooden_barricade_barricade_col-convcolonly |
| Части | crossbeams, iron_bands, posts, rear_braces |
| Подвижные части | нет подвижных частей |
| Проблемы сетки | нет (вырожденных граней, висячих вершин, отрицательного масштаба нет) |
| Границы исходник = GLB | да |

## Решения и ограничения
Два заострённых столба, две поперечины спереди, задние треугольные упоры, железные бандажи.

Оси: Blender Z-up, front −Y; экспорт glTF с штатным +Y-up (front модели в Godot +Z). Origin — на опоре.
