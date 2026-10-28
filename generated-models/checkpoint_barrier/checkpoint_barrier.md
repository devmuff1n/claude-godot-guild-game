# Подъёмный шлагбаум (`checkpoint_barrier`)

Референс и промпт: `outputs/game-asset-kit-2026-10-26/Окружение/…/checkpoint_barrier.png|.md`.
Происхождение: смоделировано процедурно в Blender 5.2.0 LTS по PNG и MD-промпту; Tripo/high-poly не использовался, bake не делался.

## Файлы
- Runtime: `assets/models/environment/road_defense/checkpoint_barrier.glb` (297 КБ, текстуры встроены)
- Исходник: `generated-models/checkpoint_barrier/checkpoint_barrier.blend` (сцена `ENV_checkpoint_barrier`, коллекция `checkpoint_barrier`, текстуры упакованы)
- Превью: `generated-models/checkpoint_barrier/checkpoint_barrier_preview.png`, данные проверки: `checkpoint_barrier_report.json`

## Факт после повторного импорта GLB
| | |
|---|---|
| Габариты X×Y×Z, м | 3.59 × 0.415 × 1.214 (цель 3.6 × 0.4 × 1.2, макс. отклонение 4%) |
| Треугольники | 522 (визуальные меши, без коллизий) |
| Меши / узлы | 5 мешей, 5 визуальных узлов, 9 узлов в GLB |
| Материалы | env_wood_mid, env_paint_cream, env_iron |
| Коллизии | checkpoint_barrier_crossbar_col-convcolonly, checkpoint_barrier_posts_L_col-convcolonly, checkpoint_barrier_posts_R_col-convcolonly |
| Части | crossbar, fixed_posts, iron_fittings, iron_hinge, stop_support |
| Подвижные части | checkpoint_barrier_crossbar: ось local Y (lift), pivot [-1.36, 0.0, 0.85], движется=True |
| Проблемы сетки | нет (вырожденных граней, висячих вершин, отрицательного масштаба нет) |
| Границы исходник = GLB | да |

## Решения и ограничения
Неподвижные стойки, железные бандажи, ложемент-упор на правой стойке. Перекладина `crossbar` — отдельный узел с pivot на оси шарнира (локальная Y в Blender = Z в Godot); тест подъёма пройден, коллизия перекладины — дочерняя и двигается с ней.

Оси: Blender Z-up, front −Y; экспорт glTF с штатным +Y-up (front модели в Godot +Z). Origin — на опоре.
