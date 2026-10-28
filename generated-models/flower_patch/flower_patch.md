# Пятно полевых цветов (`flower_patch`)

Референс и промпт: `outputs/game-asset-kit-2026-10-26/Окружение/…/flower_patch.png|.md`.
Происхождение: смоделировано процедурно в Blender 5.2.0 LTS по PNG и MD-промпту; Tripo/high-poly не использовался, bake не делался.

## Файлы
- Runtime: `assets/models/environment/vegetation/flower_patch.glb` (241 КБ, текстуры встроены)
- Исходник: `generated-models/flower_patch/flower_patch.blend` (сцена `ENV_flower_patch`, коллекция `flower_patch`, текстуры упакованы)
- Превью: `generated-models/flower_patch/flower_patch_preview.png`, данные проверки: `flower_patch_report.json`

## Факт после повторного импорта GLB
| | |
|---|---|
| Габариты X×Y×Z, м | 0.7 × 0.6 × 0.5 (цель 0.7 × 0.6 × 0.5, макс. отклонение 0%) |
| Треугольники | 1566 (визуальные меши, без коллизий) |
| Меши / узлы | 2 мешей, 2 визуальных узлов, 3 узлов в GLB |
| Материалы | env_petal_cream (2-sided), env_petal_lavender (2-sided), env_soil_dark, env_flower_leaf (2-sided) |
| Коллизии | нет (не нужна) |
| Части | flower_heads, stems_and_leaves |
| Подвижные части | нет подвижных частей |
| Проблемы сетки | нет (вырожденных граней, висячих вершин, отрицательного масштаба нет) |
| Границы исходник = GLB | да |

## Решения и ограничения
Корневой холмик, 30 листьев в три яруса, 11 цветков (кремовые и лавандовые) и 3 бутона.

Оси: Blender Z-up, front −Y; экспорт glTF с штатным +Y-up (front модели в Godot +Z). Origin — на опоре.
