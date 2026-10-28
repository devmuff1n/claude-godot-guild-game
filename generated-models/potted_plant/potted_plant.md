# Комнатное растение (`potted_plant`)

Референс и промпт: `outputs/game-asset-kit-2026-10-26/Окружение/…/potted_plant.png|.md`.
Происхождение: смоделировано процедурно в Blender 5.2.0 LTS по PNG и MD-промпту; Tripo/high-poly не использовался, bake не делался.

## Файлы
- Runtime: `assets/models/environment/vegetation/potted_plant.glb` (227 КБ, текстуры встроены)
- Исходник: `generated-models/potted_plant/potted_plant.blend` (сцена `ENV_potted_plant`, коллекция `potted_plant`, текстуры упакованы)
- Превью: `generated-models/potted_plant/potted_plant_preview.png`, данные проверки: `potted_plant_report.json`

## Факт после повторного импорта GLB
| | |
|---|---|
| Габариты X×Y×Z, м | 0.44 × 0.43 × 0.75 (цель 0.45 × 0.4 × 0.75, макс. отклонение 8%) |
| Треугольники | 850 (визуальные меши, без коллизий) |
| Меши / узлы | 3 мешей, 3 визуальных узлов, 6 узлов в GLB |
| Материалы | env_leaf_broad (2-sided), env_terracotta, env_soil_dark |
| Коллизии | potted_plant_pot_col-convcolonly |
| Части | plant, pot, soil |
| Подвижные части | нет подвижных частей |
| Проблемы сетки | нет (вырожденных граней, висячих вершин, отрицательного масштаба нет) |
| Границы исходник = GLB | да |

## Решения и ограничения
Горшок-тело вращения с толстой кромкой, отдельная почва, растение (стебли + 9 листьев). Пустышка `plant_insert` в центре почвы.

Оси: Blender Z-up, front −Y; экспорт glTF с штатным +Y-up (front модели в Godot +Z). Origin — на опоре.
