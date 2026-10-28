# Декоративное копьё (`decorative_spear`)

Референс и промпт: `outputs/game-asset-kit-2026-10-26/Окружение/…/decorative_spear.png|.md`.
Происхождение: смоделировано процедурно в Blender 5.2.0 LTS по PNG и MD-промпту; Tripo/high-poly не использовался, bake не делался.

## Файлы
- Runtime: `assets/models/environment/road_defense/decorative_spear.glb` (164 КБ, текстуры встроены)
- Исходник: `generated-models/decorative_spear/decorative_spear.blend` (сцена `ENV_decorative_spear`, коллекция `decorative_spear`, текстуры упакованы)
- Превью: `generated-models/decorative_spear/decorative_spear_preview.png`, данные проверки: `decorative_spear_report.json`

## Факт после повторного импорта GLB
| | |
|---|---|
| Габариты X×Y×Z, м | 0.116 × 0.044 × 1.65 (цель 0.12 × 0.08 × 1.65, макс. отклонение 45%) |
| Треугольники | 136 (визуальные меши, без коллизий) |
| Меши / узлы | 2 мешей, 2 визуальных узлов, 4 узлов в GLB |
| Материалы | env_steel, env_wood_dark |
| Коллизии | нет (не нужна) |
| Части | iron_spearhead, wooden_shaft |
| Подвижные части | нет подвижных частей |
| Проблемы сетки | нет (вырожденных граней, висячих вершин, отрицательного масштаба нет) |
| Границы исходник = GLB | да |

## Решения и ограничения
Древко + железный наконечник ромбического сечения, втулка и подток. Пустышка `rack_socket` на середине древка. Глубина 0.044 м — наконечник плоский; целевые 0.08 м — это огибающая.

Оси: Blender Z-up, front −Y; экспорт glTF с штатным +Y-up (front модели в Godot +Z). Origin — на опоре.
