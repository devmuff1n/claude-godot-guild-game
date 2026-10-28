# Поваленное дерево (`fallen_tree_root`)

Референс и промпт: `outputs/game-asset-kit-2026-10-26/Окружение/…/fallen_tree_root.png|.md`.
Происхождение: смоделировано процедурно в Blender 5.2.0 LTS по PNG и MD-промпту; Tripo/high-poly не использовался, bake не делался.

## Файлы
- Runtime: `assets/models/environment/landscape/fallen_tree_root.glb` (427 КБ, текстуры встроены)
- Исходник: `generated-models/fallen_tree_root/fallen_tree_root.blend` (сцена `ENV_fallen_tree_root`, коллекция `fallen_tree_root`, текстуры упакованы)
- Превью: `generated-models/fallen_tree_root/fallen_tree_root_preview.png`, данные проверки: `fallen_tree_root_report.json`

## Факт после повторного импорта GLB
| | |
|---|---|
| Габариты X×Y×Z, м | 3.0 × 1.3 × 1.0 (цель 3 × 1.3 × 1.0, макс. отклонение 0%) |
| Треугольники | 1234 (визуальные меши, без коллизий) |
| Меши / узлы | 3 мешей, 3 визуальных узлов, 6 узлов в GLB |
| Материалы | env_bark_oak, env_wood_raw, env_leaf_broad (2-sided), env_moss |
| Коллизии | fallen_tree_root_log_col-convcolonly, fallen_tree_root_roots_col-convcolonly |
| Части | branch_stubs, root_mass, trunk |
| Подвижные части | нет подвижных частей |
| Проблемы сетки | нет (вырожденных граней, висячих вершин, отрицательного масштаба нет) |
| Границы исходник = GLB | да |

## Решения и ограничения
Ствол, корневой веер (13 сплющенных корней с обломанными светлыми концами), сломанные сучья, мох материалом по верху, листья плюща. Следы зверей не впечены — это decal на грунте.

Оси: Blender Z-up, front −Y; экспорт glTF с штатным +Y-up (front модели в Godot +Z). Origin — на опоре.
