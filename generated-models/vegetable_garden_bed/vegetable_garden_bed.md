# Деревенская грядка (`vegetable_garden_bed`)

Референс и промпт: `outputs/game-asset-kit-2026-10-26/Окружение/…/vegetable_garden_bed.png|.md`.
Происхождение: смоделировано процедурно в Blender 5.2.0 LTS по PNG и MD-промпту; Tripo/high-poly не использовался, bake не делался.

## Файлы
- Runtime: `assets/models/environment/landscape/vegetable_garden_bed.glb` (329 КБ, текстуры встроены)
- Исходник: `generated-models/vegetable_garden_bed/vegetable_garden_bed.blend` (сцена `ENV_vegetable_garden_bed`, коллекция `vegetable_garden_bed`, текстуры упакованы)
- Превью: `generated-models/vegetable_garden_bed/vegetable_garden_bed_preview.png`, данные проверки: `vegetable_garden_bed_report.json`

## Факт после повторного импорта GLB
| | |
|---|---|
| Габариты X×Y×Z, м | 3.639 × 2.748 × 0.334 (цель 3.6 × 2.7 × 0.35, макс. отклонение 5%) |
| Треугольники | 2080 (визуальные меши, без коллизий) |
| Меши / узлы | 3 мешей, 3 визуальных узлов, 5 узлов в GLB |
| Материалы | env_soil, env_soil_dark, env_seedling_leaf (2-sided) |
| Коллизии | vegetable_garden_bed_bed_col-convcolonly |
| Части | furrows, soil_bed, vegetable_clumps |
| Подвижные части | нет подвижных частей |
| Проблемы сетки | нет (вырожденных граней, висячих вершин, отрицательного масштаба нет) |
| Границы исходник = GLB | да |

## Решения и ограничения
Земляное основание с валиком, три гряды, 18 кустиков рассады одним мешем. Декорация, без механики фермерства.

Оси: Blender Z-up, front −Y; экспорт glTF с штатным +Y-up (front модели в Godot +Z). Origin — на опоре.
