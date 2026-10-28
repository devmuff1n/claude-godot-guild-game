# Круглый щит дозорного (`round_watch_shield`)

Референс и промпт: `outputs/game-asset-kit-2026-10-26/Окружение/…/round_watch_shield.png|.md`.
Происхождение: смоделировано процедурно в Blender 5.2.0 LTS по PNG и MD-промпту; Tripo/high-poly не использовался, bake не делался.

## Файлы
- Runtime: `assets/models/environment/road_defense/round_watch_shield.glb` (415 КБ, текстуры встроены)
- Исходник: `generated-models/round_watch_shield/round_watch_shield.blend` (сцена `ENV_round_watch_shield`, коллекция `round_watch_shield`, текстуры упакованы)
- Превью: `generated-models/round_watch_shield/round_watch_shield_preview.png`, данные проверки: `round_watch_shield_report.json`

## Факт после повторного импорта GLB
| | |
|---|---|
| Габариты X×Y×Z, м | 0.6 × 0.109 × 0.6 (цель 0.6 × 0.1 × 0.6, макс. отклонение 9%) |
| Треугольники | 1032 (визуальные меши, без коллизий) |
| Меши / узлы | 4 мешей, 4 визуальных узлов, 7 узлов в GLB |
| Материалы | env_steel, env_iron, env_leather, env_shield_planks |
| Коллизии | нет (не нужна) |
| Части | central_boss, metal_rim, rear_grip_and_straps, wooden_shield_disk |
| Подвижные части | нет подвижных частей |
| Проблемы сетки | нет (вырожденных граней, висячих вершин, отрицательного масштаба нет) |
| Границы исходник = GLB | да |

## Решения и ограничения
Диск из досок (текстура), железный обод с заклёпками, умбон с фланцем, сзади рукоять и ремённая петля у левого края (на обороте, не на лицевой стороне). Root в центре диска; `grip_socket` и `arm_strap_socket` сзади.

Оси: Blender Z-up, front −Y; экспорт glTF с штатным +Y-up (front модели в Godot +Z). Origin — на опоре.
