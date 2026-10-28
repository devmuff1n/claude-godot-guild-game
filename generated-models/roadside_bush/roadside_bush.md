# Куст у дороги (`roadside_bush`)

Референс и промпт: `outputs/game-asset-kit-2026-10-26/Окружение/…/roadside_bush.png|.md`.
Происхождение: смоделировано процедурно в Blender 5.2.0 LTS по PNG и MD-промпту; Tripo/high-poly не использовался, bake не делался.

## Файлы
- Runtime: `assets/models/environment/vegetation/roadside_bush.glb` (419 КБ, текстуры встроены)
- Исходник: `generated-models/roadside_bush/roadside_bush.blend` (сцена `ENV_roadside_bush`, коллекция `roadside_bush`, текстуры упакованы)
- Превью: `generated-models/roadside_bush/roadside_bush_preview.png`, данные проверки: `roadside_bush_report.json`

## Факт после повторного импорта GLB
| | |
|---|---|
| Габариты X×Y×Z, м | 1.4 × 1.2 × 1.0 (цель 1.4 × 1.2 × 1.0, макс. отклонение 0%) |
| Треугольники | 2682 (визуальные меши, без коллизий) |
| Меши / узлы | 3 мешей, 3 визуальных узлов, 4 узлов в GLB |
| Материалы | env_leaf_bush (2-sided), env_leaves_bush, env_bark |
| Коллизии | нет (не нужна) |
| Части | leaf_cards, leaf_masses, woody_stems |
| Подвижные части | нет подвижных частей |
| Проблемы сетки | нет (вырожденных граней, висячих вершин, отрицательного масштаба нет) |
| Границы исходник = GLB | да |

## Решения и ограничения
Скрытые древесные стебли, тёмные массы-ядра и 150 крупных зубчатых листьев-карточек (двусторонний материал). Коллизии нет — куст проходим и служит маркером засады.

Оси: Blender Z-up, front −Y; экспорт glTF с штатным +Y-up (front модели в Godot +Z). Origin — на опоре.
