# Пешеходный мост (`timber_footbridge`)

Референс и промпт: `outputs/game-asset-kit-2026-10-26/Окружение/…/timber_footbridge.png|.md`.
Происхождение: смоделировано процедурно в Blender 5.2.0 LTS по PNG и MD-промпту; Tripo/high-poly не использовался, bake не делался.

## Файлы
- Runtime: `assets/models/environment/road_defense/timber_footbridge.glb` (412 КБ, текстуры встроены)
- Исходник: `generated-models/timber_footbridge/timber_footbridge.blend` (сцена `ENV_timber_footbridge`, коллекция `timber_footbridge`, текстуры упакованы)
- Превью: `generated-models/timber_footbridge/timber_footbridge_preview.png`, данные проверки: `timber_footbridge_report.json`

## Факт после повторного импорта GLB
| | |
|---|---|
| Габариты X×Y×Z, м | 4.208 × 2.21 × 1.255 (цель 4.2 × 2.2 × 1.25, макс. отклонение 0%) |
| Треугольники | 2684 (визуальные меши, без коллизий) |
| Меши / узлы | 5 мешей, 5 визуальных узлов, 11 узлов в GLB |
| Материалы | env_wood_mid, env_wood_light, env_rope |
| Коллизии | timber_footbridge_deck_col-convcolonly, timber_footbridge_rail_L_col-convcolonly, timber_footbridge_rail_R_col-convcolonly |
| Части | beams, deck_boards, posts, rails, rope_lashings |
| Подвижные части | нет подвижных частей |
| Проблемы сетки | нет (вырожденных граней, висячих вершин, отрицательного масштаба нет) |
| Границы исходник = GLB | да |

## Решения и ограничения
Две несущие балки, пять поперечных лаг, 8 продольных досок настила, 4 столба с шапками, перила и раскосы, верёвочные обмотки. Настил на высоте 0.4 м; пустышки `deck_start/end`.

Оси: Blender Z-up, front −Y; экспорт glTF с штатным +Y-up (front модели в Godot +Z). Origin — на опоре.
